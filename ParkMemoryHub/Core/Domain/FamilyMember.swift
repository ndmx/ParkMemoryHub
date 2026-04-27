import Foundation

struct FamilyMember: Identifiable, Codable, Equatable, Sendable {
    enum Role: String, Codable, CaseIterable, Sendable {
        case owner
        case admin
        case member
    }

    let id: UUID
    var groupID: GroupSpace.ID?
    var displayName: String
    var avatarLocalAssetIdentifier: String?
    var role: Role
    var isCurrentUser: Bool
    var sharesLocation: Bool
    var lastKnownLocation: ParkLocation?
    var lastSeenAt: Date?
    var joinedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case groupID
        case displayName
        case avatarLocalAssetIdentifier
        case role
        case isCurrentUser
        case sharesLocation
        case lastKnownLocation
        case lastSeenAt
        case joinedAt
    }

    init(
        id: UUID = UUID(),
        groupID: GroupSpace.ID? = nil,
        displayName: String,
        avatarLocalAssetIdentifier: String? = nil,
        role: Role = .member,
        isCurrentUser: Bool = false,
        sharesLocation: Bool = true,
        lastKnownLocation: ParkLocation? = nil,
        lastSeenAt: Date? = nil,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.groupID = groupID
        self.displayName = displayName
        self.avatarLocalAssetIdentifier = avatarLocalAssetIdentifier
        self.role = role
        self.isCurrentUser = isCurrentUser
        self.sharesLocation = sharesLocation
        self.lastKnownLocation = lastKnownLocation
        self.lastSeenAt = lastSeenAt
        self.joinedAt = joinedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.groupID = try container.decodeIfPresent(GroupSpace.ID.self, forKey: .groupID)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "Member"
        self.avatarLocalAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .avatarLocalAssetIdentifier)
        self.role = try container.decodeIfPresent(Role.self, forKey: .role) ?? .member
        self.isCurrentUser = try container.decodeIfPresent(Bool.self, forKey: .isCurrentUser) ?? false
        self.sharesLocation = try container.decodeIfPresent(Bool.self, forKey: .sharesLocation) ?? true
        self.lastKnownLocation = try container.decodeIfPresent(ParkLocation.self, forKey: .lastKnownLocation)
        self.lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt)
        self.joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt) ?? Date()
    }
}
