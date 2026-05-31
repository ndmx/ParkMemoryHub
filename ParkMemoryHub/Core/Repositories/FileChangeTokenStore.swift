import CloudKit
import Foundation

/// Persists CloudKit `CKServerChangeToken`s so sync fetches only deltas instead
/// of re-reading the whole zone every time. Tokens are archived (they conform to
/// `NSSecureCoding`) and stored keyed by a caller-supplied string.
actor FileChangeTokenStore {
    private let fileURL: URL
    private var tokensByKey: [String: Data]?

    init(rootDirectoryURL: URL? = nil) {
        let baseDirectory = rootDirectoryURL
            ?? FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("ParkMemoryHub", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ParkMemoryHub", isDirectory: true)

        let syncDirectoryURL = baseDirectory.appendingPathComponent("Sync", isDirectory: true)
        self.fileURL = syncDirectoryURL.appendingPathComponent("change-tokens.json")
    }

    func token(forKey key: String) -> CKServerChangeToken? {
        guard let data = load()[key] else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    func setToken(_ token: CKServerChangeToken?, forKey key: String) {
        var tokens = load()
        if let token, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            tokens[key] = data
        } else {
            tokens[key] = nil
        }
        tokensByKey = tokens
        try? persist(tokens)
    }

    /// Drops every stored token, forcing the next fetch to read the full zone.
    /// Used when a zone is deleted server-side or the device leaves a circle.
    func reset() {
        tokensByKey = [:]
        try? persist([:])
    }

    private func load() -> [String: Data] {
        if let tokensByKey { return tokensByKey }

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Data].self, from: data) else {
            tokensByKey = [:]
            return [:]
        }

        tokensByKey = decoded
        return decoded
    }

    private func persist(_ tokens: [String: Data]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(tokens)
        try data.write(to: fileURL, options: [.atomic])
    }
}
