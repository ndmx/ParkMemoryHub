import SwiftUI

struct ParkHubView: View {
    @State private var dependencies: AppDependencies
    @State private var pendingInvite: GroupInvite?
    @State private var inviteErrorMessage: String?
    @State private var groupStatusMessage: String?

    init(dependencies: AppDependencies = .production()) {
        _dependencies = State(initialValue: dependencies)
    }

    var body: some View {
        TabView {
            MemoriesRoute()
                .tabItem {
                    Label("Memories", systemImage: "photo.on.rectangle.angled")
                }

            RadarRoute()
                .tabItem {
                    Label("Radar", systemImage: "location.circle")
                }

            PlannerRoute()
                .tabItem {
                    Label("Planner", systemImage: "calendar.badge.plus")
                }

            ProfileRoute()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .appDependencies(dependencies)
        .id(dependencies.activeGroup.id)
        .onOpenURL { url in
            handleInviteURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .parkMemoryHubGroupDidChange)) { _ in
            reloadDependencies()
        }
        .sheet(item: $pendingInvite) { invite in
            AcceptGroupInviteView(invite: invite, currentGroup: dependencies.activeGroup) {
                try acceptInvite(invite)
            }
        }
        .alert("Invite Link Error", isPresented: inviteErrorBinding) {
            Button("OK") {
                inviteErrorMessage = nil
            }
        } message: {
            Text(inviteErrorMessage ?? "The invite link could not be opened.")
        }
        .alert("Circle Status", isPresented: groupStatusBinding) {
            Button("OK") {
                groupStatusMessage = nil
            }
        } message: {
            Text(groupStatusMessage ?? "Circle updated.")
        }
    }

    private var inviteErrorBinding: Binding<Bool> {
        Binding(
            get: { inviteErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    inviteErrorMessage = nil
                }
            }
        )
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

    private func handleInviteURL(_ url: URL) {
        do {
            pendingInvite = try GroupInviteCodec.invite(from: url)
        } catch {
            inviteErrorMessage = error.localizedDescription
        }
    }

    private func acceptInvite(_ invite: GroupInvite) throws {
        if dependencies.activeGroup.id == invite.groupID {
            groupStatusMessage = "This device is already in \(invite.groupDisplayName). Circle code \(invite.groupCode)."
            return
        }

        try FileDeviceIdentityStore.acceptInvite(invite)
        groupStatusMessage = "Joined \(invite.groupDisplayName). Circle code \(invite.groupCode)."
        reloadDependencies()
    }

    private func reloadDependencies() {
        dependencies = .production()
    }
}

private struct AcceptGroupInviteView: View {
    @Environment(\.dismiss) private var dismiss
    let invite: GroupInvite
    let currentGroup: GroupSpace
    let onAccept: () throws -> Void
    @State private var errorMessage: String?

    private var isAlreadyInGroup: Bool {
        currentGroup.id == invite.groupID
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(invite.groupDisplayName)
                            .font(.headline)

                        Text("Join this circle on this device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("Circle Codes") {
                    LabeledContent("Current", value: currentGroup.groupCode)
                    LabeledContent("Invite", value: invite.groupCode)
                }

                if isAlreadyInGroup {
                    Section {
                        Text("This device is already using this circle.")
                            .foregroundStyle(.secondary)
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
                    Button(isAlreadyInGroup ? "Done" : "Join") {
                        joinGroup()
                    }
                }
            }
        }
    }

    private func joinGroup() {
        guard !isAlreadyInGroup else {
            dismiss()
            return
        }

        do {
            try onAccept()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ParkHubView()
}
