import Foundation

actor FileSyncEventRepository: SyncEventRepository {
    private let metadataURL: URL

    init(rootDirectoryURL: URL? = nil) {
        let baseDirectory = rootDirectoryURL
            ?? FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("ParkMemoryHub", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ParkMemoryHub", isDirectory: true)

        let syncDirectoryURL = baseDirectory.appendingPathComponent("Sync", isDirectory: true)
        self.metadataURL = syncDirectoryURL.appendingPathComponent("events.json")
    }

    func listEvents(groupID: GroupSpace.ID?) async throws -> [GroupSyncEvent] {
        let events = try loadEvents()
        let filteredEvents = groupID.map { id in
            events.filter { $0.groupID == id }
        } ?? events

        return filteredEvents.sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func appendEvent(_ event: GroupSyncEvent) async throws -> GroupSyncEvent {
        var events = try loadEvents()

        if !events.contains(where: { $0.id == event.id }) {
            events.append(event)
            try persist(events)
        }

        return event
    }

    func appendEvents(_ newEvents: [GroupSyncEvent]) async throws {
        var events = try loadEvents()
        let existingIDs = Set(events.map(\.id))
        let uniqueEvents = newEvents.filter { !existingIDs.contains($0.id) }

        guard !uniqueEvents.isEmpty else {
            return
        }

        events.append(contentsOf: uniqueEvents)
        try persist(events)
    }

    private func ensureStorageExists() throws {
        try FileManager.default.createDirectory(
            at: metadataURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func loadEvents() throws -> [GroupSyncEvent] {
        try ensureStorageExists()

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return []
        }

        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder().decode([GroupSyncEvent].self, from: data)
    }

    private func persist(_ events: [GroupSyncEvent]) throws {
        try ensureStorageExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(events.sorted { $0.createdAt < $1.createdAt })
        try data.write(to: metadataURL, options: [.atomic])
    }
}
