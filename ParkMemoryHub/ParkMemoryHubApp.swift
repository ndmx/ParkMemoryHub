//
//  ParkMemoryHubApp.swift
//  ParkMemoryHub
//
//  Created by Alexander Ukaga on 8/18/25.
//

import CloudKit
import SwiftUI
import UIKit

@main
struct ParkMemoryHubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ParkHubView()
                .environment(\.font, .system(.body, design: .rounded))
        }
    }
}

/// Handles incoming CloudKit share acceptances (the user tapped an iCloud invite
/// link). Accepting joins this device to the shared circle, then notifies the UI
/// to reload its dependencies for the new circle.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task {
            do {
                try await CircleShareAcceptor.accept(cloudKitShareMetadata)
                await MainActor.run {
                    NotificationCenter.default.post(name: .parkMemoryHubGroupDidChange, object: nil)
                }
            } catch {
                // Surfaced on the next manual sync; nothing actionable here.
            }
        }
    }
}
