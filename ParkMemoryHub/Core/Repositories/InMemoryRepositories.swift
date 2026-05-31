import Foundation

actor InMemoryMemoryRepository: MemoryRepository {
    private var memories: [ParkMemory.ID: ParkMemory]

    init(memories: [ParkMemory] = []) {
        self.memories = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })
    }

    func listMemories() async throws -> [ParkMemory] {
        memories.values.sorted { $0.createdAt > $1.createdAt }
    }

    func memory(id: ParkMemory.ID) async throws -> ParkMemory? {
        memories[id]
    }

    func mediaData(for memory: ParkMemory) async throws -> Data? {
        nil
    }

    func mediaData(for item: ParkMemory.MediaItem) async throws -> Data? {
        nil
    }

    @discardableResult
    func saveMemory(_ memory: ParkMemory) async throws -> ParkMemory {
        memories[memory.id] = memory
        return memory
    }

    @discardableResult
    func saveMemory(_ memory: ParkMemory, mediaData: Data?) async throws -> ParkMemory {
        try await saveMemory(memory)
    }

    @discardableResult
    func saveMemory(_ memory: ParkMemory, mediaDataItems: [Data]) async throws -> ParkMemory {
        try await saveMemory(memory)
    }

    @discardableResult
    func saveMemory(_ memory: ParkMemory, mediaDataByItemID: [ParkMemory.MediaItem.ID: Data]) async throws -> ParkMemory {
        try await saveMemory(memory)
    }

    func deleteMemory(id: ParkMemory.ID) async throws {
        memories[id] = nil
    }
}

actor InMemoryActivityRepository: ActivityRepository {
    private var activities: [ParkActivity.ID: ParkActivity]

    init(activities: [ParkActivity] = []) {
        self.activities = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
    }

    func listActivities() async throws -> [ParkActivity] {
        activities.values.sorted {
            switch ($0.scheduledAt, $1.scheduledAt) {
            case let (lhs?, rhs?):
                return lhs < rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return $0.createdAt > $1.createdAt
            }
        }
    }

    func activity(id: ParkActivity.ID) async throws -> ParkActivity? {
        activities[id]
    }

    @discardableResult
    func saveActivity(_ activity: ParkActivity) async throws -> ParkActivity {
        var savedActivity = activity
        savedActivity.updatedAt = Date()
        activities[savedActivity.id] = savedActivity
        return savedActivity
    }

    func vote(activityID: ParkActivity.ID, memberID: FamilyMember.ID, vote: ParkActivity.Vote) async throws {
        guard var activity = activities[activityID] else { return }
        activity.votesByMemberID[memberID] = vote
        activity.updatedAt = Date()
        activities[activityID] = activity
    }

    func deleteActivity(id: ParkActivity.ID) async throws {
        activities[id] = nil
    }
}

actor InMemoryFamilyRepository: FamilyRepository {
    private var current: FamilyMember
    private var members: [FamilyMember.ID: FamilyMember]

    init(currentMember: FamilyMember, members: [FamilyMember] = []) {
        self.current = currentMember
        let allMembers = ([currentMember] + members)
        self.members = Dictionary(uniqueKeysWithValues: allMembers.map { ($0.id, $0) })
    }

    func currentMember() async throws -> FamilyMember {
        current
    }

    func listMembers() async throws -> [FamilyMember] {
        members.values.sorted { lhs, rhs in
            if lhs.isCurrentUser != rhs.isCurrentUser {
                return lhs.isCurrentUser
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    @discardableResult
    func saveMember(_ member: FamilyMember) async throws -> FamilyMember {
        members[member.id] = member
        if member.isCurrentUser {
            current = member
        }
        return member
    }
}

actor InMemoryGroupRepository: GroupRepository {
    private var active: GroupSpace
    private var groups: [GroupSpace.ID: GroupSpace]

    init(activeGroup: GroupSpace, groups: [GroupSpace] = []) {
        self.active = activeGroup
        let allGroups = ([activeGroup] + groups)
        self.groups = Dictionary(uniqueKeysWithValues: allGroups.map { ($0.id, $0) })
    }

    func activeGroup() async throws -> GroupSpace {
        active
    }

    func listGroups() async throws -> [GroupSpace] {
        groups.values.sorted {
            $0.updatedAt > $1.updatedAt
        }
    }

    @discardableResult
    func saveGroup(_ group: GroupSpace) async throws -> GroupSpace {
        groups[group.id] = group
        if group.id == active.id {
            active = group
        }
        return group
    }
}

actor InMemoryPreferencesRepository: PreferencesRepository {
    private var preferences: UserPreferences

    init(preferences: UserPreferences = UserPreferences()) {
        self.preferences = preferences
    }

    func loadPreferences() async throws -> UserPreferences {
        preferences
    }

    func savePreferences(_ preferences: UserPreferences) async throws {
        self.preferences = preferences
    }
}
