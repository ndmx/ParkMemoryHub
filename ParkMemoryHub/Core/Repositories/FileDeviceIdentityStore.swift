import Foundation

enum FileDeviceIdentityStore {
    private static var identityURL: URL {
        let baseDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("ParkMemoryHub", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ParkMemoryHub", isDirectory: true)

        return baseDirectory
            .appendingPathComponent("Profile", isDirectory: true)
            .appendingPathComponent("local-device.json")
    }

    static func loadOrCreate() -> DeviceIdentity {
        do {
            try FileManager.default.createDirectory(
                at: identityURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: identityURL.path) {
                let data = try Data(contentsOf: identityURL)
                return try JSONDecoder().decode(DeviceIdentity.self, from: data)
            }

            let identity = DeviceIdentity()
            try save(identity)
            return identity
        } catch {
            return DeviceIdentity()
        }
    }

    /// Records that this device joined another member's circle as a share
    /// participant. The circle id, zone, and share owner come from the accepted
    /// `CKShareMetadata`. The device's own `memberID` is preserved.
    @discardableResult
    static func joinCircle(
        circleID: GroupSpace.ID,
        displayName: String,
        zoneName: String,
        zoneOwnerName: String
    ) throws -> DeviceIdentity {
        var identity = loadOrCreate()
        identity.groupID = circleID
        identity.groupDisplayName = displayName
        identity.role = .participant
        identity.zoneName = zoneName
        identity.zoneOwnerName = zoneOwnerName
        try save(identity)
        return identity
    }

    @discardableResult
    static func createNewCircle(displayName: String) throws -> DeviceIdentity {
        var identity = loadOrCreate()
        let groupID = UUID()
        identity.groupID = groupID
        identity.groupDisplayName = displayName
        identity.createdAt = Date()
        identity.role = .owner
        identity.zoneName = DeviceIdentity.defaultZoneName(for: groupID)
        identity.zoneOwnerName = nil
        try save(identity)
        return identity
    }

    @discardableResult
    static func updateGroupDisplayName(_ displayName: String) throws -> DeviceIdentity {
        var identity = loadOrCreate()
        identity.groupDisplayName = displayName
        try save(identity)
        return identity
    }

    private static func save(_ identity: DeviceIdentity) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(identity)
        try data.write(to: identityURL, options: [.atomic])
    }
}
