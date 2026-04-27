import Foundation

struct GroupSyncEvent: Identifiable, Codable, Equatable, Sendable {
    enum EventType: String, Codable, CaseIterable, Sendable {
        case memberProfileUpdated
        case memberLocationUpdated
        case planUpserted
        case planDeleted
        case memoryUpserted
        case memoryDeleted
    }

    let id: UUID
    var groupID: GroupSpace.ID
    var createdByMemberID: FamilyMember.ID?
    var type: EventType
    var subjectID: UUID?
    var payload: Data
    var createdAt: Date

    init<Payload: Encodable>(
        id: UUID = UUID(),
        groupID: GroupSpace.ID,
        createdByMemberID: FamilyMember.ID?,
        type: EventType,
        subjectID: UUID?,
        payload: Payload,
        createdAt: Date = Date(),
        encoder: JSONEncoder = GroupSyncEvent.payloadEncoder
    ) throws {
        self.id = id
        self.groupID = groupID
        self.createdByMemberID = createdByMemberID
        self.type = type
        self.subjectID = subjectID
        self.payload = try encoder.encode(payload)
        self.createdAt = createdAt
    }

    init(
        id: UUID,
        groupID: GroupSpace.ID,
        createdByMemberID: FamilyMember.ID?,
        type: EventType,
        subjectID: UUID?,
        payload: Data,
        createdAt: Date
    ) {
        self.id = id
        self.groupID = groupID
        self.createdByMemberID = createdByMemberID
        self.type = type
        self.subjectID = subjectID
        self.payload = payload
        self.createdAt = createdAt
    }

    func decodedPayload<Payload: Decodable>(
        as payloadType: Payload.Type,
        decoder: JSONDecoder = GroupSyncEvent.payloadDecoder
    ) throws -> Payload {
        try decoder.decode(payloadType, from: payload)
    }

    static let payloadEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let payloadDecoder = JSONDecoder()
}

struct DeletedSyncSubject: Codable, Equatable, Sendable {
    var id: UUID
    var deletedAt: Date
}
