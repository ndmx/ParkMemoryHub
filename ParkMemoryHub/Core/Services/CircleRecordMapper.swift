import CloudKit
import Foundation

/// Translates between domain models and `CKRecord`s for a single circle zone.
/// Every record is rooted at the circle's `Circle` record so the whole tree can
/// be shared by a single `CKShare`.
struct CircleRecordMapper: Sendable {
    enum RecordType {
        static let circle = "Circle"
        static let member = "Member"
        static let memory = "Memory"
        static let memoryMedia = "MemoryMedia"
        static let plan = "Plan"
    }

    let zoneID: CKRecordZone.ID
    let circleID: GroupSpace.ID

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private static let decoder = JSONDecoder()

    // MARK: Record IDs

    var rootRecordID: CKRecord.ID {
        CKRecord.ID(recordName: circleID.uuidString, zoneID: zoneID)
    }

    func memberRecordID(_ id: FamilyMember.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "member-\(id.uuidString)", zoneID: zoneID)
    }

    func memoryRecordID(_ id: ParkMemory.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "memory-\(id.uuidString)", zoneID: zoneID)
    }

    func planRecordID(_ id: ParkActivity.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "plan-\(id.uuidString)", zoneID: zoneID)
    }

    func mediaRecordID(memoryID: ParkMemory.ID, mediaItemID: ParkMemory.MediaItem.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "media-\(memoryID.uuidString)-\(mediaItemID.uuidString)", zoneID: zoneID)
    }

    private var rootReference: CKRecord.Reference {
        CKRecord.Reference(recordID: rootRecordID, action: .none)
    }

    // MARK: Circle root

    func circleRootRecord(existing: CKRecord? = nil, displayName: String, createdByMemberID: FamilyMember.ID?, createdAt: Date) -> CKRecord {
        let record = existing ?? CKRecord(recordType: RecordType.circle, recordID: rootRecordID)
        record["displayName"] = displayName as CKRecordValue
        record["createdByMemberID"] = createdByMemberID?.uuidString as CKRecordValue?
        record["createdAt"] = createdAt as CKRecordValue
        return record
    }

    // MARK: Member

    func memberRecord(from member: FamilyMember, avatarData: Data?, existing: CKRecord? = nil) throws -> CKRecord {
        let record = existing ?? CKRecord(recordType: RecordType.member, recordID: memberRecordID(member.id))
        record.parent = rootReference
        record["memberID"] = member.id.uuidString as CKRecordValue
        record["displayName"] = member.displayName as CKRecordValue
        record["role"] = member.role.rawValue as CKRecordValue
        record["sharesLocation"] = (member.sharesLocation ? 1 : 0) as CKRecordValue
        record["lastSeenAt"] = member.lastSeenAt as CKRecordValue?
        record["joinedAt"] = member.joinedAt as CKRecordValue
        record["avatarLocalAssetIdentifier"] = member.avatarLocalAssetIdentifier as CKRecordValue?

        // Live location is the most sensitive field — store it field-level encrypted.
        if member.sharesLocation, let location = member.lastKnownLocation {
            record.encryptedValues["location"] = try Self.encoder.encode(location) as CKRecordValue
        } else {
            record.encryptedValues["location"] = nil
        }

        if let avatarData {
            record["avatar"] = try Self.asset(for: avatarData, suffix: "avatar")
        }

        return record
    }

    func member(from record: CKRecord) -> FamilyMember? {
        guard record.recordType == RecordType.member,
              let idString = record["memberID"] as? String,
              let id = UUID(uuidString: idString) else {
            return nil
        }

        let location: ParkLocation?
        if let data = record.encryptedValues["location"] as? Data {
            location = try? Self.decoder.decode(ParkLocation.self, from: data)
        } else {
            location = nil
        }

        return FamilyMember(
            id: id,
            groupID: circleID,
            displayName: record["displayName"] as? String ?? "Member",
            avatarLocalAssetIdentifier: record["avatarLocalAssetIdentifier"] as? String,
            role: (record["role"] as? String).flatMap(FamilyMember.Role.init(rawValue:)) ?? .member,
            isCurrentUser: false,
            sharesLocation: (record["sharesLocation"] as? Int) == 1,
            lastKnownLocation: location,
            lastSeenAt: record["lastSeenAt"] as? Date,
            joinedAt: record["joinedAt"] as? Date ?? Date()
        )
    }

    func avatarData(from record: CKRecord) -> Data? {
        guard let asset = record["avatar"] as? CKAsset, let url = asset.fileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: Memory

    func memoryRecord(from memory: ParkMemory, existing: CKRecord? = nil) throws -> CKRecord {
        let record = existing ?? CKRecord(recordType: RecordType.memory, recordID: memoryRecordID(memory.id))
        record.parent = rootReference
        record["memoryID"] = memory.id.uuidString as CKRecordValue
        record["caption"] = memory.caption as CKRecordValue
        record["tags"] = memory.tags as CKRecordValue
        record["mediaKind"] = memory.mediaKind.rawValue as CKRecordValue
        record["createdByMemberID"] = memory.createdByMemberID?.uuidString as CKRecordValue?
        record["createdAt"] = memory.createdAt as CKRecordValue
        record["updatedAt"] = memory.updatedAt as CKRecordValue
        record["mediaItemIDs"] = memory.displayMediaItems.map { $0.id.uuidString } as CKRecordValue
        if let location = memory.location {
            record["location"] = try Self.encoder.encode(location) as CKRecordValue
        } else {
            record["location"] = nil
        }
        return record
    }

    /// Reconstructs a memory from its `Memory` record plus any already-downloaded
    /// media. `mediaDataByItemID` holds bytes fetched from `MemoryMedia` records.
    func memory(from record: CKRecord) -> ParkMemory? {
        guard record.recordType == RecordType.memory,
              let idString = record["memoryID"] as? String,
              let id = UUID(uuidString: idString) else {
            return nil
        }

        let location: ParkLocation?
        if let data = record["location"] as? Data {
            location = try? Self.decoder.decode(ParkLocation.self, from: data)
        } else {
            location = nil
        }

        let mediaKind = (record["mediaKind"] as? String).flatMap(ParkMemory.MediaKind.init(rawValue:)) ?? .photo
        let mediaItemIDs = (record["mediaItemIDs"] as? [String])?.compactMap(UUID.init(uuidString:)) ?? []
        let createdAt = record["createdAt"] as? Date ?? Date()
        let updatedAt = record["updatedAt"] as? Date ?? createdAt
        let createdByMemberID = (record["createdByMemberID"] as? String).flatMap(UUID.init(uuidString:))

        let mediaItems = mediaItemIDs.map { itemID in
            ParkMemory.MediaItem(
                id: itemID,
                memoryID: id,
                groupID: circleID,
                createdByMemberID: createdByMemberID,
                kind: mediaKind,
                downloadState: .availableForDownload,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        return ParkMemory(
            id: id,
            groupID: circleID,
            createdByMemberID: createdByMemberID,
            mediaKind: mediaKind,
            mediaItems: mediaItems,
            caption: record["caption"] as? String ?? "",
            tags: record["tags"] as? [String] ?? [],
            location: location,
            shareState: .shared,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: Memory media (CKAsset children of a Memory)

    func mediaRecords(for memory: ParkMemory, mediaDataByItemID: [ParkMemory.MediaItem.ID: Data]) throws -> [CKRecord] {
        let memoryReference = CKRecord.Reference(recordID: memoryRecordID(memory.id), action: .none)
        return try memory.displayMediaItems.compactMap { item in
            guard let data = mediaDataByItemID[item.id] else { return nil }
            let record = CKRecord(recordType: RecordType.memoryMedia, recordID: mediaRecordID(memoryID: memory.id, mediaItemID: item.id))
            record.parent = memoryReference
            record["memoryID"] = memory.id.uuidString as CKRecordValue
            record["mediaItemID"] = item.id.uuidString as CKRecordValue
            record["kind"] = item.kind.rawValue as CKRecordValue
            record["asset"] = try Self.asset(for: data, suffix: "photo")
            return record
        }
    }

    func mediaAsset(from record: CKRecord) -> (mediaItemID: ParkMemory.MediaItem.ID, data: Data)? {
        guard record.recordType == RecordType.memoryMedia,
              let idString = record["mediaItemID"] as? String,
              let id = UUID(uuidString: idString),
              let asset = record["asset"] as? CKAsset,
              let url = asset.fileURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return (id, data)
    }

    // MARK: Plan

    func planRecord(from activity: ParkActivity, existing: CKRecord? = nil) throws -> CKRecord {
        let record = existing ?? CKRecord(recordType: RecordType.plan, recordID: planRecordID(activity.id))
        record.parent = rootReference
        record["planID"] = activity.id.uuidString as CKRecordValue
        record["title"] = activity.title as CKRecordValue
        record["notes"] = activity.notes as CKRecordValue
        record["status"] = activity.status.rawValue as CKRecordValue
        record["visibility"] = activity.visibility.rawValue as CKRecordValue
        record["scheduledAt"] = activity.scheduledAt as CKRecordValue?
        record["createdByMemberID"] = activity.createdByMemberID?.uuidString as CKRecordValue?
        record["createdAt"] = activity.createdAt as CKRecordValue
        record["updatedAt"] = activity.updatedAt as CKRecordValue
        record["sharedWithMemberIDs"] = activity.sharedWithMemberIDs.map { $0.uuidString } as CKRecordValue
        record["votesByMemberID"] = try Self.encoder.encode(activity.votesByMemberID) as CKRecordValue
        if let location = activity.location {
            record["location"] = try Self.encoder.encode(location) as CKRecordValue
        } else {
            record["location"] = nil
        }
        return record
    }

    func activity(from record: CKRecord) -> ParkActivity? {
        guard record.recordType == RecordType.plan,
              let idString = record["planID"] as? String,
              let id = UUID(uuidString: idString) else {
            return nil
        }

        let location: ParkLocation?
        if let data = record["location"] as? Data {
            location = try? Self.decoder.decode(ParkLocation.self, from: data)
        } else {
            location = nil
        }

        let votes: [UUID: ParkActivity.Vote]
        if let data = record["votesByMemberID"] as? Data {
            votes = (try? Self.decoder.decode([UUID: ParkActivity.Vote].self, from: data)) ?? [:]
        } else {
            votes = [:]
        }

        let createdAt = record["createdAt"] as? Date ?? Date()
        let updatedAt = record["updatedAt"] as? Date ?? createdAt

        return ParkActivity(
            id: id,
            groupID: circleID,
            createdByMemberID: (record["createdByMemberID"] as? String).flatMap(UUID.init(uuidString:)),
            title: record["title"] as? String ?? "Plan",
            notes: record["notes"] as? String ?? "",
            location: location,
            scheduledAt: record["scheduledAt"] as? Date,
            status: (record["status"] as? String).flatMap(ParkActivity.Status.init(rawValue:)) ?? .planned,
            visibility: (record["visibility"] as? String).flatMap(ParkActivity.Visibility.init(rawValue:)) ?? .circle,
            sharedWithMemberIDs: (record["sharedWithMemberIDs"] as? [String])?.compactMap(UUID.init(uuidString:)) ?? [],
            votesByMemberID: votes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: Helpers

    private static func asset(for data: Data, suffix: String) throws -> CKAsset {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(suffix)")
        try data.write(to: fileURL, options: [.atomic])
        return CKAsset(fileURL: fileURL)
    }
}
