import Foundation

actor FileActivityRepository: ActivityRepository {
    private let metadataURL: URL
    private let defaultGroupID: GroupSpace.ID?
    private let defaultMemberID: FamilyMember.ID?

    init(
        rootDirectoryURL: URL? = nil,
        defaultGroupID: GroupSpace.ID? = nil,
        defaultMemberID: FamilyMember.ID? = nil
    ) {
        let baseDirectory = rootDirectoryURL
            ?? FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("ParkMemoryHub", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ParkMemoryHub", isDirectory: true)

        let plannerDirectoryURL = baseDirectory.appendingPathComponent("Planner", isDirectory: true)
        self.metadataURL = plannerDirectoryURL.appendingPathComponent("activities.json")
        self.defaultGroupID = defaultGroupID
        self.defaultMemberID = defaultMemberID
    }

    func listActivities() async throws -> [ParkActivity] {
        try loadActivities()
            .map(normalizedActivity)
            .filter { $0.isVisible(to: defaultMemberID) }
            .sorted(by: activitySort)
    }

    func activity(id: ParkActivity.ID) async throws -> ParkActivity? {
        try loadActivities()
            .map(normalizedActivity)
            .first { $0.id == id && $0.isVisible(to: defaultMemberID) }
    }

    @discardableResult
    func saveActivity(_ activity: ParkActivity) async throws -> ParkActivity {
        try ensureStorageExists()

        var activities = try loadActivities()
        activities.removeAll { $0.id == activity.id }

        var savedActivity = normalizedActivity(activity)
        savedActivity.updatedAt = Date()
        activities.append(savedActivity)
        try persist(activities)

        return savedActivity
    }

    func vote(activityID: ParkActivity.ID, memberID: FamilyMember.ID, vote: ParkActivity.Vote) async throws {
        var activities = try loadActivities()
        guard let index = activities.firstIndex(where: { $0.id == activityID }) else {
            return
        }

        activities[index].votesByMemberID[memberID] = vote
        activities[index].updatedAt = Date()
        try persist(activities.map(normalizedActivity))
    }

    func deleteActivity(id: ParkActivity.ID) async throws {
        var activities = try loadActivities()
        activities.removeAll { $0.id == id }
        try persist(activities)
    }

    private func ensureStorageExists() throws {
        try FileManager.default.createDirectory(
            at: metadataURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func loadActivities() throws -> [ParkActivity] {
        try ensureStorageExists()

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return []
        }

        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder().decode([ParkActivity].self, from: data)
    }

    private func persist(_ activities: [ParkActivity]) throws {
        try ensureStorageExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(activities)
        try data.write(to: metadataURL, options: [.atomic])
    }

    private func normalizedActivity(_ activity: ParkActivity) -> ParkActivity {
        var normalized = activity

        if normalized.groupID == nil {
            normalized.groupID = defaultGroupID
        }

        if normalized.createdByMemberID == nil {
            normalized.createdByMemberID = defaultMemberID
        }

        if normalized.updatedAt < normalized.createdAt {
            normalized.updatedAt = normalized.createdAt
        }

        return normalized
    }

    private func activitySort(_ lhs: ParkActivity, _ rhs: ParkActivity) -> Bool {
        switch (lhs.scheduledAt, rhs.scheduledAt) {
        case let (lhs?, rhs?):
            return lhs < rhs
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.createdAt > rhs.createdAt
        }
    }
}
