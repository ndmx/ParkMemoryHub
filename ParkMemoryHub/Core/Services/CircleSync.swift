import CloudKit
import Foundation

struct CircleSyncSummary: Equatable, Sendable {
    var pushedCount: Int = 0
    var checkedCount: Int = 0
    var appliedCount: Int = 0
}

/// The sync surface the view models talk to. Production is `CircleSyncCoordinator`
/// (CloudKit shared zones); previews/tests use `NoOpCircleSync`.
protocol CircleSyncing: Sendable {
    func accountStatus() async -> CKAccountStatus
    /// Pulls remote changes into the local repositories and pushes the local
    /// member snapshot. Returns counts for status messages.
    func refresh() async throws -> CircleSyncSummary
    func pushMember(_ member: FamilyMember, avatarData: Data?) async throws
    func pushMemory(_ memory: ParkMemory) async throws
    func pushPlan(_ activity: ParkActivity) async throws
    func deleteMemoryRemote(_ memory: ParkMemory) async throws
    func deletePlanRemote(id: ParkActivity.ID) async throws
    /// Owner-only: returns a share + container for `UICloudSharingController`.
    func prepareShare(displayName: String) async throws -> (CKShare, CKContainer)
}

// MARK: - Production

struct CircleSyncCoordinator: CircleSyncing {
    private let service: CloudKitCircleService
    private let familyRepository: any FamilyRepository
    private let memoryRepository: any MemoryRepository
    private let activitiesRepository: any ActivityRepository
    private let activeGroup: GroupSpace
    private let isOwner: Bool
    private let refreshGate = CircleSyncRefreshGate()

    init(
        identity: DeviceIdentity,
        familyRepository: any FamilyRepository,
        memoryRepository: any MemoryRepository,
        activitiesRepository: any ActivityRepository,
        activeGroup: GroupSpace,
        tokenStore: FileChangeTokenStore
    ) {
        self.service = CloudKitCircleService(identity: identity, tokenStore: tokenStore)
        self.familyRepository = familyRepository
        self.memoryRepository = memoryRepository
        self.activitiesRepository = activitiesRepository
        self.activeGroup = activeGroup
        self.isOwner = identity.role == .owner
    }

    func accountStatus() async -> CKAccountStatus {
        await service.accountStatus()
    }

    func prepareShare(displayName: String) async throws -> (CKShare, CKContainer) {
        guard isOwner else { throw CircleSyncError.notOwner }
        let member = try? await familyRepository.currentMember()
        let share = try await service.fetchOrCreateShare(
            displayName: displayName,
            createdByMemberID: member?.id,
            createdAt: activeGroup.createdAt
        )
        return (share, service.container)
    }

    func refresh() async throws -> CircleSyncSummary {
        try await refreshGate.refresh {
            try await performRefresh()
        }
    }

    private func performRefresh() async throws -> CircleSyncSummary {
        try await service.requireSignedIn()

        var summary = CircleSyncSummary()

        let currentMember = try await familyRepository.currentMember()
        if isOwner {
            _ = try await service.ensureProvisioned(
                displayName: activeGroup.displayName,
                createdByMemberID: currentMember.id,
                createdAt: activeGroup.createdAt
            )
        }

        // Push the local member snapshot (profile + location). Avatars are only
        // uploaded on explicit profile saves, so refresh stays asset-light.
        try await pushMember(currentMember, avatarData: nil)
        summary.pushedCount = 1

        let changes = try await service.fetchChanges()
        summary.checkedCount = changes.records.count + changes.deletedRecordIDs.count
        summary.appliedCount = try await apply(changes, currentMemberID: currentMember.id)
        return summary
    }

    func pushMember(_ member: FamilyMember, avatarData: Data?) async throws {
        let mapper = await service.mapper
        if isOwner {
            _ = try await service.ensureProvisioned(
                displayName: activeGroup.displayName,
                createdByMemberID: member.id,
                createdAt: activeGroup.createdAt
            )
        }
        let record = try mapper.memberRecord(from: member, avatarData: avatarData)
        try await service.save([record])
    }

    func pushMemory(_ memory: ParkMemory) async throws {
        let mapper = await service.mapper
        if isOwner {
            _ = try await service.ensureProvisioned(
                displayName: activeGroup.displayName,
                createdByMemberID: memory.createdByMemberID,
                createdAt: activeGroup.createdAt
            )
        }

        var mediaDataByItemID: [ParkMemory.MediaItem.ID: Data] = [:]
        for item in memory.displayMediaItems {
            if let data = try await memoryRepository.mediaData(for: item) {
                mediaDataByItemID[item.id] = data
            }
        }

        let memoryRecord = try mapper.memoryRecord(from: memory)
        let mediaRecords = try mapper.mediaRecords(for: memory, mediaDataByItemID: mediaDataByItemID)
        try await service.save([memoryRecord] + mediaRecords)
    }

    func pushPlan(_ activity: ParkActivity) async throws {
        let mapper = await service.mapper
        if isOwner {
            _ = try await service.ensureProvisioned(
                displayName: activeGroup.displayName,
                createdByMemberID: activity.createdByMemberID,
                createdAt: activeGroup.createdAt
            )
        }
        let record = try mapper.planRecord(from: activity)
        try await service.save([record])
    }

    func deleteMemoryRemote(_ memory: ParkMemory) async throws {
        let mapper = await service.mapper
        var ids = [mapper.memoryRecordID(memory.id)]
        ids += memory.displayMediaItems.map { mapper.mediaRecordID(memoryID: memory.id, mediaItemID: $0.id) }
        try await service.delete(ids)
    }

    func deletePlanRemote(id: ParkActivity.ID) async throws {
        let mapper = await service.mapper
        try await service.delete([mapper.planRecordID(id)])
    }

    // MARK: Apply pulled changes

    private func apply(_ changes: CloudKitCircleService.ChangeSet, currentMemberID: FamilyMember.ID) async throws -> Int {
        let mapper = await service.mapper
        var appliedCount = 0

        // Collect media bytes first so memories can be saved with their photos.
        var mediaDataByItemID: [ParkMemory.MediaItem.ID: Data] = [:]
        for record in changes.records where record.recordType == CircleRecordMapper.RecordType.memoryMedia {
            if let asset = mapper.mediaAsset(from: record) {
                mediaDataByItemID[asset.mediaItemID] = asset.data
            }
        }

        for record in changes.records {
            switch record.recordType {
            case CircleRecordMapper.RecordType.member:
                guard var member = mapper.member(from: record), member.id != currentMemberID else { continue }
                member.isCurrentUser = false
                if let avatarData = mapper.avatarData(from: record) {
                    member.avatarLocalAssetIdentifier = try? FileProfileAvatarStore.saveAvatarData(avatarData, memberID: member.id)
                }
                _ = try await familyRepository.saveMember(member)
                appliedCount += 1

            case CircleRecordMapper.RecordType.memory:
                guard var memory = mapper.memory(from: record) else { continue }

                // Preserve media we already downloaded locally: a metadata-only
                // update (e.g. a caption edit) won't re-send the MemoryMedia bytes.
                let existing = try? await memoryRepository.memory(id: memory.id)
                memory.mediaItems = memory.displayMediaItems.map { item in
                    if mediaDataByItemID[item.id] == nil,
                       let downloaded = existing?.displayMediaItems.first(where: { $0.id == item.id }),
                       downloaded.downloadState == .downloaded {
                        return downloaded
                    }
                    return item
                }

                let payload = mediaDataByItemID.filter { key, _ in memory.displayMediaItems.contains { $0.id == key } }
                if payload.isEmpty {
                    _ = try await memoryRepository.saveMemory(memory)
                } else {
                    _ = try await memoryRepository.saveMemory(memory, mediaDataByItemID: payload)
                }
                appliedCount += 1

            case CircleRecordMapper.RecordType.plan:
                guard let activity = mapper.activity(from: record) else { continue }
                _ = try await activitiesRepository.saveActivity(activity)
                appliedCount += 1

            default:
                continue // Circle root / MemoryMedia handled above.
            }
        }

        for recordID in changes.deletedRecordIDs {
            let name = recordID.recordName
            if name.hasPrefix("memory-"), let id = uuid(name, prefix: "memory-") {
                try await memoryRepository.deleteMemory(id: id)
                appliedCount += 1
            } else if name.hasPrefix("plan-"), let id = uuid(name, prefix: "plan-") {
                try await activitiesRepository.deleteActivity(id: id)
                appliedCount += 1
            }
        }

        return appliedCount
    }

    private func uuid(_ recordName: String, prefix: String) -> UUID? {
        UUID(uuidString: String(recordName.dropFirst(prefix.count)))
    }
}

private actor CircleSyncRefreshGate {
    private let minimumRefreshInterval: TimeInterval = 8
    private var inFlight: Task<CircleSyncSummary, any Error>?
    private var lastFinishedAt: Date?
    private var lastSummary: CircleSyncSummary?

    func refresh(operation: @Sendable @escaping () async throws -> CircleSyncSummary) async throws -> CircleSyncSummary {
        if let inFlight {
            return try await inFlight.value
        }

        if let lastFinishedAt,
           let lastSummary,
           Date().timeIntervalSince(lastFinishedAt) < minimumRefreshInterval {
            return lastSummary
        }

        let task = Task {
            try await operation()
        }
        inFlight = task

        do {
            let summary = try await task.value
            lastSummary = summary
            lastFinishedAt = Date()
            inFlight = nil
            return summary
        } catch {
            inFlight = nil
            throw error
        }
    }
}

// MARK: - Preview / tests

struct NoOpCircleSync: CircleSyncing {
    func accountStatus() async -> CKAccountStatus { .available }
    func refresh() async throws -> CircleSyncSummary { CircleSyncSummary() }
    func pushMember(_ member: FamilyMember, avatarData: Data?) async throws {}
    func pushMemory(_ memory: ParkMemory) async throws {}
    func pushPlan(_ activity: ParkActivity) async throws {}
    func deleteMemoryRemote(_ memory: ParkMemory) async throws {}
    func deletePlanRemote(id: ParkActivity.ID) async throws {}
    func prepareShare(displayName: String) async throws -> (CKShare, CKContainer) {
        throw CircleSyncError.notOwner
    }
}

enum CircleSyncErrorFormatter {
    static func message(for error: Error) -> String {
        if let circleError = error as? CircleSyncError {
            return circleError.localizedDescription
        }

        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain {
            return "iCloud sync failed: \(error.localizedDescription)"
        }

        return error.localizedDescription
    }
}
