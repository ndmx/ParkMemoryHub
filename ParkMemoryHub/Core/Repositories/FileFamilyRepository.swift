import Foundation

actor FileFamilyRepository: FamilyRepository {
    private let metadataURL: URL
    private let defaultMemberID: FamilyMember.ID
    private let seedMembers: [FamilyMember]
    private let legacyDemoGroupID = UUID(uuidString: "8B713551-0360-42A1-A3F2-E82132979F65")
    private var activeGroupID: GroupSpace.ID? {
        seedMembers.first(where: { $0.id == defaultMemberID })?.groupID
    }

    init(
        rootDirectoryURL: URL? = nil,
        defaultMemberID: FamilyMember.ID,
        seedMembers: [FamilyMember]
    ) {
        let baseDirectory = rootDirectoryURL
            ?? FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("ParkMemoryHub", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ParkMemoryHub", isDirectory: true)

        let profileDirectoryURL = baseDirectory.appendingPathComponent("Profile", isDirectory: true)
        self.metadataURL = profileDirectoryURL.appendingPathComponent("members.json")
        self.defaultMemberID = defaultMemberID
        self.seedMembers = seedMembers
    }

    func currentMember() async throws -> FamilyMember {
        let members = try normalizedMembers()

        if let defaultMember = members.first(where: { $0.id == defaultMemberID }) {
            return defaultMember
        }

        return FamilyMember(id: defaultMemberID, displayName: "Me", isCurrentUser: true, sharesLocation: false)
    }

    func listMembers() async throws -> [FamilyMember] {
        try normalizedMembers().sorted(by: memberSort)
    }

    @discardableResult
    func saveMember(_ member: FamilyMember) async throws -> FamilyMember {
        var members = try normalizedMembers()
        members.removeAll { $0.id == member.id }

        var savedMember = member
        if savedMember.id == defaultMemberID {
            savedMember.isCurrentUser = true
        }

        if savedMember.isCurrentUser {
            members = members.map { existingMember in
                var updatedMember = existingMember
                updatedMember.isCurrentUser = updatedMember.id == savedMember.id
                return updatedMember
            }
        }

        members.append(savedMember)
        try persist(members)
        return savedMember
    }

    private func ensureStorageExists() throws {
        try FileManager.default.createDirectory(
            at: metadataURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func loadMembers() throws -> [FamilyMember] {
        try ensureStorageExists()

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            try persist(seedMembers)
            return seedMembers
        }

        let data = try Data(contentsOf: metadataURL)
        let members = try JSONDecoder().decode([FamilyMember].self, from: data)
        return members.isEmpty ? seedMembers : members
    }

    private func normalizedMembers() throws -> [FamilyMember] {
        var members = try loadMembers()
        var didChange = false
        let currentGroupID = activeGroupID

        if let legacyDemoGroupID {
            let countBeforeCleanup = members.count
            members.removeAll { member in
                member.groupID == legacyDemoGroupID && member.id != defaultMemberID
            }
            didChange = didChange || members.count != countBeforeCleanup
        }

        if let currentGroupID {
            let countBeforeCleanup = members.count
            members.removeAll { member in
                member.id != defaultMemberID && member.groupID != currentGroupID
            }
            didChange = didChange || members.count != countBeforeCleanup
        }

        if members.contains(where: { $0.id == defaultMemberID }) {
            members = members.map { member in
                var updatedMember = member
                let shouldBeCurrent = updatedMember.id == defaultMemberID
                if updatedMember.isCurrentUser != shouldBeCurrent {
                    updatedMember.isCurrentUser = shouldBeCurrent
                    didChange = true
                }
                if shouldBeCurrent,
                   let seedGroupID = seedMembers.first(where: { $0.id == defaultMemberID })?.groupID,
                   updatedMember.groupID != seedGroupID {
                    updatedMember.groupID = seedGroupID
                    didChange = true
                }
                return updatedMember
            }
        } else {
            let previousCurrentMember = members.first(where: \.isCurrentUser)
            let seedCurrentMember = seedMembers.first(where: { $0.id == defaultMemberID })

            let sourceMember = previousCurrentMember ?? seedCurrentMember
            let currentMember = FamilyMember(
                id: defaultMemberID,
                groupID: seedCurrentMember?.groupID ?? sourceMember?.groupID,
                displayName: normalizedDisplayName(sourceMember?.displayName),
                avatarLocalAssetIdentifier: sourceMember?.avatarLocalAssetIdentifier,
                role: sourceMember?.role ?? .owner,
                isCurrentUser: true,
                sharesLocation: sourceMember?.sharesLocation ?? false,
                lastKnownLocation: nil,
                lastSeenAt: sourceMember?.lastSeenAt,
                joinedAt: sourceMember?.joinedAt ?? Date()
            )

            members = members.map { member in
                var updatedMember = member
                if updatedMember.isCurrentUser {
                    updatedMember.isCurrentUser = false
                    didChange = true
                }
                return updatedMember
            }
            members.append(currentMember)
            didChange = true
        }

        if didChange {
            try persist(members)
        }

        return members
    }

    private func normalizedDisplayName(_ displayName: String?) -> String {
        let cleanDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if cleanDisplayName.isEmpty || cleanDisplayName == "You" {
            return "Me"
        }

        return cleanDisplayName
    }

    private func persist(_ members: [FamilyMember]) throws {
        try ensureStorageExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(members.sorted(by: memberSort))
        try data.write(to: metadataURL, options: [.atomic])
    }

    private func memberSort(_ lhs: FamilyMember, _ rhs: FamilyMember) -> Bool {
        if lhs.isCurrentUser != rhs.isCurrentUser {
            return lhs.isCurrentUser
        }

        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }
}
