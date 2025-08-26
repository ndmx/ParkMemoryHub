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
    @State private var showAvatarEditor = false

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
                            Button(action: {
                                HapticManager.shared.lightTap()
                                showAvatarEditor = true
                            }) {
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
                                .overlay(
                                    // Camera overlay to indicate it's clickable
                                    Circle()
                                        .fill(.black.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        )
                                        .opacity(0.8)
                                )
                            }
                            .buttonStyle(.plain)

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
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.brandDeleteRed))
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
        .sheet(isPresented: $showAvatarEditor) {
            ProfilePictureEditorView(userProfile: userProfile) { updatedProfile in
                userProfile = updatedProfile
                loadUserProfile() // Refresh the profile data
            }
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

    // Kid Mode removed

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
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var newEmail = ""
    @State private var showEmailVerificationSheet = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Username", text: $username)
                }
                
                Section("Change Email") {
                    TextField("New Email", text: $newEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    Button("Send Verification Link") {
                        startEmailVerification()
                    }
                    .disabled(newEmail.isEmpty)
                }
                
                Section("Change Password") {
                    SecureField("New Password (min 8 chars)", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
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
            .alert("Update Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showEmailVerificationSheet) {
                NavigationStack {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.primaryColor)
                        Text("Verify your new email")
                            .font(.headline)
                        Text("We sent a verification link to \(newEmail). Tap the link in your email to verify, then return here and press 'I've verified'.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("I've verified") {
                            Task { await checkEmailVerificationStatus() }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .primaryActionBackground()
                    }
                    .padding()
                    .navigationTitle("Email Verification")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationCornerRadius(16)
            }
        }
        .onAppear {
            if let profile = userProfile {
                username = profile.username
            }
        }
    }

    private func saveProfile() {
        guard let profile = userProfile else { return }

        // Validate password fields if provided
        if !newPassword.isEmpty || !confirmPassword.isEmpty {
            guard newPassword.count >= 8 else { presentError("Password must be at least 8 characters."); return }
            guard newPassword == confirmPassword else { presentError("Passwords do not match."); return }
        }
        
        isSaving = true

        Task {
            do {
                let updatedProfile = UserProfile(
                    id: profile.id,
                    username: username,
                    email: profile.email,
                    avatarURL: profile.avatarURL,
                    familyCode: profile.familyCode
                )

                try await firebaseService.saveUserProfile(updatedProfile)
                
                // Update password if provided
                if !newPassword.isEmpty {
                    try await FirebaseAuth.Auth.auth().currentUser?.updatePassword(to: newPassword)
                }

                DispatchQueue.main.async {
                    self.isSaving = false
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSaving = false
                    presentError(error.localizedDescription)
                }
            }
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Email Verification Flow
    private func startEmailVerification() {
        guard !newEmail.isEmpty else { return }
        // Attempt to send verification to new email, fallback to updateEmail then send verification on current if unavailable
        if let user = FirebaseAuth.Auth.auth().currentUser {
            if #available(iOS 13.0, *) {
                user.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            presentError(error.localizedDescription)
                        } else {
                            showEmailVerificationSheet = true
                        }
                    }
                }
            } else {
                // Fallback: try direct update (not ideal) and prompt user to verify
                user.updateEmail(to: newEmail) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            presentError(error.localizedDescription)
                        } else {
                            showEmailVerificationSheet = true
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    private func checkEmailVerificationStatus() async {
        guard let user = FirebaseAuth.Auth.auth().currentUser else { return }
        do {
            try await user.reload()
            // After verification link is tapped, Firebase updates the email automatically
            if user.email?.lowercased() == newEmail.lowercased() {
                showEmailVerificationSheet = false
            } else {
                presentError("We haven't detected the change yet. Please tap the link in your email, then try again.")
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(FirebaseService.shared)
}
