import SwiftUI
import Foundation

class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var errorMessage: String?
    @Published var showAlert: Bool = false
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var toastType: ToastType = .info
    
    private init() {}
    
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.showAlert = true
        }
    }
    
    func handleError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showAlert = true
        }
    }
    
    func showToast(_ message: String, type: ToastType = .info, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastType = type
            self.showToast = true
            
            // Auto-hide toast after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.showToast = false
            }
        }
    }
    
    func clearError() {
        errorMessage = nil
        showAlert = false
    }
    
    func clearToast() {
        showToast = false
        toastMessage = ""
    }
}

enum ToastType {
    case success, error, warning, info
    
    var backgroundColor: Color {
        switch self {
        case .success:
            return Theme.secondaryColor
        case .error:
            return Theme.errorColor
        case .warning:
            return Theme.warningColor
        case .info:
            return Theme.primaryColor
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

// MARK: - Error Alert View Modifier
struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorManager: ErrorManager
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorManager.showAlert) {
                Button("OK") {
                    errorManager.clearError()
                }
            } message: {
                Text(errorManager.errorMessage ?? "An unknown error occurred")
            }
    }
}

// MARK: - Toast View Modifier
struct ToastModifier: ViewModifier {
    @ObservedObject var errorManager: ErrorManager
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if errorManager.showToast {
                VStack {
                    Spacer()
                    
                    HStack(spacing: Theme.spacingS) {
                        Image(systemName: errorManager.toastType.icon)
                            .foregroundColor(.white)
                        
                        Text(errorManager.toastMessage)
                            .font(Theme.captionFont)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Button(action: {
                            errorManager.clearToast()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    }
                    .padding(Theme.spacingM)
                    .background(errorManager.toastType.backgroundColor)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.cornerRadiusM)
                    .themeShadow(.medium)
                    .padding(.horizontal, Theme.spacingM)
                    .padding(.bottom, Theme.spacingL)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Theme.springAnimation, value: errorManager.showToast)
                }
            }
        }
    }
}

extension View {
    func errorAlert(_ errorManager: ErrorManager) -> some View {
        modifier(ErrorAlertModifier(errorManager: errorManager))
    }
    
    func toast(_ errorManager: ErrorManager) -> some View {
        modifier(ToastModifier(errorManager: errorManager))
    }
}
