import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var activityNotifications = true
    @State private var mediaNotifications = true
    @State private var pingNotifications = true
    @State private var locationUpdates = true
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Notification Preferences")) {
                    Toggle("Activity Updates", isOn: $activityNotifications)
                        .tint(Theme.accentColor)
                        .animation(Theme.animationFast, value: activityNotifications)
                    
                    Toggle("New Media Shares", isOn: $mediaNotifications)
                        .tint(Theme.accentColor)
                        .animation(Theme.animationFast, value: mediaNotifications)
                    
                    Toggle("Location Pings", isOn: $pingNotifications)
                        .tint(Theme.accentColor)
                        .animation(Theme.animationFast, value: pingNotifications)
                    
                    Toggle("Location Updates", isOn: $locationUpdates)
                        .tint(Theme.accentColor)
                        .animation(Theme.animationFast, value: locationUpdates)
                }
                
                Section(header: Text("About Notifications")) {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Activity Updates")
                            .font(Theme.captionFont)
                            .fontWeight(.semibold)
                        Text("Get notified when family members create or update activities")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                        
                        Divider()
                        
                        Text("Media Shares")
                            .font(Theme.captionFont)
                            .fontWeight(.semibold)
                        Text("Receive notifications when family members share new photos or videos")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                        
                        Divider()
                        
                        Text("Location Pings")
                            .font(Theme.captionFont)
                            .fontWeight(.semibold)
                        Text("Get notified when family members send you location pings")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, Theme.spacingS)
                }
            }
            .navigationTitle("Notifications")
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
        .onAppear {
            loadCurrentPreferences()
        }
    }
    
    private func loadCurrentPreferences() {
        guard let userId = firebaseService.currentUser?.uid else { return }

        Task {
            do {
                // Try to get user profile to load preferences (not used currently but kept for future)
                _ = try await firebaseService.getUserProfile(userId: userId)

                DispatchQueue.main.async {
                        // Load notification preferences from UserDefaults as fallback
                        // since UserProfile doesn't store these directly
                        self.activityNotifications = UserDefaults.standard.bool(forKey: "activityNotifications")
                        self.mediaNotifications = UserDefaults.standard.bool(forKey: "mediaNotifications")
                        self.pingNotifications = UserDefaults.standard.bool(forKey: "pingNotifications")
                        self.locationUpdates = UserDefaults.standard.bool(forKey: "locationUpdates")

                        // If UserDefaults has no values, use defaults (true)
                        if UserDefaults.standard.object(forKey: "activityNotifications") == nil {
                            self.activityNotifications = true
                            self.mediaNotifications = true
                            self.pingNotifications = true
                            self.locationUpdates = true
                        }
                    }
            } catch {
                print("Failed to load notification preferences: \(error)")
                // Use default values
                DispatchQueue.main.async {
                    self.activityNotifications = true
                    self.mediaNotifications = true
                    self.pingNotifications = true
                    self.locationUpdates = true
                }
            }
        }
    }
    
    private func savePreferences() {
        guard let userId = firebaseService.currentUser?.uid else { return }
        
        isSaving = true
        
        Task {
            do {
                let preferences: [String: Any] = [
                    "activityNotifications": activityNotifications,
                    "mediaNotifications": mediaNotifications,
                    "pingNotifications": pingNotifications,
                    "locationUpdates": locationUpdates
                ]
                
                try await firebaseService.updateUserPreferences(
                    userId: userId,
                    preferences: preferences
                )

                // Also save to UserDefaults for quick access
                UserDefaults.standard.set(self.activityNotifications, forKey: "activityNotifications")
                UserDefaults.standard.set(self.mediaNotifications, forKey: "mediaNotifications")
                UserDefaults.standard.set(self.pingNotifications, forKey: "pingNotifications")
                UserDefaults.standard.set(self.locationUpdates, forKey: "locationUpdates")

                DispatchQueue.main.async {
                    self.isSaving = false
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSaving = false
                    // Handle error
                    print("Failed to save notification preferences: \(error)")
                }
            }
        }
    }
}

#Preview {
    NotificationsView()
        .environmentObject(FirebaseService.shared)
}
