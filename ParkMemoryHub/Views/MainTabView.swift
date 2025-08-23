import SwiftUI

struct MainTabView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var selectedTab = 0
    @State private var notificationCount = 0
    @State private var unreadMediaCount = 0
    @State private var pendingActivitiesCount = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MemoryMingle - Shared Album
            NavigationStack {
                AlbumView()
            }
            .tabItem {
                Image(systemName: "photo.on.rectangle.angled")
                Text("Memories")
            }
            .badge(unreadMediaCount > 0 ? unreadMediaCount : 0)
            .tag(0)
            
            // ReuniteRadar - Location Map
            NavigationStack {
                RadarView()
            }
            .tabItem {
                Image(systemName: "location.circle")
                Text("Radar")
            }
            .badge(notificationCount > 0 ? notificationCount : 0)
            .tag(1)
            
            // ParkSync - Planning
            NavigationStack {
                PlannerView()
            }
            .tabItem {
                Image(systemName: "calendar.badge.plus")
                Text("Planner")
            }
            .badge(pendingActivitiesCount > 0 ? pendingActivitiesCount : 0)
            .tag(2)
            
            // Profile/Settings
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.circle")
                Text("Profile")
            }
            .tag(3)
        }
        .accentColor(Theme.primaryColor)
        .animation(.snappy(duration: 0.3), value: selectedTab)
        .onAppear {
            setupTabBarAppearance()
            loadNotificationCounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            loadNotificationCounts()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func loadNotificationCounts() {
        Task {
            do {
                let familyCode = try await firebaseService.getCurrentFamilyCode() ?? ""
                guard !familyCode.isEmpty else { return }
                
                // Load notification counts
                let notifications = try await firebaseService.getUnreadNotifications(familyCode: familyCode)
                let media = try await firebaseService.getUnreadMedia(familyCode: familyCode)
                let activities = try await firebaseService.getPendingActivities(familyCode: familyCode)
                
                DispatchQueue.main.async {
                    self.notificationCount = notifications.count
                    self.unreadMediaCount = media.count
                    self.pendingActivitiesCount = activities.count
                }
            } catch {
                print("Failed to load notification counts: \(error)")
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(FirebaseService.shared)
}
