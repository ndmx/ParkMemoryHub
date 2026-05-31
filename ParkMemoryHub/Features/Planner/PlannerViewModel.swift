import Foundation

@MainActor
final class PlannerViewModel: ObservableObject {
    @Published private(set) var activities: [ParkActivity] = []
    @Published private(set) var currentMember: FamilyMember?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var memberNamesByID: [FamilyMember.ID: String] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isSyncingICloud = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let activitiesRepository: any ActivityRepository
    private let familyRepository: any FamilyRepository
    private let activeGroup: GroupSpace
    private let circleSync: any CircleSyncing
    private var hasLoaded = false

    init(
        activitiesRepository: any ActivityRepository,
        familyRepository: any FamilyRepository,
        activeGroup: GroupSpace,
        circleSync: any CircleSyncing
    ) {
        self.activitiesRepository = activitiesRepository
        self.familyRepository = familyRepository
        self.activeGroup = activeGroup
        self.circleSync = circleSync
    }

    func load() {
        guard !isLoading else { return }

        let shouldShowFullScreenLoading = !hasLoaded && activities.isEmpty
        isLoading = shouldShowFullScreenLoading
        errorMessage = nil

        Task {
            do {
                async let loadedCurrentMember = familyRepository.currentMember()
                async let loadedMembers = familyRepository.listMembers()
                async let loadedActivities = activitiesRepository.listActivities()

                currentMember = try await loadedCurrentMember
                members = try await loadedMembers
                memberNamesByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.displayName) })
                activities = try await loadedActivities
                hasLoaded = true
                isLoading = false

                try await refreshFromICloud(showStatus: false)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func createActivity(
        title: String,
        notes: String,
        scheduledAt: Date?,
        location: ParkLocation?,
        visibility: ParkActivity.Visibility,
        sharedWithMemberIDs: [FamilyMember.ID]
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        Task {
            do {
                let author: FamilyMember
                if let currentMember {
                    author = currentMember
                } else {
                    author = try await familyRepository.currentMember()
                }
                currentMember = author
                let now = Date()
                let activity = ParkActivity(
                    groupID: activeGroup.id,
                    createdByMemberID: author.id,
                    title: cleanTitle,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    location: location,
                    scheduledAt: scheduledAt,
                    visibility: visibility,
                    sharedWithMemberIDs: sharedWithMemberIDs,
                    votesByMemberID: [author.id: .yes],
                    createdAt: now,
                    updatedAt: now
                )

                let savedActivity = try await activitiesRepository.saveActivity(activity)
                try await circleSync.pushPlan(savedActivity)
                activities = try await activitiesRepository.listActivities()
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
            }
        }
    }

    func vote(on activity: ParkActivity, vote: ParkActivity.Vote) {
        guard let currentMember else { return }

        Task {
            do {
                try await activitiesRepository.vote(
                    activityID: activity.id,
                    memberID: currentMember.id,
                    vote: vote
                )
                activities = try await activitiesRepository.listActivities()
                if let updatedActivity = activities.first(where: { $0.id == activity.id }) {
                    try await circleSync.pushPlan(updatedActivity)
                }
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
            }
        }
    }

    func updateStatus(for activity: ParkActivity, status: ParkActivity.Status) {
        var updatedActivity = activity
        updatedActivity.status = status
        updatedActivity.updatedAt = Date()

        Task {
            do {
                let savedActivity = try await activitiesRepository.saveActivity(updatedActivity)
                try await circleSync.pushPlan(savedActivity)
                activities = try await activitiesRepository.listActivities()
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
            }
        }
    }

    func deleteActivity(_ activity: ParkActivity) {
        Task {
            do {
                try await activitiesRepository.deleteActivity(id: activity.id)
                try await circleSync.deletePlanRemote(id: activity.id)
                activities.removeAll { $0.id == activity.id }
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
            }
        }
    }

    func syncWithICloud() {
        isSyncingICloud = true
        errorMessage = nil
        statusMessage = nil

        Task {
            do {
                try await refreshFromICloud(showStatus: true)
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
            }

            isSyncingICloud = false
        }
    }

    func creatorName(for activity: ParkActivity) -> String? {
        guard let createdByMemberID = activity.createdByMemberID else {
            return nil
        }

        if createdByMemberID == currentMember?.id {
            return "You"
        }

        return memberNamesByID[createdByMemberID]
    }

    private func refreshFromICloud(showStatus: Bool) async throws {
        let result = try await circleSync.refresh()
        async let loadedCurrentMember = familyRepository.currentMember()
        async let loadedMembers = familyRepository.listMembers()
        async let loadedActivities = activitiesRepository.listActivities()

        currentMember = try await loadedCurrentMember
        members = try await loadedMembers
        memberNamesByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.displayName) })
        activities = try await loadedActivities

        if showStatus {
            statusMessage = "Planner synced. Checked \(result.checkedCount) iCloud update\(result.checkedCount == 1 ? "" : "s")."
        }
    }
}
