//
//  ParkMemoryHubApp.swift
//  ParkMemoryHub
//
//  Created by Alexander Ukaga on 8/18/25.
//

import SwiftUI

@main
struct ParkMemoryHubApp: App {
    var body: some Scene {
        WindowGroup {
            ParkHubView()
                .environment(\.font, .system(.body, design: .rounded))
        }
    }
}
