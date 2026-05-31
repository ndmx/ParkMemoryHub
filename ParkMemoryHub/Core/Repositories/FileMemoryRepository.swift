import Foundation

actor FileMemoryRepository: MemoryRepository {
    private let mediaDirectoryURL: URL
    private let metadataURL: URL
    private let defaultGroupID: GroupSpace.ID?
    private let defaultMemberID: FamilyMember.ID?
    private var _cache: [ParkMemory]?

    init(
        rootDirectoryURL: URL? = nil,
        defaultGroupID: GroupSpace.ID? = nil,
        defaultMemberID: FamilyMember.ID? = nil
    ) {
        let baseDirectory = rootDirectoryURL
            ?? FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("ParkMemoryHub", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ParkMemoryHub", isDirectory: true)

        let rootDirectoryURL = baseDirectory.appendingPathComponent("Memories", isDirectory: true)
        self.mediaDirectoryURL = rootDirectoryURL.appendingPathComponent("Media", isDirectory: true)
        self.metadataURL = rootDirectoryURL.appendingPathComponent("memories.json")
        self.defaultGroupID = defaultGroupID
        self.defaultMemberID = defaultMemberID
    }

    func listMemories() async throws -> [ParkMemory] {
        try loadMemories().map(normalizedMemory).sorted { $0.createdAt > $1.createdAt }
    }

    func memory(id: ParkMemory.ID) async throws -> ParkMemory? {
        try loadMemories().map(normalizedMemory).first { $0.id == id }
    }

    func mediaData(for memory: ParkMemory) async throws -> Data? {
        guard let mediaURL = resolvedMediaURL(for: memory) else {
            return nil
        }

        return try? Data(contentsOf: mediaURL)
    }

    func mediaData(for item: ParkMemory.MediaItem) async throws -> Data? {
        guard let mediaURL = resolvedMediaURL(for: item) else {
            return nil
        }

        return try? Data(contentsOf: mediaURL)
    }

    @discardableResult
    func saveMemory(_ memory: ParkMemory) async throws -> ParkMemory {
        try await saveMemory(memory, mediaData: nil)
    }

    @discardableResult
    func saveMemory(_ memory: ParkMemory, mediaData: Data?) async throws -> ParkMemory {
        if let mediaData {
            return try await saveMemory(memory, mediaDataItems: [mediaData])
        }

        try ensureStorageExists()

        var memories = try loadMemories()
        memories.removeAll { $0.id == memory.id }
        let savedMemory = normalizedMemory(memory)
        memories.append(savedMemory)
        try persist(memories)

        return savedMemory
    }

    @discardableResult
    func saveMemory(_ memory: ParkMemory, mediaDataItems: [Data]) async throws -> ParkMemory {
        try ensureStorageExists()

        var savedMemory = memory
        let now = Date()
        if savedMemory.groupID == nil {
            savedMemory.groupID = defaultGroupID
        }
        if savedMemory.createdByMemberID == nil {
            savedMemory.createdByMemberID = defaultMemberID
        }
        savedMemory.updatedAt = now

        if !mediaDataItems.isEmpty {
            savedMemory.mediaItems = try mediaDataItems.enumerated().map { index, mediaData in
                let mediaID = UUID()
                let filename = "\(memory.id.uuidString)-\(index)-\(mediaID.uuidString).photo"
                let mediaURL = mediaDirectoryURL.appendingPathComponent(filename)
                try mediaData.write(to: mediaURL, options: [.atomic])

                return ParkMemory.MediaItem(
                    id: mediaID,
                    memoryID: savedMemory.id,
                    groupID: savedMemory.groupID,
                    createdByMemberID: savedMemory.createdByMemberID,
                    kind: .photo,
                    localFileURL: mediaURL,
                    localMediaFilename: filename,
                    localCacheFilename: filename,
                    downloadState: .localOnly,
                    createdAt: now,
                    updatedAt: now
                )
            }

            let firstItem = savedMemory.mediaItems.first
            savedMemory.localFileURL = firstItem?.localFileURL
            savedMemory.localMediaFilename = firstItem?.localMediaFilename
            savedMemory.mediaKind = .photo
        }

        var memories = try loadMemories()
        memories.removeAll { $0.id == savedMemory.id }
        memories.append(savedMemory)
        try persist(memories)

        return savedMemory
    }

    @discardableResult
    func saveMemory(_ memory: ParkMemory, mediaDataByItemID: [ParkMemory.MediaItem.ID: Data]) async throws -> ParkMemory {
        try ensureStorageExists()

        guard !mediaDataByItemID.isEmpty else {
            return try await saveMemory(memory)
        }

        var savedMemory = memory
        let now = Date()
        if savedMemory.groupID == nil {
            savedMemory.groupID = defaultGroupID
        }
        if savedMemory.createdByMemberID == nil {
            savedMemory.createdByMemberID = defaultMemberID
        }
        savedMemory.updatedAt = now

        let sourceItems = savedMemory.displayMediaItems
        savedMemory.mediaItems = try sourceItems.map { item in
            var savedItem = item
            savedItem.memoryID = savedMemory.id
            savedItem.groupID = savedMemory.groupID
            savedItem.createdByMemberID = savedMemory.createdByMemberID
            savedItem.updatedAt = now

            if let mediaData = mediaDataByItemID[item.id] {
                let filename = "\(savedMemory.id.uuidString)-\(item.id.uuidString).photo"
                let mediaURL = mediaDirectoryURL.appendingPathComponent(filename)
                try mediaData.write(to: mediaURL, options: [.atomic])
                savedItem.localFileURL = mediaURL
                savedItem.localMediaFilename = filename
                savedItem.localCacheFilename = filename
                savedItem.downloadState = .downloaded
            }

            return savedItem
        }

        let firstItem = savedMemory.mediaItems.first
        savedMemory.localFileURL = firstItem?.localFileURL
        savedMemory.localMediaFilename = firstItem?.localMediaFilename
        savedMemory.mediaKind = firstItem?.kind ?? savedMemory.mediaKind
        savedMemory.shareState = .shared

        var memories = try loadMemories()
        memories.removeAll { $0.id == savedMemory.id }
        memories.append(savedMemory)
        try persist(memories)

        return savedMemory
    }

    func deleteMemory(id: ParkMemory.ID) async throws {
        var memories = try loadMemories()
        guard let memory = memories.first(where: { $0.id == id }) else {
            return
        }

        for item in normalizedMemory(memory).displayMediaItems {
            if let mediaURL = resolvedMediaURL(for: item), FileManager.default.fileExists(atPath: mediaURL.path) {
                try FileManager.default.removeItem(at: mediaURL)
            }
        }

        memories.removeAll { $0.id == id }
        try persist(memories)  // persist() updates _cache
    }

    private func ensureStorageExists() throws {
        try FileManager.default.createDirectory(
            at: mediaDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    private func loadMemories() throws -> [ParkMemory] {
        if let cached = _cache { return cached }

        try ensureStorageExists()

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            _cache = []
            return []
        }

        let data = try Data(contentsOf: metadataURL)
        let memories = try JSONDecoder().decode([ParkMemory].self, from: data)
        _cache = memories
        return memories
    }

    private func persist(_ memories: [ParkMemory]) throws {
        try ensureStorageExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(memories)
        try data.write(to: metadataURL, options: [.atomic])
        _cache = memories
    }

    private func normalizedMemory(_ memory: ParkMemory) -> ParkMemory {
        var normalized = memory
        let fallbackCreatedAt = normalized.createdAt

        if normalized.localMediaFilename == nil {
            normalized.localMediaFilename = memory.localFileURL?.lastPathComponent
        }

        if normalized.groupID == nil {
            normalized.groupID = defaultGroupID
        }

        if normalized.createdByMemberID == nil {
            normalized.createdByMemberID = defaultMemberID
        }

        if normalized.updatedAt < normalized.createdAt {
            normalized.updatedAt = fallbackCreatedAt
        }

        if normalized.mediaItems.isEmpty {
            normalized.mediaItems = normalized.displayMediaItems
        }

        normalized.mediaItems = normalized.mediaItems.map { item in
            normalizedMediaItem(item, memory: normalized)
        }

        if let firstItem = normalized.mediaItems.first {
            normalized.localFileURL = firstItem.localFileURL
            normalized.localMediaFilename = firstItem.localMediaFilename
            normalized.mediaKind = firstItem.kind
        } else if let mediaURL = resolvedMediaURL(for: normalized) {
            normalized.localFileURL = mediaURL
        }

        return normalized
    }

    private func normalizedMediaItem(_ item: ParkMemory.MediaItem, memory: ParkMemory) -> ParkMemory.MediaItem {
        var normalized = item

        if normalized.memoryID == nil {
            normalized.memoryID = memory.id
        }

        if normalized.groupID == nil {
            normalized.groupID = memory.groupID ?? defaultGroupID
        }

        if normalized.createdByMemberID == nil {
            normalized.createdByMemberID = memory.createdByMemberID ?? defaultMemberID
        }

        if normalized.originalLocalAssetIdentifier == nil {
            normalized.originalLocalAssetIdentifier = item.localAssetIdentifier
        }

        if normalized.localMediaFilename == nil {
            normalized.localMediaFilename = item.localFileURL?.lastPathComponent
        }

        if normalized.localCacheFilename == nil {
            normalized.localCacheFilename = normalized.localMediaFilename
        }

        if normalized.updatedAt < normalized.createdAt {
            normalized.updatedAt = normalized.createdAt
        }

        if let mediaURL = resolvedMediaURL(for: normalized) {
            normalized.localFileURL = mediaURL
        }

        return normalized
    }

    private func resolvedMediaURL(for memory: ParkMemory) -> URL? {
        if let filename = memory.localMediaFilename {
            let mediaURL = mediaDirectoryURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: mediaURL.path) {
                return mediaURL
            }
        }

        if let legacyURL = memory.localFileURL {
            let mediaURL = mediaDirectoryURL.appendingPathComponent(legacyURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: mediaURL.path) {
                return mediaURL
            }

            if FileManager.default.fileExists(atPath: legacyURL.path) {
                return legacyURL
            }
        }

        let fallbackURL = mediaDirectoryURL.appendingPathComponent("\(memory.id.uuidString).jpg")
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        }

        return nil
    }

    private func resolvedMediaURL(for item: ParkMemory.MediaItem) -> URL? {
        if let filename = item.localMediaFilename {
            let mediaURL = mediaDirectoryURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: mediaURL.path) {
                return mediaURL
            }
        }

        if let filename = item.localCacheFilename {
            let mediaURL = mediaDirectoryURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: mediaURL.path) {
                return mediaURL
            }
        }

        if let legacyURL = item.localFileURL {
            let mediaURL = mediaDirectoryURL.appendingPathComponent(legacyURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: mediaURL.path) {
                return mediaURL
            }

            if FileManager.default.fileExists(atPath: legacyURL.path) {
                return legacyURL
            }
        }

        return nil
    }
}
