import Foundation

@MainActor
final class RadarViewModel: ObservableObject {
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var currentMember: FamilyMember?
    @Published private(set) var isLoading = false
    @Published private(set) var isSavingLocation = false
    @Published var errorMessage: String?

    private let familyRepository: any FamilyRepository
    private let memoryRepository: any MemoryRepository
    private let activitiesRepository: any ActivityRepository
    private let syncEventRepository: any SyncEventRepository
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
        activeGroup: GroupSpace,
        syncEventRepository: any SyncEventRepository
    ) {
        self.familyRepository = familyRepository
        self.memoryRepository = memoryRepository
        self.activitiesRepository = activitiesRepository
        self.activeGroup = activeGroup
        self.syncEventRepository = syncEventRepository
    }

    func loadMembers() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let member = try await familyRepository.currentMember()
                currentMember = member
                _ = try await cloudSyncCoordinator.sync(currentMemberID: member.id)
                members = try await familyRepository.listMembers()
            } catch {
                errorMessage = GroupCloudSyncErrorFormatter.message(for: error)
            }

            isLoading = false
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
                try await recordSyncEvent(
                    type: .memberProfileUpdated,
                    subjectID: savedMember.id,
                    createdByMemberID: savedMember.id,
                    payload: savedMember
                )
                _ = try await cloudSyncCoordinator.pushPendingEvents()
                currentMember = savedMember
                members = try await familyRepository.listMembers()
            } catch {
                errorMessage = GroupCloudSyncErrorFormatter.message(for: error)
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
                try await recordSyncEvent(
                    type: .memberLocationUpdated,
                    subjectID: savedMember.id,
                    createdByMemberID: savedMember.id,
                    payload: savedMember
                )
                _ = try await cloudSyncCoordinator.pushPendingEvents()
                currentMember = savedMember
                members = try await familyRepository.listMembers()
            } catch {
                errorMessage = GroupCloudSyncErrorFormatter.message(for: error)
            }

            isSavingLocation = false
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
}
