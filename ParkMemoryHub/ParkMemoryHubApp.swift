//
//  ParkMemoryHubApp.swift
//  ParkMemoryHub
//
//  Created by Alexander Ukaga on 8/18/25.
//

import SwiftUI
import FirebaseCore
import BackgroundTasks
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🚀 Configuring Firebase...")
        FirebaseApp.configure()
        // Enable Firebase App Check
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif
        print("✅ Firebase configured successfully!")
        
        // Test Firebase services
        FirebaseConfigTest.testFirebaseServices()
        
        // Test Firebase connection after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task {
                await FirebaseConfigTest.testFirebaseConnection()
            }
        }
        
        // Register background tasks
        registerBackgroundTasks()
        
        return true
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.parkmemoryhub.locationSync", using: nil) { task in
            Task {
                await LocationManager.shared.performBackgroundSync()
                task.setTaskCompleted(success: true)
            }
        }
    }
}

@main
struct ParkMemoryHubApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.font, .system(.body, design: .rounded))
        }
    }
}
