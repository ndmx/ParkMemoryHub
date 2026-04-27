import Foundation

struct DeviceIdentity: Codable, Equatable, Sendable {
    var groupID: GroupSpace.ID
    var memberID: FamilyMember.ID
    var groupDisplayName: String
    var createdAt: Date

    init(
        groupID: GroupSpace.ID = UUID(),
        memberID: FamilyMember.ID = UUID(),
        groupDisplayName: String = "My Circle",
        createdAt: Date = Date()
    ) {
        self.groupID = groupID
        self.memberID = memberID
        self.groupDisplayName = groupDisplayName
        self.createdAt = createdAt
    }
}
