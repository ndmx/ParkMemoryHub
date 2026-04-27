import Foundation

struct GroupInvite: Identifiable, Codable, Equatable, Sendable {
    var groupID: GroupSpace.ID
    var groupDisplayName: String
    var createdAt: Date

    var id: GroupSpace.ID {
        groupID
    }

    init(
        groupID: GroupSpace.ID,
        groupDisplayName: String,
        createdAt: Date = Date()
    ) {
        self.groupID = groupID
        self.groupDisplayName = groupDisplayName
        self.createdAt = createdAt
    }

    init(group: GroupSpace) {
        self.init(
            groupID: group.id,
            groupDisplayName: group.displayName,
            createdAt: group.createdAt
        )
    }
}

extension GroupInvite {
    var groupCode: String {
        String(groupID.uuidString.prefix(8)).uppercased()
    }
}

extension GroupSpace {
    var groupCode: String {
        String(id.uuidString.prefix(8)).uppercased()
    }
}

enum GroupInviteCodec {
    static func token(for invite: GroupInvite) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(invite)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func url(for invite: GroupInvite) throws -> URL {
        let token = try token(for: invite)
        var components = URLComponents()
        components.scheme = "parkmemoryhub"
        components.host = "join"
        components.path = "/\(token)"

        guard let url = components.url else {
            throw GroupInviteError.invalidInvite
        }

        return url
    }

    static func invite(from rawValue: String) throws -> GroupInvite {
        let cleanValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanValue.isEmpty else {
            throw GroupInviteError.emptyInvite
        }

        if let url = URL(string: cleanValue),
           url.scheme?.localizedCaseInsensitiveCompare("parkmemoryhub") == .orderedSame {
            return try invite(from: url)
        }

        return try decodeToken(cleanValue)
    }

    static func invite(from url: URL) throws -> GroupInvite {
        guard url.scheme?.localizedCaseInsensitiveCompare("parkmemoryhub") == .orderedSame else {
            throw GroupInviteError.unsupportedLink
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let token = components?.queryItems?.first(where: { $0.name == "invite" || $0.name == "code" })?.value {
            return try decodeToken(token)
        }

        if url.host?.localizedCaseInsensitiveCompare("join") == .orderedSame {
            let token = url.pathComponents.dropFirst().first
            if let token, !token.isEmpty {
                return try decodeToken(token)
            }
        }

        throw GroupInviteError.invalidInvite
    }

    private static func decodeToken(_ token: String) throws -> GroupInvite {
        var base64 = token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let missingPadding = base64.count % 4
        if missingPadding > 0 {
            base64 += String(repeating: "=", count: 4 - missingPadding)
        }

        guard let data = Data(base64Encoded: base64) else {
            throw GroupInviteError.invalidInvite
        }

        do {
            return try JSONDecoder().decode(GroupInvite.self, from: data)
        } catch {
            throw GroupInviteError.invalidInvite
        }
    }
}

enum GroupInviteError: LocalizedError {
    case emptyInvite
    case unsupportedLink
    case invalidInvite

    var errorDescription: String? {
        switch self {
        case .emptyInvite:
            return "Paste an invite link or code to join a circle."
        case .unsupportedLink:
            return "This link does not belong to Park Memory Hub."
        case .invalidInvite:
            return "This invite could not be read. Ask the sender for a new invite link or code."
        }
    }
}

extension Notification.Name {
    static let parkMemoryHubGroupDidChange = Notification.Name("parkMemoryHubGroupDidChange")
}
