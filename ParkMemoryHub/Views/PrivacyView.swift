import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var shareLocation = true
    @State private var shareMedia = true
    @State private var shareProfile = true
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    @State private var showExportAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Privacy Settings")) {
                    Toggle("Share Location with Family", isOn: $shareLocation)
                        .tint(Theme.accentColor)
                        .animation(Theme.animationFast, value: shareLocation)
                    
                    Toggle("Share Media with Family", isOn: $shareMedia)
                        .tint(Theme.accentColor)
                        .animation(Theme.animationFast, value: shareMedia)
                    
                    Toggle("Share Profile with Family", isOn: $shareProfile)
                        .tint(Theme.accentColor)
                        .animation(Theme.animationFast, value: shareProfile)
                }
                
                Section(header: Text("About Privacy")) {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Location Sharing")
                            .font(Theme.captionFont)
                            .fontWeight(.semibold)
                        Text("Allow family members to see your current location on the radar")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                        
                        Divider()
                        
                        Text("Media Sharing")
                            .font(Theme.captionFont)
                            .fontWeight(.semibold)
                        Text("Share your photos and videos with family members")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                        
                        Divider()
                        
                        Text("Profile Sharing")
                            .font(Theme.captionFont)
                            .fontWeight(.semibold)
                        Text("Allow family members to view your profile information")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, Theme.spacingS)
                }
                
                Section(header: Text("Data Management")) {
                    Button("Request Data Export") {
                        showExportAlert = true
                    }
                    .foregroundColor(Theme.primaryColor)
                    
                    Button("Delete Account", role: .destructive) {
                        showDeleteAlert = true
                    }
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .alert("Data Export", isPresented: $showExportAlert) {
            Button("OK") { }
        } message: {
            Text("Your data export request has been submitted. You will receive an email with your data within 48 hours.")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .onAppear {
            loadCurrentPreferences()
        }
    }
    
    private func loadCurrentPreferences() {
        guard let userId = firebaseService.currentUser?.uid else { return }

        Task {
            do {
                // Get user profile which contains preference data
                if let profile = try await firebaseService.getUserProfile(userId: userId) {
                    DispatchQueue.main.async {
                        self.shareLocation = profile.shareLocation
                        self.shareMedia = profile.shareMedia
                        self.shareProfile = profile.shareProfile
                    }
                }
            } catch {
                print("Failed to load preferences: \(error)")
                // Keep default values if loading fails
            }
        }
    }
    
    private func savePreferences() {
        guard let userId = firebaseService.currentUser?.uid else { return }
        
        isSaving = true
        
        Task {
            do {
                let preferences: [String: Any] = [
                    "shareLocation": shareLocation,
                    "shareMedia": shareMedia,
                    "shareProfile": shareProfile
                ]
                
                try await firebaseService.updateUserPreferences(
                    userId: userId,
                    preferences: preferences
                )
                
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSaving = false
                    // Handle error
                    print("Failed to save privacy preferences: \(error)")
                }
            }
        }
    }
    
    private func deleteAccount() {
        // Implement account deletion logic
        // This would typically involve:
        // 1. Confirming with the user
        // 2. Deleting all user data from Firebase
        // 3. Signing out the user
        // 4. Navigating back to auth screen
    }
}

#Preview {
    PrivacyView()
        .environmentObject(FirebaseService.shared)
}
