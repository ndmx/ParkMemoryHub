import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var currentMember: FamilyMember?
    @Published private(set) var members: [FamilyMember] = []
    @Published var displayName = ""
    @Published private(set) var avatarImageData: Data?
    @Published var preferences = UserPreferences()
    @Published private(set) var syncEventCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var isSyncingICloud = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    var hasUnsavedChanges: Bool {
        preferences != lastSavedPreferences
    }

    private let familyRepository: any FamilyRepository
    private let memoryRepository: any MemoryRepository
    private let activitiesRepository: any ActivityRepository
    private let preferencesRepository: any PreferencesRepository
    private let syncEventRepository: any SyncEventRepository
    private var lastSavedPreferences = UserPreferences()
    let activeGroup: GroupSpace

    private var cloudSyncCoordinator: GroupCloudSyncCoordinator {
        GroupCloudSyncCoordinator(
            familyRepository: familyRepository,
            memoryRepository: memoryRepository,
            activitiesRepository: activitiesRepository,
            syncEventRepository: syncEventRepository,
            activeGroup: activeGroup
        )
    }

    init(
        familyRepository: any FamilyRepository,
        memoryRepository: any MemoryRepository,
        activitiesRepository: any ActivityRepository,
        preferencesRepository: any PreferencesRepository,
        activeGroup: GroupSpace,
        syncEventRepository: any SyncEventRepository
    ) {
        self.familyRepository = familyRepository
        self.memoryRepository = memoryRepository
        self.activitiesRepository = activitiesRepository
        self.preferencesRepository = preferencesRepository
        self.activeGroup = activeGroup
        self.syncEventRepository = syncEventRepository
    }

    var visibleGroup: GroupSpace {
        var group = activeGroup
        group.displayName = visibleGroupDisplayName
        return group
    }

    var visibleGroupDisplayName: String {
        if activeGroup.displayName.isGenericCircleName {
            return Self.circleName(for: displayName)
        }

        return activeGroup.displayName
    }

    func load() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                async let loadedCurrentMember = familyRepository.currentMember()
                async let loadedMembers = familyRepository.listMembers()
                async let loadedPreferences = preferencesRepository.loadPreferences()
                async let loadedSyncEvents = syncEventRepository.listEvents(groupID: activeGroup.id)

                let member = try await loadedCurrentMember
                var loadedPreferencesValue = try await loadedPreferences
                loadedPreferencesValue.shareLocation = member.sharesLocation

                currentMember = member
                members = try await loadedMembers
                displayName = member.displayName
                avatarImageData = FileProfileAvatarStore.avatarData(filename: member.avatarLocalAssetIdentifier)
                preferences = loadedPreferencesValue
                lastSavedPreferences = loadedPreferencesValue
                syncEventCount = try await loadedSyncEvents.count
                try await refreshFromICloud(showStatus: false)
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    func saveProfile() {
        saveProfile(displayName: displayName, avatarImageData: nil)
    }

    func saveProfile(displayName newDisplayName: String, avatarImageData newAvatarImageData: Data?) {
        guard var member = currentMember else {
            return
        }

        let cleanDisplayName = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDisplayName.isEmpty else {
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let previousDisplayName = member.displayName
                member.displayName = cleanDisplayName
                member.sharesLocation = preferences.shareLocation
                member.lastSeenAt = Date()
                if let newAvatarImageData {
                    member.avatarLocalAssetIdentifier = try FileProfileAvatarStore.saveAvatarData(
                        newAvatarImageData,
                        memberID: member.id
                    )
                    avatarImageData = newAvatarImageData
                }

                try await preferencesRepository.savePreferences(preferences)
                let savedMember = try await familyRepository.saveMember(member)
                lastSavedPreferences = preferences
                if shouldRenameCircle(afterChangingFrom: previousDisplayName) {
                    try FileDeviceIdentityStore.updateGroupDisplayName(Self.circleName(for: cleanDisplayName))
                    NotificationCenter.default.post(name: .parkMemoryHubGroupDidChange, object: nil)
                }
                try await recordSyncEvent(
                    type: .memberProfileUpdated,
                    subjectID: savedMember.id,
                    createdByMemberID: savedMember.id,
                    payload: savedMember
                )
                _ = try await cloudSyncCoordinator.pushPendingEvents()
                currentMember = savedMember
                members = try await familyRepository.listMembers()
                displayName = currentMember?.displayName ?? cleanDisplayName
                syncEventCount = try await syncEventRepository.listEvents(groupID: activeGroup.id).count
            } catch {
                errorMessage = error.localizedDescription
            }

            isSaving = false
        }
    }

    func leaveGroup() {
        errorMessage = nil
        statusMessage = nil

        do {
            let circleName = Self.circleName(for: displayName)
            let identity = try FileDeviceIdentityStore.createNewCircle(displayName: circleName)
            statusMessage = "Left the circle. This device is now using \(circleName) with circle code \(String(identity.groupID.uuidString.prefix(8)).uppercased())."
            NotificationCenter.default.post(name: .parkMemoryHubGroupDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startNewCircle() {
        errorMessage = nil
        statusMessage = nil

        do {
            let circleName = Self.circleName(for: displayName)
            let identity = try FileDeviceIdentityStore.createNewCircle(displayName: circleName)
            statusMessage = "Started \(circleName). Circle code \(String(identity.groupID.uuidString.prefix(8)).uppercased())."
            NotificationCenter.default.post(name: .parkMemoryHubGroupDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
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
                errorMessage = GroupCloudSyncErrorFormatter.message(for: error)
            }

            isSyncingICloud = false
        }
    }

    private func recordSyncEvent<Payload: Encodable>(
        type: GroupSyncEvent.EventType,
        subjectID: UUID?,
        createdByMemberID: FamilyMember.ID?,
        payload: Payload
    ) async throws {
        let event = try GroupSyncEvent(
            groupID: activeGroup.id,
            createdByMemberID: createdByMemberID,
            type: type,
            subjectID: subjectID,
            payload: payload
        )

        try await syncEventRepository.appendEvent(event)
    }

    private func shouldRenameCircle(afterChangingFrom previousDisplayName: String) -> Bool {
        let previousCircleName = Self.circleName(for: previousDisplayName)
        return activeGroup.displayName.isGenericCircleName || activeGroup.displayName == previousCircleName
    }

    private func refreshFromICloud(showStatus: Bool) async throws {
        let result = try await cloudSyncCoordinator.sync(currentMemberID: currentMember?.id)
        syncEventCount = try await syncEventRepository.listEvents(groupID: activeGroup.id).count
        members = try await familyRepository.listMembers()

        if showStatus {
            statusMessage = "iCloud sync complete. Pushed \(result.pushedCount) update\(result.pushedCount == 1 ? "" : "s") and checked \(result.checkedCount) cloud update\(result.checkedCount == 1 ? "" : "s")."
        }
    }

    private static func circleName(for displayName: String) -> String {
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty || cleanName.lowercased() == "me" {
            return "My Circle"
        }

        return "\(cleanName)'s Circle"
    }

}

private extension String {
    var isGenericCircleName: Bool {
        let cleanValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanValue.isEmpty || cleanValue == "My Circle" || cleanValue == "My Group" || cleanValue == "Group"
    }
}
