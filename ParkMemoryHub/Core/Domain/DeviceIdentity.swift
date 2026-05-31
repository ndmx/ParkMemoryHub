import Foundation

/// Whether this device created the circle (and hosts its CloudKit zone in its
/// own private database) or joined someone else's circle as a share participant.
enum CircleRole: String, Codable, Sendable {
    case owner
    case participant
}

struct DeviceIdentity: Codable, Equatable, Sendable {
    var groupID: GroupSpace.ID
    var memberID: FamilyMember.ID
    var groupDisplayName: String
    var createdAt: Date
    /// The device's relationship to the active circle.
    var role: CircleRole
    /// CloudKit custom-zone name backing the circle. For an owner this is derived
    /// from `groupID`; for a participant it comes from the accepted share metadata.
    var zoneName: String
    /// The CloudKit record-zone owner name. `nil` for an owner (the current user);
    /// set to the share owner's record name when joined as a participant.
    var zoneOwnerName: String?

    private enum CodingKeys: String, CodingKey {
        case groupID
        case memberID
        case groupDisplayName
        case createdAt
        case role
        case zoneName
        case zoneOwnerName
    }

    init(
        groupID: GroupSpace.ID = UUID(),
        memberID: FamilyMember.ID = UUID(),
        groupDisplayName: String = "My Circle",
        createdAt: Date = Date(),
        role: CircleRole = .owner,
        zoneName: String? = nil,
        zoneOwnerName: String? = nil
    ) {
        self.groupID = groupID
        self.memberID = memberID
        self.groupDisplayName = groupDisplayName
        self.createdAt = createdAt
        self.role = role
        self.zoneName = zoneName ?? Self.defaultZoneName(for: groupID)
        self.zoneOwnerName = zoneOwnerName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let groupID = try container.decodeIfPresent(GroupSpace.ID.self, forKey: .groupID) ?? UUID()
        self.groupID = groupID
        self.memberID = try container.decodeIfPresent(FamilyMember.ID.self, forKey: .memberID) ?? UUID()
        self.groupDisplayName = try container.decodeIfPresent(String.self, forKey: .groupDisplayName) ?? "My Circle"
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.role = try container.decodeIfPresent(CircleRole.self, forKey: .role) ?? .owner
        self.zoneName = try container.decodeIfPresent(String.self, forKey: .zoneName) ?? Self.defaultZoneName(for: groupID)
        self.zoneOwnerName = try container.decodeIfPresent(String.self, forKey: .zoneOwnerName)
    }

    static func defaultZoneName(for groupID: GroupSpace.ID) -> String {
        "Circle-\(groupID.uuidString)"
    }
}

extension Notification.Name {
    /// Posted when the active circle changes (new circle started, or a shared
    /// circle joined) so the UI can rebuild its dependencies.
    static let parkMemoryHubGroupDidChange = Notification.Name("parkMemoryHubGroupDidChange")
}
