import Foundation

struct ParkMemory: Identifiable, Codable, Equatable, Sendable {
    enum MediaKind: String, Codable, CaseIterable, Sendable {
        case photo
        case video
    }

    enum ShareState: String, Codable, CaseIterable, Sendable {
        case localOnly
        case uploadPending
        case uploading
        case shared
        case unavailable
    }

    enum MediaDownloadState: String, Codable, CaseIterable, Sendable {
        case localOnly
        case uploadPending
        case uploading
        case availableForDownload
        case downloaded
        case unavailable
    }

    struct MediaItem: Identifiable, Codable, Equatable, Sendable {
        let id: UUID
        var memoryID: ParkMemory.ID?
        var groupID: GroupSpace.ID?
        var createdByMemberID: FamilyMember.ID?
        var kind: MediaKind
        var localAssetIdentifier: String?
        var originalLocalAssetIdentifier: String?
        var localFileURL: URL?
        var localMediaFilename: String?
        var localCacheFilename: String?
        var remoteAssetID: String?
        var downloadState: MediaDownloadState
        var createdAt: Date
        var updatedAt: Date

        private enum CodingKeys: String, CodingKey {
            case id
            case memoryID
            case groupID
            case createdByMemberID
            case kind
            case localAssetIdentifier
            case originalLocalAssetIdentifier
            case localFileURL
            case localMediaFilename
            case localCacheFilename
            case remoteAssetID
            case downloadState
            case createdAt
            case updatedAt
        }

        init(
            id: UUID = UUID(),
            memoryID: ParkMemory.ID? = nil,
            groupID: GroupSpace.ID? = nil,
            createdByMemberID: FamilyMember.ID? = nil,
            kind: MediaKind = .photo,
            localAssetIdentifier: String? = nil,
            originalLocalAssetIdentifier: String? = nil,
            localFileURL: URL? = nil,
            localMediaFilename: String? = nil,
            localCacheFilename: String? = nil,
            remoteAssetID: String? = nil,
            downloadState: MediaDownloadState = .localOnly,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.memoryID = memoryID
            self.groupID = groupID
            self.createdByMemberID = createdByMemberID
            self.kind = kind
            self.localAssetIdentifier = localAssetIdentifier
            self.originalLocalAssetIdentifier = originalLocalAssetIdentifier
            self.localFileURL = localFileURL
            self.localMediaFilename = localMediaFilename
            self.localCacheFilename = localCacheFilename
            self.remoteAssetID = remoteAssetID
            self.downloadState = downloadState
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            self.memoryID = try container.decodeIfPresent(ParkMemory.ID.self, forKey: .memoryID)
            self.groupID = try container.decodeIfPresent(GroupSpace.ID.self, forKey: .groupID)
            self.createdByMemberID = try container.decodeIfPresent(FamilyMember.ID.self, forKey: .createdByMemberID)
            self.kind = try container.decodeIfPresent(MediaKind.self, forKey: .kind) ?? .photo
            self.localAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .localAssetIdentifier)
            self.originalLocalAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .originalLocalAssetIdentifier) ?? localAssetIdentifier
            self.localFileURL = try container.decodeIfPresent(URL.self, forKey: .localFileURL)
            self.localMediaFilename = try container.decodeIfPresent(String.self, forKey: .localMediaFilename)
            self.localCacheFilename = try container.decodeIfPresent(String.self, forKey: .localCacheFilename) ?? localMediaFilename
            self.remoteAssetID = try container.decodeIfPresent(String.self, forKey: .remoteAssetID)
            self.downloadState = try container.decodeIfPresent(MediaDownloadState.self, forKey: .downloadState) ?? .localOnly
            self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        }
    }

    let id: UUID
    var groupID: GroupSpace.ID?
    var createdByMemberID: FamilyMember.ID?
    var mediaKind: MediaKind
    var localAssetIdentifier: String?
    var localFileURL: URL?
    var localMediaFilename: String?
    var mediaItems: [MediaItem]
    var caption: String
    var tags: [String]
    var location: ParkLocation?
    var shareState: ShareState
    var createdAt: Date
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case groupID
        case createdByMemberID
        case mediaKind
        case localAssetIdentifier
        case localFileURL
        case localMediaFilename
        case mediaItems
        case caption
        case tags
        case location
        case shareState
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        groupID: GroupSpace.ID? = nil,
        createdByMemberID: FamilyMember.ID? = nil,
        mediaKind: MediaKind = .photo,
        localAssetIdentifier: String? = nil,
        localFileURL: URL? = nil,
        localMediaFilename: String? = nil,
        mediaItems: [MediaItem] = [],
        caption: String = "",
        tags: [String] = [],
        location: ParkLocation? = nil,
        shareState: ShareState = .localOnly,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.groupID = groupID
        self.createdByMemberID = createdByMemberID
        self.mediaKind = mediaKind
        self.localAssetIdentifier = localAssetIdentifier
        self.localFileURL = localFileURL
        self.localMediaFilename = localMediaFilename
        self.mediaItems = mediaItems
        self.caption = caption
        self.tags = tags
        self.location = location
        self.shareState = shareState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.groupID = try container.decodeIfPresent(GroupSpace.ID.self, forKey: .groupID)
        self.createdByMemberID = try container.decodeIfPresent(FamilyMember.ID.self, forKey: .createdByMemberID)
        self.mediaKind = try container.decodeIfPresent(MediaKind.self, forKey: .mediaKind) ?? .photo
        self.localAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .localAssetIdentifier)
        self.localFileURL = try container.decodeIfPresent(URL.self, forKey: .localFileURL)
        self.localMediaFilename = try container.decodeIfPresent(String.self, forKey: .localMediaFilename)
        self.mediaItems = try container.decodeIfPresent([MediaItem].self, forKey: .mediaItems) ?? []
        self.caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.location = try container.decodeIfPresent(ParkLocation.self, forKey: .location)
        self.shareState = try container.decodeIfPresent(ShareState.self, forKey: .shareState) ?? .localOnly
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    var displayMediaItems: [MediaItem] {
        if !mediaItems.isEmpty {
            return mediaItems
        }

        guard localFileURL != nil || localMediaFilename != nil || localAssetIdentifier != nil else {
            return []
        }

        return [
            MediaItem(
                id: id,
                memoryID: id,
                groupID: groupID,
                createdByMemberID: createdByMemberID,
                kind: mediaKind,
                localAssetIdentifier: localAssetIdentifier,
                originalLocalAssetIdentifier: localAssetIdentifier,
                localFileURL: localFileURL,
                localMediaFilename: localMediaFilename,
                localCacheFilename: localMediaFilename,
                downloadState: .localOnly,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        ]
    }
}
