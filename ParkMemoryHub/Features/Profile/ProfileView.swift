import PhotosUI
import SwiftUI
import UIKit

struct ProfileRoute: View {
    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        ProfileView(
            familyRepository: dependencies.family,
            memoryRepository: dependencies.memories,
            activitiesRepository: dependencies.activities,
            preferencesRepository: dependencies.preferences,
            activeGroup: dependencies.activeGroup,
            syncEventRepository: dependencies.syncEvents
        )
    }
}

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var isShowingInvite = false
    @State private var isShowingJoinGroup = false
    @State private var isEditingProfile = false
    @State private var isConfirmingNewCircle = false
    @State private var isConfirmingLeaveGroup = false

    init(
        familyRepository: any FamilyRepository,
        memoryRepository: any MemoryRepository,
        activitiesRepository: any ActivityRepository,
        preferencesRepository: any PreferencesRepository,
        activeGroup: GroupSpace,
        syncEventRepository: any SyncEventRepository
    ) {
        _viewModel = StateObject(
            wrappedValue: ProfileViewModel(
                familyRepository: familyRepository,
                memoryRepository: memoryRepository,
                activitiesRepository: activitiesRepository,
                preferencesRepository: preferencesRepository,
                activeGroup: activeGroup,
                syncEventRepository: syncEventRepository
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading profile...")
                } else {
                    Form {
                        Section {
                            Button {
                                isEditingProfile = true
                            } label: {
                                ProfileHeader(
                                    member: viewModel.currentMember,
                                    avatarImageData: viewModel.avatarImageData
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Section("Circle") {
                            LabeledContent("Name", value: viewModel.visibleGroupDisplayName)
                            LabeledContent("Circle Code", value: viewModel.activeGroup.groupCode)
                            LabeledContent("Members", value: "\(viewModel.members.count)")

                            Button {
                                isShowingInvite = true
                            } label: {
                                Label("Invite to Circle", systemImage: "person.badge.plus")
                            }

                            Button {
                                isShowingJoinGroup = true
                            } label: {
                                Label("Join Circle", systemImage: "link.badge.plus")
                            }

                            Button {
                                isConfirmingNewCircle = true
                            } label: {
                                Label("Start New Circle", systemImage: "person.3.sequence")
                            }

                            Button(role: .destructive) {
                                isConfirmingLeaveGroup = true
                            } label: {
                                Label("Leave Circle", systemImage: "rectangle.portrait.and.arrow.right")
                            }

                            ForEach(viewModel.members) { member in
                                ProfileMemberRow(member: member)
                            }
                        }

                        Section("Location Sharing") {
                            Toggle("Share My Location", isOn: $viewModel.preferences.shareLocation)

                            Text("Radar and current-location tagging stay off until you enable them on this device.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Section("Storage") {
                            LabeledContent("Data", value: "This device + iCloud")
                            LabeledContent("iCloud Sync", value: "Automatic")
                            LabeledContent("Sync Records", value: "\(viewModel.syncEventCount)")
                        }

                        Section("iCloud Sync") {
                            Button {
                                viewModel.syncWithICloud()
                            } label: {
                                if viewModel.isSyncingICloud {
                                    ProgressView()
                                } else {
                                    Label("Sync with iCloud", systemImage: "icloud.and.arrow.up")
                                }
                            }
                            .disabled(viewModel.isSyncingICloud)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                if viewModel.hasUnsavedChanges {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.saveProfile()
                        } label: {
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text("Save")
                            }
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .alert("Profile Error", isPresented: errorBinding) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong.")
            }
            .alert("Profile Update", isPresented: statusBinding) {
                Button("OK") {
                    viewModel.statusMessage = nil
                }
            } message: {
                Text(viewModel.statusMessage ?? "Profile updated.")
            }
            .confirmationDialog("Start a new circle?", isPresented: $isConfirmingNewCircle) {
                Button("Start New Circle", role: .destructive) {
                    viewModel.startNewCircle()
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This device will create a new circle with its own unique code. Share the new invite link or circle code with the people you want in it.")
            }
            .confirmationDialog("Leave this circle?", isPresented: $isConfirmingLeaveGroup) {
                Button("Leave Circle", role: .destructive) {
                    viewModel.leaveGroup()
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This device will move into a new personal circle. Other members and iCloud data in the old circle will stay available to people who remain in it.")
            }
            .onAppear {
                viewModel.load()
            }
            .sheet(isPresented: $isShowingInvite) {
                ProfileInviteView(group: viewModel.visibleGroup)
            }
            .sheet(isPresented: $isShowingJoinGroup) {
                JoinGroupView(currentGroup: viewModel.activeGroup)
            }
            .sheet(isPresented: $isEditingProfile) {
                EditProfileView(
                    displayName: viewModel.displayName,
                    avatarImageData: viewModel.avatarImageData
                ) { displayName, avatarImageData in
                    viewModel.saveProfile(displayName: displayName, avatarImageData: avatarImageData)
                }
            }
        }
    }

    private var canSave: Bool {
        !viewModel.isLoading
            && !viewModel.isSaving
            && viewModel.hasUnsavedChanges
            && !viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private var statusBinding: Binding<Bool> {
        Binding(
            get: { viewModel.statusMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.statusMessage = nil
                }
            }
        )
    }
}

private struct ProfileHeader: View {
    let member: FamilyMember?
    let avatarImageData: Data?

    var body: some View {
        HStack(spacing: 14) {
            ProfileAvatarView(
                imageData: avatarImageData,
                initials: initials,
                size: 58,
                tint: .blue
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(member?.displayName ?? "You")
                    .font(.headline)

                Text("Park Memory Hub")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let member {
                    Text("Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    private var initials: String {
        guard let displayName = member?.displayName, !displayName.isEmpty else {
            return "Y"
        }

        return displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

private struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var avatarImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?

    let onSave: (String, Data?) -> Void

    init(
        displayName: String,
        avatarImageData: Data?,
        onSave: @escaping (String, Data?) -> Void
    ) {
        _displayName = State(initialValue: displayName)
        _avatarImageData = State(initialValue: avatarImageData)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 14) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                ProfileAvatarView(
                                    imageData: avatarImageData,
                                    initials: initials,
                                    size: 96,
                                    tint: .blue
                                )

                                Image(systemName: "camera.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(7)
                                    .background(.blue, in: Circle())
                            }
                        }
                        .buttonStyle(.plain)

                        TextField("Name", text: $displayName)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.words)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(displayName, avatarImageData)
                        dismiss()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                loadAvatar(from: item)
            }
        }
    }

    private var initials: String {
        let cleanDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDisplayName.isEmpty else {
            return "M"
        }

        return cleanDisplayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private func loadAvatar(from item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                avatarImageData = data
            }
        }
    }
}

private struct ProfileAvatarView: View {
    let imageData: Data?
    let initials: String
    let size: CGFloat
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))

            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: max(15, size * 0.34), weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}

private struct ProfileInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copiedMessage: String?
    let group: GroupSpace

    private var invite: GroupInvite {
        GroupInvite(group: group)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite Code") {
                    LabeledContent("Circle Code", value: group.groupCode)

                    Text(inviteCode)
                        .font(.footnote.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .textSelection(.enabled)

                    ShareLink(item: inviteMessage) {
                        Label("Share Invite", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        copyInviteCode()
                    } label: {
                        Label("Copy Invite Code", systemImage: "doc.on.doc")
                    }
                }

                Section("Invite Link") {
                    Text(inviteURL.absoluteString)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    ShareLink(item: inviteURL.absoluteString) {
                        Label("Share Link", systemImage: "link")
                    }

                    Button {
                        copyInviteLink()
                    } label: {
                        Label("Copy Invite Link", systemImage: "doc.on.doc")
                    }
                }
            }
            .navigationTitle("Invite to Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Copied", isPresented: copiedBinding) {
                Button("OK") {
                    copiedMessage = nil
                }
            } message: {
                Text(copiedMessage ?? "Copied to clipboard.")
            }
        }
    }

    private var inviteCode: String {
        (try? GroupInviteCodec.token(for: invite)) ?? ""
    }

    private var inviteURL: URL {
        (try? GroupInviteCodec.url(for: invite)) ?? URL(string: "parkmemoryhub://join")!
    }

    private var inviteMessage: String {
        "Join \(group.displayName) in Park Memory Hub.\n\nOpen Park Memory Hub, go to Profile, tap Join Circle, and paste this invite code:\n\(inviteCode)\n\nInvite link:\n\(inviteURL.absoluteString)"
    }

    private var copiedBinding: Binding<Bool> {
        Binding(
            get: { copiedMessage != nil },
            set: { newValue in
                if !newValue {
                    copiedMessage = nil
                }
            }
        )
    }

    private func copyInviteCode() {
        UIPasteboard.general.string = inviteCode
        copiedMessage = "Invite code copied."
    }

    private func copyInviteLink() {
        UIPasteboard.general.string = inviteURL.absoluteString
        copiedMessage = "Invite link copied."
    }
}

private struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    let currentGroup: GroupSpace
    @State private var inviteText = ""
    @State private var errorMessage: String?
    @State private var isJoining = false
    @State private var groupStatusMessage: String?
    @State private var shouldReloadAfterStatus = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Circle") {
                    LabeledContent("Circle Code", value: currentGroup.groupCode)
                }

                Section("Invite") {
                    TextField("Invite link or code", text: $inviteText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(3...6)

                    Button {
                        pasteInvite()
                    } label: {
                        Label("Paste From Clipboard", systemImage: "doc.on.clipboard")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Join Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        joinGroup()
                    } label: {
                        if isJoining {
                            ProgressView()
                        } else {
                            Text("Join")
                        }
                    }
                    .disabled(inviteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoining)
                }
            }
            .alert("Circle Status", isPresented: groupStatusBinding) {
                Button("OK") {
                    groupStatusMessage = nil
                    if shouldReloadAfterStatus {
                        NotificationCenter.default.post(name: .parkMemoryHubGroupDidChange, object: nil)
                        shouldReloadAfterStatus = false
                    }
                    dismiss()
                }
            } message: {
                Text(groupStatusMessage ?? "Circle updated.")
            }
        }
    }

    private var groupStatusBinding: Binding<Bool> {
        Binding(
            get: { groupStatusMessage != nil },
            set: { newValue in
                if !newValue {
                    groupStatusMessage = nil
                }
            }
        )
    }

    private func pasteInvite() {
        if let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !clipboardText.isEmpty {
            inviteText = clipboardText
        }
    }

    private func joinGroup() {
        isJoining = true
        errorMessage = nil

        do {
            let invite = try GroupInviteCodec.invite(from: inviteText)

            if currentGroup.id == invite.groupID {
                groupStatusMessage = "This device is already in \(invite.groupDisplayName). Circle code \(invite.groupCode)."
                shouldReloadAfterStatus = false
                isJoining = false
                return
            }

            try FileDeviceIdentityStore.acceptInvite(invite)
            groupStatusMessage = "Joined \(invite.groupDisplayName). Circle code \(invite.groupCode)."
            shouldReloadAfterStatus = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isJoining = false
    }
}

private struct ProfileMemberRow: View {
    let member: FamilyMember

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(member.isCurrentUser ? .blue.opacity(0.14) : .secondary.opacity(0.12))

                Text(initials)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(member.isCurrentUser ? .blue : .secondary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.subheadline.weight(.medium))

                    if member.isCurrentUser {
                        Text("This Device")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }

                    if member.role != .member {
                        Text(member.role.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }
                }

                Text(memberStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: member.sharesLocation ? "location.fill" : "location.slash")
                .foregroundStyle(member.sharesLocation ? .green : .secondary)
                .accessibilityLabel(member.sharesLocation ? "Sharing location" : "Location hidden")
        }
        .padding(.vertical, 3)
    }

    private var initials: String {
        let name = member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return "M"
        }

        return name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var memberStatus: String {
        guard let lastSeenAt = member.lastSeenAt else {
                            return member.sharesLocation ? "Location sharing on" : "Location sharing off"
        }

        return "Active \(lastSeenAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

private extension FamilyMember.Role {
    var title: String {
        switch self {
        case .owner:
            return "Owner"
        case .admin:
            return "Admin"
        case .member:
            return "Member"
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()

    ProfileView(
        familyRepository: dependencies.family,
        memoryRepository: dependencies.memories,
        activitiesRepository: dependencies.activities,
        preferencesRepository: dependencies.preferences,
        activeGroup: dependencies.activeGroup,
        syncEventRepository: dependencies.syncEvents
    )
}
