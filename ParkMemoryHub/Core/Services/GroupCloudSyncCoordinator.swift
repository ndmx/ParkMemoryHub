import CloudKit
import Foundation

struct GroupCloudSyncResult: Equatable, Sendable {
    var pushedCount: Int
    var checkedCount: Int
    var appliedCount: Int
}

struct GroupCloudSyncCoordinator: Sendable {
    private let familyRepository: any FamilyRepository
    private let memoryRepository: any MemoryRepository
    private let activitiesRepository: any ActivityRepository
    private let syncEventRepository: any SyncEventRepository
    private let cloudSyncService: CloudKitSyncService
    private let activeGroup: GroupSpace

    init(
        familyRepository: any FamilyRepository,
        memoryRepository: any MemoryRepository,
        activitiesRepository: any ActivityRepository,
        syncEventRepository: any SyncEventRepository,
        activeGroup: GroupSpace,
        cloudSyncService: CloudKitSyncService = CloudKitSyncService()
    ) {
        self.familyRepository = familyRepository
        self.memoryRepository = memoryRepository
        self.activitiesRepository = activitiesRepository
        self.syncEventRepository = syncEventRepository
        self.activeGroup = activeGroup
        self.cloudSyncService = cloudSyncService
    }

    func sync(currentMemberID: FamilyMember.ID?) async throws -> GroupCloudSyncResult {
        let snapshotMemberID = try await appendCurrentMemberSnapshot()
        let localMemberID = currentMemberID ?? snapshotMemberID
        let localEvents = try await syncEventRepository.listEvents(groupID: activeGroup.id)
        let pushedCount = try await cloudSyncService.push(events: localEvents)
        let cloudEvents = try await cloudSyncService.pull(groupID: activeGroup.id)
        let appliedCount = try await apply(events: cloudEvents, currentMemberID: localMemberID)
        try await syncEventRepository.appendEvents(cloudEvents)

        return GroupCloudSyncResult(
            pushedCount: pushedCount,
            checkedCount: cloudEvents.count,
            appliedCount: appliedCount
        )
    }

    func pushPendingEvents() async throws -> Int {
        let localEvents = try await syncEventRepository.listEvents(groupID: activeGroup.id)
        return try await cloudSyncService.push(events: localEvents)
    }

    func pullAndApply(currentMemberID: FamilyMember.ID?) async throws -> GroupCloudSyncResult {
        let localMemberID: FamilyMember.ID?
        if let currentMemberID {
            localMemberID = currentMemberID
        } else {
            localMemberID = try? await familyRepository.currentMember().id
        }
        let localEvents = try await syncEventRepository.listEvents(groupID: activeGroup.id)
        let pushedCount = try await cloudSyncService.push(events: localEvents)
        let cloudEvents = try await cloudSyncService.pull(groupID: activeGroup.id)
        let appliedCount = try await apply(events: cloudEvents, currentMemberID: localMemberID)
        try await syncEventRepository.appendEvents(cloudEvents)

        return GroupCloudSyncResult(
            pushedCount: pushedCount,
            checkedCount: cloudEvents.count,
            appliedCount: appliedCount
        )
    }

    @discardableResult
    func uploadMemoryMedia(for memory: ParkMemory) async throws -> Int {
        var mediaDataByItemID: [ParkMemory.MediaItem.ID: Data] = [:]

        for item in memory.displayMediaItems {
            if let mediaData = try await memoryRepository.mediaData(for: item) {
                mediaDataByItemID[item.id] = mediaData
            }
        }

        return try await cloudSyncService.uploadMemoryMedia(
            memory: memory,
            mediaDataByItemID: mediaDataByItemID
        )
    }

    @discardableResult
    func apply(events: [GroupSyncEvent], currentMemberID: FamilyMember.ID?) async throws -> Int {
        let localMemberID: FamilyMember.ID?
        if let currentMemberID {
            localMemberID = currentMemberID
        } else {
            localMemberID = try? await familyRepository.currentMember().id
        }
        var appliedCount = 0

        for event in events {
            try await apply(event, currentMemberID: localMemberID)
            appliedCount += 1
        }

        return appliedCount
    }

    private func appendCurrentMemberSnapshot() async throws -> FamilyMember.ID {
        let member = try await familyRepository.currentMember()
        let snapshotType: GroupSyncEvent.EventType = member.lastKnownLocation == nil
            ? .memberProfileUpdated
            : .memberLocationUpdated
        let event = try GroupSyncEvent(
            groupID: activeGroup.id,
            createdByMemberID: member.id,
            type: snapshotType,
            subjectID: member.id,
            payload: member
        )
        try await syncEventRepository.appendEvent(event)
        return member.id
    }

    private func apply(_ event: GroupSyncEvent, currentMemberID: FamilyMember.ID?) async throws {
        switch event.type {
        case .memberProfileUpdated, .memberLocationUpdated:
            var member = try event.decodedPayload(as: FamilyMember.self)
            if member.id == currentMemberID {
                return
            }

            member.groupID = activeGroup.id
            member.isCurrentUser = false
            _ = try await familyRepository.saveMember(member)
        case .planUpserted:
            var activity = try event.decodedPayload(as: ParkActivity.self)
            activity.groupID = activeGroup.id
            _ = try await activitiesRepository.saveActivity(activity)
        case .planDeleted:
            let deletedSubject = try event.decodedPayload(as: DeletedSyncSubject.self)
            try await activitiesRepository.deleteActivity(id: deletedSubject.id)
        case .memoryUpserted:
            var memory = try event.decodedPayload(as: ParkMemory.self)
            memory.groupID = activeGroup.id
            memory.localFileURL = nil
            memory.localMediaFilename = nil
            let mediaDataByItemID = try await cloudSyncService.downloadMemoryMedia(for: memory)

            memory.mediaItems = memory.displayMediaItems.map { item in
                var remoteItem = item
                remoteItem.groupID = activeGroup.id
                remoteItem.localFileURL = nil
                remoteItem.localMediaFilename = nil
                remoteItem.localCacheFilename = nil
                remoteItem.downloadState = mediaDataByItemID[item.id] == nil ? .availableForDownload : .downloaded
                return remoteItem
            }

            if mediaDataByItemID.isEmpty && !memory.displayMediaItems.isEmpty {
                memory.shareState = .unavailable
                _ = try await memoryRepository.saveMemory(memory)
            } else if mediaDataByItemID.isEmpty {
                memory.shareState = .shared
                _ = try await memoryRepository.saveMemory(memory)
            } else {
                memory.shareState = .shared
                _ = try await memoryRepository.saveMemory(memory, mediaDataByItemID: mediaDataByItemID)
            }
        case .memoryDeleted:
            let deletedSubject = try event.decodedPayload(as: DeletedSyncSubject.self)
            try await memoryRepository.deleteMemory(id: deletedSubject.id)
        }
    }
}

enum GroupCloudSyncErrorFormatter {
    static func message(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain {
            return "iCloud sync failed: \(error.localizedDescription). Make sure iCloud is enabled for this app and the CloudKit container exists for this Apple Developer account."
        }

        return error.localizedDescription
    }
}
