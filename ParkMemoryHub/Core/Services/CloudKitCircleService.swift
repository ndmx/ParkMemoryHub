import CloudKit
import Foundation

enum CircleSyncError: LocalizedError {
    case notSignedIn
    case circleUnavailable
    case notOwner

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to iCloud in Settings to use circles. Your memories stay on this device until you do."
        case .circleUnavailable:
            return "This circle is no longer available. The owner may have removed you or deleted it."
        case .notOwner:
            return "Only the circle's creator can invite people."
        }
    }
}

/// Owns all CloudKit access for one circle. An owner hosts the circle as a custom
/// zone in their private database; a participant reads/writes it through the shared
/// database. Membership and permissions are enforced by the CloudKit server.
actor CloudKitCircleService {
    nonisolated let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID
    private let circleID: GroupSpace.ID
    private let role: CircleRole
    private let tokenStore: FileChangeTokenStore

    private var didEnsureZone = false

    init(
        identity: DeviceIdentity,
        tokenStore: FileChangeTokenStore,
        containerIdentifier: String = "iCloud.lxr.ParkMemoryHub"
    ) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.circleID = identity.groupID
        self.role = identity.role
        self.tokenStore = tokenStore

        switch identity.role {
        case .owner:
            self.database = container.privateCloudDatabase
            self.zoneID = CKRecordZone.ID(zoneName: identity.zoneName, ownerName: CKCurrentUserDefaultName)
        case .participant:
            self.database = container.sharedCloudDatabase
            self.zoneID = CKRecordZone.ID(
                zoneName: identity.zoneName,
                ownerName: identity.zoneOwnerName ?? CKCurrentUserDefaultName
            )
        }
    }

    var mapper: CircleRecordMapper {
        CircleRecordMapper(zoneID: zoneID, circleID: circleID)
    }

    private var tokenKey: String {
        "zone:\(zoneID.ownerName)/\(zoneID.zoneName)"
    }

    // MARK: Account

    func accountStatus() async -> CKAccountStatus {
        (try? await container.accountStatus()) ?? .couldNotDetermine
    }

    func requireSignedIn() async throws {
        guard await accountStatus() == .available else {
            throw CircleSyncError.notSignedIn
        }
    }

    // MARK: Provisioning (owner only)

    /// Creates the circle's custom zone and root `Circle` record if they don't
    /// exist yet. Idempotent; safe to call before every owner push.
    @discardableResult
    func ensureProvisioned(displayName: String, createdByMemberID: FamilyMember.ID?, createdAt: Date) async throws -> CKRecord {
        guard role == .owner else { throw CircleSyncError.notOwner }
        try await requireSignedIn()

        if !didEnsureZone {
            _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
            didEnsureZone = true
        }

        let rootID = mapper.rootRecordID
        if let existing = try? await database.record(for: rootID) {
            return existing
        }

        let root = mapper.circleRootRecord(displayName: displayName, createdByMemberID: createdByMemberID, createdAt: createdAt)
        let results = try await database.modifyRecords(saving: [root], deleting: [], savePolicy: .changedKeys, atomically: true)
        return try results.saveResults[rootID]?.get() ?? root
    }

    // MARK: Sharing (owner only)

    func fetchOrCreateShare(displayName: String, createdByMemberID: FamilyMember.ID?, createdAt: Date) async throws -> CKShare {
        let root = try await ensureProvisioned(displayName: displayName, createdByMemberID: createdByMemberID, createdAt: createdAt)

        if let shareReference = root.share,
           let existing = try? await database.record(for: shareReference.recordID) as? CKShare {
            return existing
        }

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = displayName as CKRecordValue
        share.publicPermission = .none

        let results = try await database.modifyRecords(saving: [share, root], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
        if let saved = try results.saveResults[share.recordID]?.get() as? CKShare {
            return saved
        }
        return share
    }

    // MARK: Share acceptance (participant)

    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.qualityOfService = .userInitiated
            operation.acceptSharesResultBlock = { result in
                continuation.resume(with: result)
            }
            container.add(operation)
        }
    }

    // MARK: Writes

    func save(_ records: [CKRecord]) async throws {
        guard !records.isEmpty else { return }
        try await requireSignedIn()

        do {
            let results = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: false)
            let conflicts = try collectConflicts(from: results.saveResults, originals: records)
            if !conflicts.isEmpty {
                _ = try await database.modifyRecords(saving: conflicts, deleting: [], savePolicy: .changedKeys, atomically: false)
            }
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            throw CircleSyncError.circleUnavailable
        }
    }

    func delete(_ recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }
        try await requireSignedIn()
        do {
            _ = try await database.modifyRecords(saving: [], deleting: recordIDs, savePolicy: .ifServerRecordUnchanged, atomically: false)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            throw CircleSyncError.circleUnavailable
        }
    }

    /// Re-applies our field values onto the server's copy for any record that lost
    /// an optimistic-locking race (last-writer-wins by `updatedAt`).
    private func collectConflicts(
        from saveResults: [CKRecord.ID: Result<CKRecord, any Error>],
        originals: [CKRecord]
    ) throws -> [CKRecord] {
        let originalsByID = Dictionary(uniqueKeysWithValues: originals.map { ($0.recordID, $0) })
        var merged: [CKRecord] = []

        for (recordID, result) in saveResults {
            guard case let .failure(error) = result else { continue }
            guard let ckError = error as? CKError, ckError.code == .serverRecordChanged,
                  let serverRecord = ckError.serverRecord,
                  let ours = originalsByID[recordID] else {
                if let ckError = error as? CKError, ckError.code == .zoneNotFound || ckError.code == .userDeletedZone {
                    throw CircleSyncError.circleUnavailable
                }
                continue
            }

            let serverUpdatedAt = serverRecord["updatedAt"] as? Date ?? .distantPast
            let ourUpdatedAt = ours["updatedAt"] as? Date ?? Date()
            guard ourUpdatedAt >= serverUpdatedAt else { continue }

            for key in ours.allKeys() {
                serverRecord[key] = ours[key]
            }
            serverRecord.parent = ours.parent
            merged.append(serverRecord)
        }

        return merged
    }

    // MARK: Delta fetch

    struct ChangeSet {
        var records: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
    }

    /// Pulls only the records that changed since the last successful fetch, using a
    /// persisted server change token. Returns upserted records and deletions.
    func fetchChanges() async throws -> ChangeSet {
        try await requireSignedIn()

        var changeSet = ChangeSet()
        var token = await tokenStore.token(forKey: tokenKey)
        var moreComing = true

        do {
            while moreComing {
                let result = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)

                for (_, modificationResult) in result.modificationResultsByID {
                    if case let .success(modification) = modificationResult {
                        changeSet.records.append(modification.record)
                    }
                }
                changeSet.deletedRecordIDs.append(contentsOf: result.deletions.map { $0.recordID })

                token = result.changeToken
                moreComing = result.moreComing
            }
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            await tokenStore.setToken(nil, forKey: tokenKey)
            throw CircleSyncError.circleUnavailable
        } catch let error as CKError where error.code == .changeTokenExpired {
            // Token no longer valid — restart a full fetch from scratch.
            await tokenStore.setToken(nil, forKey: tokenKey)
            return try await fetchChanges()
        }

        await tokenStore.setToken(token, forKey: tokenKey)
        return changeSet
    }
}
