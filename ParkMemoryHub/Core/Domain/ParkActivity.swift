import Foundation

struct ParkActivity: Identifiable, Codable, Equatable, Sendable {
    enum Vote: String, Codable, CaseIterable, Sendable {
        case yes
        case maybe
        case no
    }

    enum Status: String, Codable, CaseIterable, Sendable {
        case planned
        case confirmed
        case completed
        case cancelled
    }

    enum Visibility: String, Codable, CaseIterable, Sendable {
        case circle
        case selectedMembers
        case onlyMe
    }

    let id: UUID
    var groupID: GroupSpace.ID?
    var createdByMemberID: FamilyMember.ID?
    var title: String
    var notes: String
    var location: ParkLocation?
    var scheduledAt: Date?
    var status: Status
    var visibility: Visibility
    var sharedWithMemberIDs: [FamilyMember.ID]
    var votesByMemberID: [UUID: Vote]
    var createdAt: Date
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case groupID
        case createdByMemberID
        case title
        case notes
        case location
        case scheduledAt
        case status
        case visibility
        case sharedWithMemberIDs
        case votesByMemberID
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        groupID: GroupSpace.ID? = nil,
        createdByMemberID: FamilyMember.ID? = nil,
        title: String,
        notes: String = "",
        location: ParkLocation? = nil,
        scheduledAt: Date? = nil,
        status: Status = .planned,
        visibility: Visibility = .circle,
        sharedWithMemberIDs: [FamilyMember.ID] = [],
        votesByMemberID: [UUID: Vote] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.groupID = groupID
        self.createdByMemberID = createdByMemberID
        self.title = title
        self.notes = notes
        self.location = location
        self.scheduledAt = scheduledAt
        self.status = status
        self.visibility = visibility
        self.sharedWithMemberIDs = sharedWithMemberIDs
        self.votesByMemberID = votesByMemberID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.groupID = try container.decodeIfPresent(GroupSpace.ID.self, forKey: .groupID)
        self.createdByMemberID = try container.decodeIfPresent(FamilyMember.ID.self, forKey: .createdByMemberID)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Plan"
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.location = try container.decodeIfPresent(ParkLocation.self, forKey: .location)
        self.scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
        self.status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .planned
        self.visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .circle
        self.sharedWithMemberIDs = try container.decodeIfPresent([FamilyMember.ID].self, forKey: .sharedWithMemberIDs) ?? []
        self.votesByMemberID = try container.decodeIfPresent([UUID: Vote].self, forKey: .votesByMemberID) ?? [:]
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    var yesVoteCount: Int {
        votesByMemberID.values.filter { $0 == .yes }.count
    }

    func isVisible(to memberID: FamilyMember.ID?) -> Bool {
        switch visibility {
        case .circle:
            return true
        case .onlyMe:
            return createdByMemberID == memberID
        case .selectedMembers:
            guard let memberID else {
                return false
            }

            return createdByMemberID == memberID || sharedWithMemberIDs.contains(memberID)
        }
    }
}
