import SwiftUI
import MapKit

struct ProfileLocationAnnotation: View {
    let user: UserProfile
    let isCurrentUser: Bool
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(isCurrentUser ? Color.blue : Color.purple)
                .frame(width: 50, height: 50)
            
            // Inner ring
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
            
            // Profile picture or initials
            Group {
                if let avatarURL = user.avatarURL, !avatarURL.isEmpty {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        UserInitialsView(username: user.username)
                    }
                } else {
                    UserInitialsView(username: user.username)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Location accuracy indicator (only for current user)
            if isCurrentUser {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .animation(.easeInOut(duration: 1.5).repeatForever(), value: true)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
    }
}

struct UserInitialsView: View {
    let username: String
    
    private var initials: String {
        let components = username.components(separatedBy: " ")
        let firstInitial = components.first?.first?.uppercased() ?? ""
        let lastInitial = components.count > 1 ? components.last?.first?.uppercased() ?? "" : ""
        return firstInitial + lastInitial
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text(initials)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileLocationAnnotation(
            user: UserProfile(
                id: "1",
                username: "John Doe",
                email: "john@example.com",
                avatarURL: nil,
                familyCode: "DEMO"
            ),
            isCurrentUser: true
        )
        
        ProfileLocationAnnotation(
            user: UserProfile(
                id: "2", 
                username: "Jane Smith",
                email: "jane@example.com",
                avatarURL: "https://example.com/avatar.jpg",
                familyCode: "DEMO"
            ),
            isCurrentUser: false
        )
    }
    .padding()
}
