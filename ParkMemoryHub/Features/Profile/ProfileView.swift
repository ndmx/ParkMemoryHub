import PhotosUI
import SwiftUI
import UIKit

struct ProfileRoute: View {
    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        ProfileView(
            familyRepository: dependencies.family,
            preferencesRepository: dependencies.preferences,
            activeGroup: dependencies.activeGroup,
            circleSync: dependencies.circleSync,
            isOwner: dependencies.circleRole == .owner
        )
    }
}

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    private let isOwner: Bool
    @State private var preparedShare: PreparedShare?
    @State private var isPreparingShare = false
    @State private var isEditingProfile = false
    @State private var isConfirmingNewCircle = false
    @State private var isConfirmingLeaveGroup = false

    init(
        familyRepository: any FamilyRepository,
        preferencesRepository: any PreferencesRepository,
        activeGroup: GroupSpace,
        circleSync: any CircleSyncing,
        isOwner: Bool = true
    ) {
        self.isOwner = isOwner
        _viewModel = StateObject(
            wrappedValue: ProfileViewModel(
                familyRepository: familyRepository,
                preferencesRepository: preferencesRepository,
                activeGroup: activeGroup,
                circleSync: circleSync
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
	                        .listRowBackground(Color.clear)

	                        Section("Circle") {
	                            LabeledContent("Name", value: viewModel.visibleGroupDisplayName)
                            LabeledContent("Circle Code", value: viewModel.activeGroup.groupCode)
                            LabeledContent("Members", value: "\(viewModel.members.count)")

                            if isOwner {
                                Button {
                                    prepareShare()
                                } label: {
                                    if isPreparingShare {
                                        ProgressView()
                                    } else {
                                        Label("Invite to Circle", systemImage: "person.badge.plus")
                                    }
                                }
                                .disabled(isPreparingShare)
                            } else {
                                Text("Only the circle's creator can invite people. Tap a shared invite link to join a circle.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
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
	                        .listRowBackground(Color.clear)

	                        Section("Location Sharing") {
	                            Toggle("Share My Location", isOn: $viewModel.preferences.shareLocation)

                            Text("Radar and current-location tagging stay off until you enable them on this device.")
	                                .font(.footnote)
	                                .foregroundStyle(.secondary)
	                        }
	                        .listRowBackground(Color.clear)

	                        Section("Storage") {
	                            LabeledContent("Data", value: "This device + iCloud")
	                            LabeledContent("iCloud Sync", value: "Automatic")
	                        }
	                        .listRowBackground(Color.clear)

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
	                        .listRowBackground(Color.clear)
	                    }
	                    .scrollContentBackground(.hidden)
                    .contentMargins(.bottom, 24, for: .scrollContent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appScreenBackground(.pearl)
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
            .sheet(item: $preparedShare) { prepared in
                CloudSharingView(share: prepared.share, container: prepared.container)
                    .ignoresSafeArea()
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

    private func prepareShare() {
        isPreparingShare = true
        Task {
            do {
                let (share, container) = try await viewModel.prepareShare()
                preparedShare = PreparedShare(share: share, container: container)
            } catch {
                viewModel.errorMessage = CircleSyncErrorFormatter.message(for: error)
            }
            isPreparingShare = false
        }
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
                tint: Lumina.Color.accent
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(member?.displayName ?? "You")
                    .font(.headline)
                    .foregroundStyle(Lumina.Color.textPrimary)

                Text("Park Memory Hub")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Lumina.Color.accent)

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
                                    tint: Lumina.Color.accent
                                )

                                Image(systemName: "camera.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Lumina.Color.onAccent)
                                    .padding(7)
                                    .background(Lumina.Color.accent, in: Circle())
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

private struct ProfileMemberRow: View {
    let member: FamilyMember

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((member.isCurrentUser ? Lumina.Color.accent : Lumina.Color.accentSecondary).opacity(0.16))

                Text(initials)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(member.isCurrentUser ? Lumina.Color.accent : Lumina.Color.accentSecondary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Lumina.Color.textPrimary)

                    if member.isCurrentUser {
                        Text("This Device")
                            .luminaChip(Lumina.Color.accent)
                    }

                    if member.role != .member {
                        Text(member.role.title)
                            .luminaChip(Lumina.Color.accentSecondary)
                    }
                }

                Text(memberStatus)
                    .font(.caption)
                    .foregroundStyle(Lumina.Color.textSubtle)
            }

            Spacer()

            Image(systemName: member.sharesLocation ? "location.fill" : "location.slash")
                .foregroundStyle(member.sharesLocation ? Lumina.Status.success : Lumina.Color.textSubtle)
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
        preferencesRepository: dependencies.preferences,
        activeGroup: dependencies.activeGroup,
        circleSync: dependencies.circleSync
    )
}
