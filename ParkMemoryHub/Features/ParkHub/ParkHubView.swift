import CloudKit
import SwiftUI

struct ParkHubView: View {
    @State private var dependencies: AppDependencies
    @State private var showsAccountWarning = false

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
        .safeAreaInset(edge: .top) {
            if showsAccountWarning {
                accountWarningBanner
            }
        }
        .task {
            await refreshAccountStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .parkMemoryHubGroupDidChange)) { _ in
            reloadDependencies()
        }
    }

    private var accountWarningBanner: some View {
        Text("Sign in to iCloud in Settings to sync and share circles. Your memories stay on this device until you do.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.orange)
    }

    private func refreshAccountStatus() async {
        let status = await dependencies.circleSync.accountStatus()
        showsAccountWarning = status != .available
    }

    private func reloadDependencies() {
        dependencies = .production()
        Task { await refreshAccountStatus() }
    }
}

#Preview {
    ParkHubView()
}
