import SwiftUI

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var message = ""
    @State private var subject = ""
    @State private var priority = SupportPriority.medium
    @State private var isSending = false
    @State private var showSuccessToast = false
    
    private let subjects = [
        "General Question",
        "Technical Issue",
        "Feature Request",
        "Bug Report",
        "Account Issue",
        "Other"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Info
                VStack(spacing: Theme.spacingM) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.primaryColor)
                    
                    Text("How can we help?")
                        .font(Theme.headlineFont)
                        .multilineTextAlignment(.center)
                    
                    Text("Send us a message and we'll get back to you as soon as possible.")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.spacingL)
                .background(Theme.backgroundSecondary)
                
                // Form
                Form {
                    Section(header: Text("Message Details")) {
                        Picker("Subject", selection: $subject) {
                            Text("Select a subject").tag("")
                            ForEach(subjects, id: \.self) { subject in
                                Text(subject).tag(subject)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Picker("Priority", selection: $priority) {
                            ForEach(SupportPriority.allCases, id: \.self) { priority in
                                HStack {
                                    Circle()
                                        .fill(priority.color)
                                        .frame(width: 12, height: 12)
                                    Text(priority.title)
                                }
                                .tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section(header: Text("Your Message")) {
                        TextEditor(text: $message)
                            .frame(minHeight: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusS)
                                    .stroke(Theme.textTertiary, lineWidth: 1)
                            )
                        
                        HStack {
                            Spacer()
                            Text("\(message.count)/1000")
                                .font(Theme.captionFont)
                                .foregroundColor(message.count > 900 ? Theme.warningColor : Theme.textSecondary)
                        }
                    }
                    
                    Section(header: Text("Contact Information")) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(Theme.primaryColor)
                            Text("support@parkmemoryhub.com")
                                .font(Theme.bodyFont)
                        }
                        
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(Theme.primaryColor)
                            Text("+1 (555) 123-4567")
                                .font(Theme.bodyFont)
                        }
                        
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(Theme.primaryColor)
                            Text("Mon-Fri 9AM-6PM EST")
                                .font(Theme.bodyFont)
                        }
                    }
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(message.isEmpty || subject.isEmpty || isSending)
                }
            }
        }
        .onAppear {
            if subject.isEmpty && !subjects.isEmpty {
                subject = subjects[0]
            }
        }
        .toast(ErrorManager.shared)
        .onChange(of: message) { _, newValue in
            if newValue.count > 1000 {
                message = String(newValue.prefix(1000))
            }
        }
    }
    
    private func sendMessage() {
        guard let userId = firebaseService.currentUser?.uid else { return }
        
        isSending = true
        
        Task {
            do {
                let fullMessage = """
                Subject: \(subject)
                Priority: \(priority.title)
                
                Message:
                \(message)
                """
                
                try await firebaseService.sendSupportMessage(
                    userId: userId,
                    message: fullMessage
                )
                
                DispatchQueue.main.async {
                    self.isSending = false
                    ErrorManager.shared.showToast("Message sent successfully!", type: .success)
                    
                    // Reset form
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.dismiss()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSending = false
                    ErrorManager.shared.handleError("Failed to send message: \(error.localizedDescription)")
                }
            }
        }
    }
}

enum SupportPriority: CaseIterable {
    case low, medium, high, urgent
    
    var title: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .urgent:
            return "Urgent"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return Theme.secondaryColor
        case .medium:
            return Theme.primaryColor
        case .high:
            return Theme.warningColor
        case .urgent:
            return Theme.errorColor
        }
    }
}

#Preview {
    ContactSupportView()
        .environmentObject(FirebaseService.shared)
}
