import Foundation

@MainActor
final class RadarViewModel: ObservableObject {
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var currentMember: FamilyMember?
    @Published private(set) var isLoading = false
    @Published private(set) var isSavingLocation = false
    @Published var errorMessage: String?

    private let familyRepository: any FamilyRepository
    private let circleSync: any CircleSyncing
    private var hasLoaded = false
    let activeGroup: GroupSpace

    init(
        familyRepository: any FamilyRepository,
        activeGroup: GroupSpace,
        circleSync: any CircleSyncing
    ) {
        self.familyRepository = familyRepository
        self.activeGroup = activeGroup
        self.circleSync = circleSync
    }

    func loadMembers() {
        guard !isLoading else { return }

        let shouldShowFullScreenLoading = !hasLoaded && members.isEmpty
        isLoading = shouldShowFullScreenLoading
        errorMessage = nil

        Task {
            do {
                let member = try await familyRepository.currentMember()
                currentMember = member
                members = try await familyRepository.listMembers()
                hasLoaded = true
                isLoading = false

                _ = try await circleSync.refresh()
                members = try await familyRepository.listMembers()
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
                isLoading = false
            }
        }
    }

    func toggleSharing(for member: FamilyMember) {
        guard member.id == currentMember?.id else {
            return
        }

        var updatedMember = member
        updatedMember.sharesLocation.toggle()
        updatedMember.lastSeenAt = Date()

        Task {
            do {
                let savedMember = try await familyRepository.saveMember(updatedMember)
                try await circleSync.pushMember(savedMember, avatarData: nil)
                currentMember = savedMember
                members = try await familyRepository.listMembers()
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
            }
        }
    }

    func updateCurrentLocation(_ location: ParkLocation) {
        guard var member = currentMember else {
            return
        }

        member.sharesLocation = true
        member.lastKnownLocation = location
        member.lastSeenAt = Date()
        isSavingLocation = true
        errorMessage = nil

        Task {
            do {
                let savedMember = try await familyRepository.saveMember(member)
                try await circleSync.pushMember(savedMember, avatarData: nil)
                currentMember = savedMember
                members = try await familyRepository.listMembers()
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
            }

            isSavingLocation = false
        }
    }
}
