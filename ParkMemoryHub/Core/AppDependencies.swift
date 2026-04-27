import Foundation

struct AppDependencies: Sendable {
    let memories: any MemoryRepository
    let activities: any ActivityRepository
    let family: any FamilyRepository
    let groups: any GroupRepository
    let activeGroup: GroupSpace
    let preferences: any PreferencesRepository
    let syncEvents: any SyncEventRepository

    static func production() -> AppDependencies {
        let identity = FileDeviceIdentityStore.loadOrCreate()

        return baseDependencies(
            memories: FileMemoryRepository(
                defaultGroupID: identity.groupID,
                defaultMemberID: identity.memberID
            ),
            activities: FileActivityRepository(
                defaultGroupID: identity.groupID,
                defaultMemberID: identity.memberID
            ),
            syncEvents: FileSyncEventRepository(),
            identity: identity,
            useFileBackedProfile: true
        )
    }

    static func preview() -> AppDependencies {
        let identity = DeviceIdentity(
            groupID: UUID(uuidString: "8B713551-0360-42A1-A3F2-E82132979F65")!,
            memberID: UUID(uuidString: "03F75945-4972-4ED6-AEE4-F51B84938938")!,
            groupDisplayName: "Family Trip"
        )

        return baseDependencies(
            memories: InMemoryMemoryRepository(),
            activities: InMemoryActivityRepository(),
            syncEvents: InMemorySyncEventRepository(),
            identity: identity
        )
    }

    private static func baseDependencies(
        memories: any MemoryRepository,
        activities: any ActivityRepository,
        syncEvents: any SyncEventRepository,
        identity: DeviceIdentity,
        useFileBackedProfile: Bool = false
    ) -> AppDependencies {
        let group = GroupSpace(
            id: identity.groupID,
            displayName: identity.groupDisplayName,
            createdByMemberID: identity.memberID,
            createdAt: identity.createdAt,
            updatedAt: identity.createdAt
        )

        let currentUser = FamilyMember(
            id: identity.memberID,
            groupID: group.id,
            displayName: "Me",
            role: .owner,
            isCurrentUser: true,
            sharesLocation: false,
            lastSeenAt: Date(),
            joinedAt: identity.createdAt
        )

        let familyMembers: [FamilyMember] = []

        let allMembers = [currentUser] + familyMembers
        let familyRepository: any FamilyRepository = useFileBackedProfile
            ? FileFamilyRepository(defaultMemberID: identity.memberID, seedMembers: allMembers)
            : InMemoryFamilyRepository(currentMember: currentUser, members: familyMembers)
        let preferencesRepository: any PreferencesRepository = useFileBackedProfile
            ? FilePreferencesRepository()
            : InMemoryPreferencesRepository()

        return AppDependencies(
            memories: memories,
            activities: activities,
            family: familyRepository,
            groups: InMemoryGroupRepository(activeGroup: group),
            activeGroup: group,
            preferences: preferencesRepository,
            syncEvents: syncEvents
        )
    }
}
