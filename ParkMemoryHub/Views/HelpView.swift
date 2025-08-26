import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private let faqs = [
        FAQ(
            question: "How do I add a family member?",
            answer: "Enter their family code during sign-up or invite them via the Profile screen. You can also share your family code with them directly."
        ),
        FAQ(
            question: "How do I share a photo?",
            answer: "Go to the Memories tab and tap the camera button to capture or upload a photo. You can add captions, tags, and location information."
        ),
        FAQ(
            question: "How does the Family Radar work?",
            answer: "The Family Radar shows real-time locations of all family members on a map. You can send location pings and see where everyone is in the park."
        ),
        FAQ(
            question: "How do I create an activity?",
            answer: "Use the Planner tab to create new activities. You can schedule rides, meals, or other park experiences and let family members vote on them."
        ),
        FAQ(
            question: "How do I manage accessibility?",
            answer: "Use system settings for Dynamic Type, VoiceOver, and high contrast. ParkMemoryHub supports large text, VoiceOver labels, and high-contrast colors."
        ),
        FAQ(
            question: "How do I change my profile picture?",
            answer: "Go to Profile > Edit Profile and tap on your current profile picture to select a new one from your photo library."
        )
    ]
    
    private let troubleshooting = [
        FAQ(
            question: "Location not updating",
            answer: "Ensure location services are enabled in Settings > Privacy & Security > Location Services. Also check that you've granted location permission to the app."
        ),
        FAQ(
            question: "Photos not uploading",
            answer: "Check your internet connection and ensure you have sufficient storage space. Try closing and reopening the app if the issue persists."
        ),
        FAQ(
            question: "Can't see family members",
            answer: "Verify that all family members are using the same family code. Check that location sharing is enabled in Privacy settings."
        ),
        FAQ(
            question: "App crashes frequently",
            answer: "Try updating to the latest version of the app. If the issue continues, restart your device or reinstall the app."
        )
    ]
    
    private var filteredFAQs: [FAQ] {
        if searchText.isEmpty {
            return faqs
        } else {
            return faqs.filter { $0.question.localizedCaseInsensitiveContains(searchText) || $0.answer.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                    
                    TextField("Search help topics...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(Theme.spacingM)
                .background(Theme.backgroundSecondary)
                .cornerRadius(Theme.cornerRadiusM)
                .padding(.horizontal, Theme.spacingM)
                .padding(.top, Theme.spacingM)
                
                // Content
                ScrollView {
                    LazyVStack(spacing: Theme.spacingL) {
                        // Quick Actions
                        VStack(alignment: .leading, spacing: Theme.spacingM) {
                            Text("Quick Actions")
                                .font(Theme.headlineFont)
                                .padding(.horizontal, Theme.spacingM)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.spacingM) {
                                    QuickActionButton(
                                        title: "Contact Support",
                                        icon: "envelope.fill",
                                        color: Theme.primaryColor
                                    ) {
                                        contactSupport()
                                    }
                                    
                                    QuickActionButton(
                                        title: "Privacy Settings",
                                        icon: "lock.fill",
                                        color: Theme.accentColor
                                    ) {
                                        // Navigate to privacy settings
                                    }
                                    
                                    QuickActionButton(
                                        title: "View Tutorials",
                                        icon: "book.fill",
                                        color: Theme.secondaryColor
                                    ) {
                                        viewTutorials()
                                    }

                                    QuickActionButton(
                                        title: "App Settings",
                                        icon: "gearshape.fill",
                                        color: Theme.warningColor
                                    ) {
                                        // Navigate to app settings
                                    }
                                }
                                .padding(.horizontal, Theme.spacingM)
                            }
                        }
                        
                        // FAQs
                        VStack(alignment: .leading, spacing: Theme.spacingM) {
                            Text("Frequently Asked Questions")
                                .font(Theme.headlineFont)
                                .padding(.horizontal, Theme.spacingM)
                            
                            LazyVStack(spacing: Theme.spacingS) {
                                ForEach(filteredFAQs) { faq in
                                    FAQRow(faq: faq)
                                }
                            }
                            .padding(.horizontal, Theme.spacingM)
                        }
                        
                        // Troubleshooting
                        VStack(alignment: .leading, spacing: Theme.spacingM) {
                            Text("Troubleshooting")
                                .font(Theme.headlineFont)
                                .padding(.horizontal, Theme.spacingM)
                            
                            LazyVStack(spacing: Theme.spacingS) {
                                ForEach(troubleshooting) { faq in
                                    FAQRow(faq: faq)
                                }
                            }
                            .padding(.horizontal, Theme.spacingM)
                        }
                        
                        // Contact Info
                        VStack(alignment: .leading, spacing: Theme.spacingM) {
                            Text("Still Need Help?")
                                .font(Theme.headlineFont)
                                .padding(.horizontal, Theme.spacingM)
                            
                            VStack(spacing: Theme.spacingS) {
                                ContactInfoRow(
                                    icon: "envelope.fill",
                                    title: "Email Support",
                                    subtitle: "support@parkmemoryhub.com"
                                )
                                
                                ContactInfoRow(
                                    icon: "phone.fill",
                                    title: "Phone Support",
                                    subtitle: "+1 (555) 123-4567"
                                )
                                
                                ContactInfoRow(
                                    icon: "clock.fill",
                                    title: "Support Hours",
                                    subtitle: "Mon-Fri 9AM-6PM EST"
                                )
                            }
                            .padding(Theme.spacingM)
                            .background(Theme.backgroundSecondary)
                            .cornerRadius(Theme.cornerRadiusM)
                            .padding(.horizontal, Theme.spacingM)
                        }
                    }
                    .padding(.vertical, Theme.spacingM)
                }
            }
            .navigationTitle("Help & FAQ")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func contactSupport() {
        // Open email client or navigate to contact support screen
        if let url = URL(string: "mailto:support@parkmemoryhub.com?subject=Support%20Request") {
            UIApplication.shared.open(url)
        }
    }

    private func viewTutorials() {
        // Navigate to tutorials or open help documentation
        // This could open a web view or navigate to a tutorial screen
        print("Navigate to tutorials")
    }
}

struct FAQ: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct FAQRow: View {
    let faq: FAQ
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Button(action: {
                withAnimation(Theme.springAnimation) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(faq.question)
                        .font(Theme.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(Theme.animationFast, value: isExpanded)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(faq.answer)
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, Theme.spacingXS)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.spacingM)
        .background(Theme.backgroundSecondary)
        .cornerRadius(Theme.cornerRadiusM)
        .themeShadow(.small)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.spacingS) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(Circle())
                    .themeShadow(.small)
                
                Text(title)
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 80)
    }
}

struct ContactInfoRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: Theme.spacingM) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Theme.primaryColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.bodyFont)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    HelpView()
}
