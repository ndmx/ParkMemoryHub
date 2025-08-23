//
//  ContentView.swift
//  ParkMemoryHub
//
//  Created by Alexander Ukaga on 8/18/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var errorManager = ErrorManager.shared
    
    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .environmentObject(firebaseService)
        .environmentObject(errorManager)
        .errorAlert(errorManager)
        .toast(errorManager)
    }
}

#Preview {
    ContentView()
}
