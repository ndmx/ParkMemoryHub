import Foundation

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published private(set) var memories: [ParkMemory] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var currentMember: FamilyMember?
    @Published private(set) var creatorNamesByID: [FamilyMember.ID: String] = [:]
    @Published private(set) var isSyncingICloud = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let repository: any MemoryRepository
    private let familyRepository: any FamilyRepository
    private let activeGroup: GroupSpace
    private let circleSync: any CircleSyncing

    init(
        repository: any MemoryRepository,
        familyRepository: any FamilyRepository,
        activeGroup: GroupSpace,
        circleSync: any CircleSyncing
    ) {
        self.repository = repository
        self.familyRepository = familyRepository
        self.activeGroup = activeGroup
        self.circleSync = circleSync
    }

    func loadMemories() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                async let loadedMemories = repository.listMemories()
                async let loadedCurrentMember = familyRepository.currentMember()
                async let loadedMembers = familyRepository.listMembers()

                let members = try await loadedMembers
                currentMember = try await loadedCurrentMember
                creatorNamesByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.displayName) })
                memories = try await loadedMemories
                try await refreshFromICloud(showStatus: false)
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    func createMemory(caption: String, tags: [String], location: ParkLocation?, mediaDataItems: [Data]) {
        let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCaption.isEmpty || !mediaDataItems.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let author: FamilyMember
                if let currentMember {
                    author = currentMember
                } else {
                    author = try await familyRepository.currentMember()
                }
                currentMember = author
                creatorNamesByID[author.id] = author.displayName

                let now = Date()
                let memory = ParkMemory(
                    groupID: activeGroup.id,
                    createdByMemberID: author.id,
                    caption: cleanCaption,
                    tags: tags,
                    location: location,
                    shareState: .localOnly,
                    createdAt: now,
                    updatedAt: now
                )

                let savedMemory = try await repository.saveMemory(memory, mediaDataItems: mediaDataItems)
                try await circleSync.pushMemory(savedMemory)
                memories = try await repository.listMemories()
            } catch {
                errorMessage = CircleSyncErrorFormatter.message(for: error)
            }

            isSaving = false
        }
    }

    func deleteMemory(_ memory: ParkMemory) {
        Task {
            do {
                try await repository.deleteMemory(id: memory.id)
                try await circleSync.deleteMemoryRemote(memory)
                memories.removeAll { $0.id == memory.id }
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

    func creatorName(for memory: ParkMemory) -> String? {
        guard let createdByMemberID = memory.createdByMemberID else {
            return nil
        }

        if createdByMemberID == currentMember?.id {
            return "You"
        }

        return creatorNamesByID[createdByMemberID]
    }

    private func refreshFromICloud(showStatus: Bool) async throws {
        let result = try await circleSync.refresh()
        async let loadedMemories = repository.listMemories()
        async let loadedCurrentMember = familyRepository.currentMember()
        async let loadedMembers = familyRepository.listMembers()

        let members = try await loadedMembers
        currentMember = try await loadedCurrentMember
        creatorNamesByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.displayName) })
        memories = try await loadedMemories

        if showStatus {
            statusMessage = "Memories synced. Checked \(result.checkedCount) iCloud update\(result.checkedCount == 1 ? "" : "s")."
        }
    }
}
