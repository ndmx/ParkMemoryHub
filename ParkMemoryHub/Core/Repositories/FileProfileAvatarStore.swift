import Foundation

enum FileProfileAvatarStore {
    private static var avatarDirectoryURL: URL {
        let baseDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("ParkMemoryHub", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ParkMemoryHub", isDirectory: true)

        return baseDirectory
            .appendingPathComponent("Profile", isDirectory: true)
            .appendingPathComponent("Avatars", isDirectory: true)
    }

    static func avatarData(filename: String?) -> Data? {
        guard let filename else {
            return nil
        }

        return try? Data(contentsOf: avatarDirectoryURL.appendingPathComponent(filename))
    }

    static func saveAvatarData(_ data: Data, memberID: FamilyMember.ID) throws -> String {
        try FileManager.default.createDirectory(
            at: avatarDirectoryURL,
            withIntermediateDirectories: true
        )

        let filename = "\(memberID.uuidString).jpg"
        try data.write(to: avatarDirectoryURL.appendingPathComponent(filename), options: [.atomic])
        return filename
    }
}
