import CloudKit
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var currentMember: FamilyMember?
    @Published private(set) var members: [FamilyMember] = []
    @Published var displayName = ""
    @Published private(set) var avatarImageData: Data?
    @Published var preferences = UserPreferences()
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var isSyncingICloud = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    var hasUnsavedChanges: Bool {
        preferences != lastSavedPreferences
    }

    private let familyRepository: any FamilyRepository
    private let preferencesRepository: any PreferencesRepository
    private let circleSync: any CircleSyncing
    private var lastSavedPreferences = UserPreferences()
    private var hasLoaded = false
    let activeGroup: GroupSpace

    init(
        familyRepository: any FamilyRepository,
        preferencesRepository: any PreferencesRepository,
        activeGroup: GroupSpace,
        circleSync: any CircleSyncing
    ) {
        self.familyRepository = familyRepository
        self.preferencesRepository = preferencesRepository
        self.activeGroup = activeGroup
        self.circleSync = circleSync
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
        guard !isLoading else { return }

        let shouldShowFullScreenLoading = !hasLoaded && currentMember == nil
        isLoading = shouldShowFullScreenLoading
        errorMessage = nil

        Task {
            do {
                async let loadedCurrentMember = familyRepository.currentMember()
                async let loadedMembers = familyRepository.listMembers()
                async let loadedPreferences = preferencesRepository.loadPreferences()

                let member = try await loadedCurrentMember
                var loadedPreferencesValue = try await loadedPreferences
                loadedPreferencesValue.shareLocation = member.sharesLocation

                currentMember = member
                members = try await loadedMembers
                displayName = member.displayName
                avatarImageData = FileProfileAvatarStore.avatarData(filename: member.avatarLocalAssetIdentifier)
                preferences = loadedPreferencesValue
                lastSavedPreferences = loadedPreferencesValue
                hasLoaded = true
                isLoading = false

                try await refreshFromICloud(showStatus: false)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
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
                try await circleSync.pushMember(savedMember, avatarData: newAvatarImageData)
                currentMember = savedMember
                members = try await familyRepository.listMembers()
                displayName = currentMember?.displayName ?? cleanDisplayName
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
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
                errorMessage = CircleSyncErrorFormatter.message(for: error)
            }

            isSyncingICloud = false
        }
    }

    /// Owner-only: builds (or fetches) the circle's `CKShare` for the share sheet.
    func prepareShare() async throws -> (CKShare, CKContainer) {
        try await circleSync.prepareShare(displayName: visibleGroupDisplayName)
    }

    private func shouldRenameCircle(afterChangingFrom previousDisplayName: String) -> Bool {
        let previousCircleName = Self.circleName(for: previousDisplayName)
        return activeGroup.displayName.isGenericCircleName || activeGroup.displayName == previousCircleName
    }

    private func refreshFromICloud(showStatus: Bool) async throws {
        let result = try await circleSync.refresh()
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
