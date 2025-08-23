import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var userProfile: UserProfile?
    @State private var isLoading = false
    @State private var showEditProfile = false
    @State private var showLogoutAlert = false
    @State private var showNotificationsView = false
    @State private var showPrivacyView = false
    @State private var showHelpView = false
    @State private var showSupportView = false
    @State private var preferredColorScheme: ColorScheme?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading profile...")
                    .font(.headline)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            AsyncImage(url: URL(string: userProfile?.avatarURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                            )

                            VStack(spacing: 8) {
                                Text(userProfile?.username ?? "Unknown User")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(userProfile?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 20)

                        // Profile Info
                        VStack(spacing: 16) {
                            ProfileInfoRow(
                                icon: "calendar",
                                title: "Member Since",
                                value: userProfile?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
                            )

                            ProfileInfoRow(
                                icon: "clock",
                                title: "Last Active",
                                value: userProfile?.lastActive.formatted(date: .abbreviated, time: .shortened) ?? "Unknown"
                            )

                            ProfileInfoRow(
                                icon: "person.3.fill",
                                title: "Family Code",
                                value: userProfile?.familyCode ?? "Unknown"
                            )
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)

                        // Settings
                        VStack(spacing: 16) {
                            SettingsSection(title: "Preferences") {
                                SettingsRow(
                                    icon: "face.smiling",
                                    title: "Kid Mode",
                                    subtitle: "Simplified interface for younger users",
                                    isToggle: true,
                                    toggleValue: userProfile?.isKidMode ?? false,
                                    toggleAction: { toggleAction in
                                        toggleKidMode(toggleAction)
                                    }
                                )

                                VStack(alignment: .leading, spacing: Theme.spacingS) {
                                    Text("Color Scheme")
                                        .font(Theme.captionFont)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Theme.textSecondary)

                                    Picker("Color Scheme", selection: $preferredColorScheme) {
                                        Text("System").tag(nil as ColorScheme?)
                                        Text("Light").tag(ColorScheme.light as ColorScheme?)
                                        Text("Dark").tag(ColorScheme.dark as ColorScheme?)
                                    }
                                    .pickerStyle(.segmented)
                                    .onChange(of: preferredColorScheme) { _, newValue in
                                        saveColorScheme(newValue)
                                    }
                                }
                                .padding(.horizontal, Theme.spacingM)
                            }

                            SettingsSection(title: "Account") {
                                SettingsRow(
                                    icon: "bell.fill",
                                    title: "Notifications",
                                    subtitle: "Manage push notifications",
                                    isToggle: false
                                ) {
                                    showNotificationsView = true
                                }

                                SettingsRow(
                                    icon: "lock.fill",
                                    title: "Privacy",
                                    subtitle: "Manage data sharing",
                                    isToggle: false
                                ) {
                                    showPrivacyView = true
                                }
                            }

                            SettingsSection(title: "Support") {
                                SettingsRow(
                                    icon: "questionmark.circle.fill",
                                    title: "Help & FAQ",
                                    subtitle: "Get help using the app",
                                    isToggle: false
                                ) {
                                    showHelpView = true
                                }

                                SettingsRow(
                                    icon: "envelope.fill",
                                    title: "Contact Support",
                                    subtitle: "Send us a message",
                                    isToggle: false
                                ) {
                                    showSupportView = true
                                }
                            }
                        }

                        // Logout Button
                        Button {
                            showLogoutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(userProfile: userProfile)
        }
        .sheet(isPresented: $showNotificationsView) {
            NotificationsView()
        }
        .sheet(isPresented: $showPrivacyView) {
            PrivacyView()
        }
        .sheet(isPresented: $showHelpView) {
            HelpView()
        }
        .sheet(isPresented: $showSupportView) {
            ContactSupportView()
        }
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onAppear {
            loadUserProfile()
            loadColorScheme()
        }
        .preferredColorScheme(preferredColorScheme)
        .toast(ErrorManager.shared)
    }

    private func loadUserProfile() {
        guard firebaseService.currentUser != nil else { return }

        isLoading = true

        Task {
            do {
                let profile = try await firebaseService.getUserProfile(userId: firebaseService.currentUser!.uid)

                DispatchQueue.main.async {
                    self.userProfile = profile
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    ErrorManager.shared.handleError(error)
                }
            }
        }
    }

    private func toggleKidMode(_ isEnabled: Bool) {
        guard let profile = userProfile else { return }

        // Update local profile
        userProfile = UserProfile(
            id: profile.id,
            username: profile.username,
            email: profile.email,
            avatarURL: profile.avatarURL,
            isKidMode: isEnabled,
            familyCode: profile.familyCode
        )

        // Save to Firebase
        Task {
            do {
                try await firebaseService.saveUserProfile(userProfile!)
            } catch {
                ErrorManager.shared.handleError(error)
                // Revert local change on error
                loadUserProfile()
            }
        }
    }

    private func signOut() {
        do {
            try firebaseService.signOut()
        } catch {
            ErrorManager.shared.handleError(error)
        }
    }

    private func loadColorScheme() {
        if let scheme = UserDefaults.standard.string(forKey: "preferredColorScheme") {
            switch scheme {
            case "light":
                preferredColorScheme = .light
            case "dark":
                preferredColorScheme = .dark
            default:
                preferredColorScheme = nil
            }
        }
    }

    private func saveColorScheme(_ scheme: ColorScheme?) {
        var schemeString = "system"
        if let scheme = scheme {
            switch scheme {
            case .light:
                schemeString = "light"
            case .dark:
                schemeString = "dark"
            @unknown default:
                schemeString = "system"
            }
        }
        UserDefaults.standard.set(schemeString, forKey: "preferredColorScheme")
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(spacing: 1) {
                content
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isToggle: Bool
    var toggleValue: Bool = false
    let action: (() -> Void)?
    let toggleAction: ((Bool) -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String,
        isToggle: Bool = false,
        toggleValue: Bool = false,
        action: (() -> Void)? = nil,
        toggleAction: ((Bool) -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isToggle = isToggle
        self.toggleValue = toggleValue
        self.action = action
        self.toggleAction = toggleAction
    }

    var body: some View {
        Button {
            if !isToggle {
                action?()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isToggle {
                    Toggle("", isOn: Binding(
                        get: { toggleValue },
                        set: { toggleAction?($0) }
                    ))
                    .labelsHidden()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditProfileView: View {
    let userProfile: UserProfile?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared

    @State private var username = ""
    @State private var isKidMode = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Username", text: $username)

                    Toggle("Kid Mode", isOn: $isKidMode)
                }

                Section("About Kid Mode") {
                    Text("Kid Mode provides a simplified interface with larger buttons, colorful animations, and easier navigation for younger family members.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(username.isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            if let profile = userProfile {
                username = profile.username
                isKidMode = profile.isKidMode
            }
        }
    }

    private func saveProfile() {
        guard let profile = userProfile else { return }

        isSaving = true

        Task {
            do {
                let updatedProfile = UserProfile(
                    id: profile.id,
                    username: username,
                    email: profile.email,
                    avatarURL: profile.avatarURL,
                    isKidMode: isKidMode,
                    familyCode: profile.familyCode
                )

                try await firebaseService.saveUserProfile(updatedProfile)

                DispatchQueue.main.async {
                    self.isSaving = false
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSaving = false
                    // Handle error
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(FirebaseService.shared)
}
