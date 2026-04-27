import Foundation

actor FilePreferencesRepository: PreferencesRepository {
    private let metadataURL: URL
    private let defaultPreferences: UserPreferences

    init(
        rootDirectoryURL: URL? = nil,
        defaultPreferences: UserPreferences = UserPreferences()
    ) {
        let baseDirectory = rootDirectoryURL
            ?? FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("ParkMemoryHub", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ParkMemoryHub", isDirectory: true)

        let profileDirectoryURL = baseDirectory.appendingPathComponent("Profile", isDirectory: true)
        self.metadataURL = profileDirectoryURL.appendingPathComponent("preferences.json")
        self.defaultPreferences = defaultPreferences
    }

    func loadPreferences() async throws -> UserPreferences {
        try ensureStorageExists()

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            try await savePreferences(defaultPreferences)
            return defaultPreferences
        }

        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder().decode(UserPreferences.self, from: data)
    }

    func savePreferences(_ preferences: UserPreferences) async throws {
        try ensureStorageExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preferences)
        try data.write(to: metadataURL, options: [.atomic])
    }

    private func ensureStorageExists() throws {
        try FileManager.default.createDirectory(
            at: metadataURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
