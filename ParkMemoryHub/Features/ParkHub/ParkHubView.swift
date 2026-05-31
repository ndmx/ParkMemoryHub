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
        .tint(Lumina.Color.accent)
        .toolbarBackground(.regularMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
        Label {
            Text("Sign in to iCloud in Settings to sync and share circles. Your memories stay on this device until you do.")
        } icon: {
            Image(systemName: "icloud.slash.fill")
        }
        .font(.footnote.weight(.medium))
        .multilineTextAlignment(.leading)
        .foregroundStyle(Lumina.Color.onAccent)
        .padding(.horizontal, Lumina.Space.md)
        .padding(.vertical, Lumina.Space.sm)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Lumina.Color.accentSecondary, Lumina.Color.accentSecondary.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
