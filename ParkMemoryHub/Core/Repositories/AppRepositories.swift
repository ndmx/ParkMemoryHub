import Foundation

protocol MemoryRepository: Sendable {
    func listMemories() async throws -> [ParkMemory]
    func memory(id: ParkMemory.ID) async throws -> ParkMemory?
    func mediaData(for memory: ParkMemory) async throws -> Data?
    func mediaData(for item: ParkMemory.MediaItem) async throws -> Data?
    @discardableResult
    func saveMemory(_ memory: ParkMemory) async throws -> ParkMemory
    @discardableResult
    func saveMemory(_ memory: ParkMemory, mediaData: Data?) async throws -> ParkMemory
    @discardableResult
    func saveMemory(_ memory: ParkMemory, mediaDataItems: [Data]) async throws -> ParkMemory
    @discardableResult
    func saveMemory(_ memory: ParkMemory, mediaDataByItemID: [ParkMemory.MediaItem.ID: Data]) async throws -> ParkMemory
    func deleteMemory(id: ParkMemory.ID) async throws
}

protocol ActivityRepository: Sendable {
    func listActivities() async throws -> [ParkActivity]
    func activity(id: ParkActivity.ID) async throws -> ParkActivity?
    @discardableResult
    func saveActivity(_ activity: ParkActivity) async throws -> ParkActivity
    func vote(activityID: ParkActivity.ID, memberID: FamilyMember.ID, vote: ParkActivity.Vote) async throws
    func deleteActivity(id: ParkActivity.ID) async throws
}

protocol FamilyRepository: Sendable {
    func currentMember() async throws -> FamilyMember
    func listMembers() async throws -> [FamilyMember]
    @discardableResult
    func saveMember(_ member: FamilyMember) async throws -> FamilyMember
}

protocol GroupRepository: Sendable {
    func activeGroup() async throws -> GroupSpace
    func listGroups() async throws -> [GroupSpace]
    @discardableResult
    func saveGroup(_ group: GroupSpace) async throws -> GroupSpace
}

protocol PreferencesRepository: Sendable {
    func loadPreferences() async throws -> UserPreferences
    func savePreferences(_ preferences: UserPreferences) async throws
}
