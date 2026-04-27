import Foundation

struct GroupSpace: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    var createdByMemberID: FamilyMember.ID?
    var createdAt: Date
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case createdByMemberID
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        createdByMemberID: FamilyMember.ID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.createdByMemberID = createdByMemberID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "Circle"
        self.createdByMemberID = try container.decodeIfPresent(FamilyMember.ID.self, forKey: .createdByMemberID)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}
