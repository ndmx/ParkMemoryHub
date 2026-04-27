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

    @discardableResult
    static func acceptInvite(_ invite: GroupInvite) throws -> DeviceIdentity {
        var identity = loadOrCreate()
        identity.groupID = invite.groupID
        identity.groupDisplayName = invite.groupDisplayName
        try save(identity)
        return identity
    }

    @discardableResult
    static func createNewCircle(displayName: String) throws -> DeviceIdentity {
        var identity = loadOrCreate()
        identity.groupID = UUID()
        identity.groupDisplayName = displayName
        identity.createdAt = Date()
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
