import UIKit
import SwiftUI
import CoreHaptics
import AVFoundation

/// Centralized haptic feedback manager for iOS 18+ enhanced haptics
class HapticManager {
    static let shared = HapticManager()
    
    private var hapticEngine: CHHapticEngine?
    private var supportsHaptics = false
    
    private init() {
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        // Check if device supports haptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            supportsHaptics = true
        } catch {
            print("❌ Failed to create haptic engine: \(error)")
        }
    }
    
    // MARK: - iOS 18 Enhanced Haptic Feedback Types
    
    /// Light tap for UI interactions (buttons, taps)
    func lightTap() {
        if #available(iOS 18.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred(intensity: 0.6)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    /// Medium impact for important actions (photo capture, sharing)
    func mediumImpact() {
        if #available(iOS 18.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
            impactFeedback.impactOccurred(intensity: 0.8)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    /// Heavy impact for critical actions (deletion, errors)
    func heavyImpact() {
        if #available(iOS 18.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.prepare()
            impactFeedback.impactOccurred(intensity: 1.0)
        } else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
    
    /// Success feedback for positive actions
    func success() {
        if #available(iOS 18.0, *) {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.prepare()
            notificationFeedback.notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    /// Error feedback for failures
    func error() {
        if #available(iOS 18.0, *) {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.prepare()
            notificationFeedback.notificationOccurred(.error)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    /// Warning feedback for cautionary actions
    func warning() {
        if #available(iOS 18.0, *) {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.prepare()
            notificationFeedback.notificationOccurred(.warning)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
    
    // MARK: - iOS 18 Music Haptics (Advanced)
    
    /// Camera shutter with realistic feel
    func cameraShutter() {
        guard supportsHaptics else {
            mediumImpact()
            return
        }
        
        playCustomHaptic(intensity: 1.0, sharpness: 0.8, duration: 0.1)
    }
    
    /// Delete action with warning pattern
    func deleteConfirm() {
        guard supportsHaptics else {
            heavyImpact()
            return
        }
        
        // Create a warning pattern
        let events: [CHHapticEvent] = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.2)
        ]
        
        playCustomPattern(events: events)
    }
    
    /// Share success with celebration pattern
    func shareSuccess() {
        guard supportsHaptics else {
            success()
            return
        }
        
        // Create a celebration pattern
        let events: [CHHapticEvent] = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0.1),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0.3)
        ]
        
        playCustomPattern(events: events)
    }
    
    /// Activity voting feedback
    func vote(isPositive: Bool) {
        if isPositive {
            playCustomHaptic(intensity: 0.7, sharpness: 0.6, duration: 0.1)
        } else {
            playCustomHaptic(intensity: 0.5, sharpness: 0.4, duration: 0.1)
        }
    }
    
    // MARK: - Private Helpers
    
    private func playCustomHaptic(intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard supportsHaptics else {
            mediumImpact()
            return
        }
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: duration
        )
        
        playCustomPattern(events: [event])
    }
    
    private func playCustomPattern(events: [CHHapticEvent]) {
        guard supportsHaptics, let engine = hapticEngine else {
            return
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("❌ Failed to play haptic pattern: \(error)")
        }
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Add light haptic feedback to any view interaction
    func hapticTap() -> some View {
        self.onTapGesture {
            HapticManager.shared.lightTap()
        }
    }
    
    /// Add medium haptic feedback for important actions
    func hapticAction() -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    HapticManager.shared.mediumImpact()
                }
        )
    }
}
