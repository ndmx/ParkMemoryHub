import CloudKit
import Foundation

actor CloudKitSyncService {
    private enum Field {
        static let groupID = "groupID"
        static let createdByMemberID = "createdByMemberID"
        static let type = "type"
        static let subjectID = "subjectID"
        static let payload = "payload"
        static let createdAt = "createdAt"
        static let memoryID = "memoryID"
        static let mediaItemID = "mediaItemID"
        static let asset = "asset"
    }

    private static let eventRecordType = "GroupSyncEvent"
    private static let mediaRecordType = "MemoryMediaAsset"

    private let database: CKDatabase

    init(containerIdentifier: String = "iCloud.lxr.ParkMemoryHub") {
        self.database = CKContainer(identifier: containerIdentifier).publicCloudDatabase
    }

    func push(events: [GroupSyncEvent]) async throws -> Int {
        let uniqueEvents = Dictionary(grouping: events, by: \.id)
            .compactMap { $0.value.first }

        guard !uniqueEvents.isEmpty else {
            return 0
        }

        let records = uniqueEvents.map(record)
        try await save(records)
        return records.count
    }

    func pull(groupID: GroupSpace.ID) async throws -> [GroupSyncEvent] {
        let predicate = NSPredicate(format: "%K == %@", Field.groupID, groupID.uuidString)
        let query = CKQuery(recordType: Self.eventRecordType, predicate: predicate)
        query.sortDescriptors = [
            NSSortDescriptor(key: Field.createdAt, ascending: true)
        ]

        var matchedRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        let firstPage = try await database.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)
        matchedRecords.append(contentsOf: try records(from: firstPage.matchResults))
        cursor = firstPage.queryCursor

        while let currentCursor = cursor {
            let page = try await database.records(continuingMatchFrom: currentCursor, resultsLimit: CKQueryOperation.maximumResults)
            matchedRecords.append(contentsOf: try records(from: page.matchResults))
            cursor = page.queryCursor
        }

        return try matchedRecords
            .map(event)
            .sorted { $0.createdAt < $1.createdAt }
    }

    func uploadMemoryMedia(memory: ParkMemory, mediaDataByItemID: [ParkMemory.MediaItem.ID: Data]) async throws -> Int {
        let records = try mediaDataByItemID.map { itemID, data in
            try mediaRecord(
                memoryID: memory.id,
                mediaItemID: itemID,
                groupID: memory.groupID,
                data: data,
                createdAt: memory.createdAt
            )
        }

        guard !records.isEmpty else {
            return 0
        }

        try await save(records)
        return records.count
    }

    func downloadMemoryMedia(for memory: ParkMemory) async throws -> [ParkMemory.MediaItem.ID: Data] {
        let recordIDs = memory.displayMediaItems.map { item in
            CKRecord.ID(recordName: mediaRecordName(memoryID: memory.id, mediaItemID: item.id))
        }
        guard !recordIDs.isEmpty else {
            return [:]
        }

        let records = try await fetchRecords(with: recordIDs)
        var mediaDataByItemID: [ParkMemory.MediaItem.ID: Data] = [:]

        for record in records {
            guard let mediaItemIDString = record[Field.mediaItemID] as? String,
                  let mediaItemID = UUID(uuidString: mediaItemIDString),
                  let asset = record[Field.asset] as? CKAsset,
                  let fileURL = asset.fileURL else {
                continue
            }

            mediaDataByItemID[mediaItemID] = try Data(contentsOf: fileURL)
        }

        return mediaDataByItemID
    }

    private func record(from event: GroupSyncEvent) -> CKRecord {
        let recordID = CKRecord.ID(recordName: event.id.uuidString)
        let record = CKRecord(recordType: Self.eventRecordType, recordID: recordID)
        record[Field.groupID] = event.groupID.uuidString
        record[Field.createdByMemberID] = event.createdByMemberID?.uuidString
        record[Field.type] = event.type.rawValue
        record[Field.subjectID] = event.subjectID?.uuidString
        record[Field.payload] = event.payload
        record[Field.createdAt] = event.createdAt
        return record
    }

    private func mediaRecord(
        memoryID: ParkMemory.ID,
        mediaItemID: ParkMemory.MediaItem.ID,
        groupID: GroupSpace.ID?,
        data: Data,
        createdAt: Date
    ) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: mediaRecordName(memoryID: memoryID, mediaItemID: mediaItemID))
        let record = CKRecord(recordType: Self.mediaRecordType, recordID: recordID)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(recordID.recordName).photo")
        try data.write(to: fileURL, options: [.atomic])

        record[Field.groupID] = groupID?.uuidString
        record[Field.memoryID] = memoryID.uuidString
        record[Field.mediaItemID] = mediaItemID.uuidString
        record[Field.createdAt] = createdAt
        record[Field.asset] = CKAsset(fileURL: fileURL)
        return record
    }

    private func mediaRecordName(memoryID: ParkMemory.ID, mediaItemID: ParkMemory.MediaItem.ID) -> String {
        "\(memoryID.uuidString)-\(mediaItemID.uuidString)"
    }

    private func save(_ records: [CKRecord]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: records)
            operation.savePolicy = .changedKeys
            operation.qualityOfService = .userInitiated
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    private func event(from record: CKRecord) throws -> GroupSyncEvent {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let groupIDString = record[Field.groupID] as? String,
              let groupID = UUID(uuidString: groupIDString),
              let typeString = record[Field.type] as? String,
              let type = GroupSyncEvent.EventType(rawValue: typeString),
              let payload = record[Field.payload] as? Data,
              let createdAt = record[Field.createdAt] as? Date else {
            throw CloudKitSyncError.invalidRecord
        }

        let createdByMemberID = (record[Field.createdByMemberID] as? String).flatMap(UUID.init(uuidString:))
        let subjectID = (record[Field.subjectID] as? String).flatMap(UUID.init(uuidString:))

        return GroupSyncEvent(
            id: id,
            groupID: groupID,
            createdByMemberID: createdByMemberID,
            type: type,
            subjectID: subjectID,
            payload: payload,
            createdAt: createdAt
        )
    }

    private func records(
        from results: [(CKRecord.ID, Result<CKRecord, any Error>)]
    ) throws -> [CKRecord] {
        try results.map { _, result in
            try result.get()
        }
    }

    private func fetchRecords(with recordIDs: [CKRecord.ID]) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecord], any Error>) in
            let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
            operation.desiredKeys = [Field.mediaItemID, Field.asset]
            operation.qualityOfService = .userInitiated
            var records: [CKRecord] = []

            operation.perRecordResultBlock = { _, result in
                if case let .success(record) = result {
                    records.append(record)
                }
            }
            operation.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: records)
                case .failure:
                    continuation.resume(returning: records)
                }
            }
            database.add(operation)
        }
    }
}

private enum CloudKitSyncError: LocalizedError {
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "An iCloud sync record could not be read."
        }
    }
}
