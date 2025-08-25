import SwiftUI

struct MediaDetailView: View {
    @State private var item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var isLiked = false
    @State private var isLoading = false
    
    init(item: MediaItem) {
        self._item = State(initialValue: item)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Media content
                    AsyncImage(url: URL(string: item.mediaURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    }
                    .frame(maxHeight: 400)
                    .clipped()
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Header info
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.username)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text(item.createdAt, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: toggleLike) {
                                HStack(spacing: 4) {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: isLiked ? "heart.fill" : "heart")
                                            .foregroundColor(isLiked ? .red : .gray)
                                    }
                                    
                                    Text("\(item.likes.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                            }
                            .disabled(isLoading)
                        }
                        
                        // Caption
                        if let caption = item.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        
                        // Location info with fallback text if names are missing
                        if let location = item.location {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let parkName = location.parkName, !parkName.isEmpty {
                                            Text(parkName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        } else {
                                            Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                        }
                                        if let rideName = location.rideName, !rideName.isEmpty {
                                            Text(rideName)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Applied filter
                        if let filter = item.appliedFilter, !filter.isEmpty && filter != "None" {
                            HStack {
                                Image(systemName: "camera.filters")
                                    .foregroundColor(.purple)
                                
                                Text("Filter: \(filter)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Frame theme
                        if let theme = item.frameTheme, !theme.isEmpty {
                            HStack {
                                Image(systemName: "rectangle.3.group.fill")
                                    .foregroundColor(.orange)
                                
                                Text("Theme: \(theme)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Tags
                        if !item.tags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(item.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Media details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 8) {
                                DetailRow(
                                    icon: "camera.fill",
                                    title: "Type",
                                    value: item.mediaType.rawValue.capitalized
                                )
                                
                                DetailRow(
                                    icon: "calendar",
                                    title: "Created",
                                    value: item.createdAt.formatted(date: .complete, time: .shortened)
                                )
                                
                                if let location = item.location {
                                    DetailRow(
                                        icon: "location.fill",
                                        title: "Coordinates",
                                        value: String(format: "%.4f, %.4f", location.latitude, location.longitude)
                                    )
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Memory Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            saveCurrentImage()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            checkInitialLikeStatus()
        }
    }
    
    private func saveCurrentImage() {
        guard let url = URL(string: item.mediaURL) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    await MainActor.run { HapticManager.shared.success() }
                }
            } catch {
                print("❌ Failed to download image for saving: \(error)")
                await MainActor.run { HapticManager.shared.error() }
            }
        }
    }
    
    private func checkInitialLikeStatus() {
        guard let userId = firebaseService.currentUser?.uid else { return }
        isLiked = item.likes.contains(userId)
    }
    
    private func toggleLike() {
        guard let userId = firebaseService.currentUser?.uid else { return }
        
        // Optimistic UI update
        let wasLiked = isLiked
        isLiked.toggle()
        
        // Update local item likes array
        if isLiked {
            if !item.likes.contains(userId) {
                item.likes.append(userId)
            }
        } else {
            item.likes.removeAll { $0 == userId }
        }
        
        // Add haptic feedback
        HapticManager.shared.lightTap()
        
        isLoading = true
        
        Task {
            do {
                try await firebaseService.toggleLike(mediaId: item.id, isLiked: isLiked)
                
                await MainActor.run {
                    isLoading = false
                    HapticManager.shared.success()
                }
            } catch {
                // Revert the optimistic update if Firebase update fails
                await MainActor.run {
                    isLiked = wasLiked
                    if wasLiked {
                        if !item.likes.contains(userId) {
                            item.likes.append(userId)
                        }
                    } else {
                        item.likes.removeAll { $0 == userId }
                    }
                    isLoading = false
                    HapticManager.shared.error()
                }
                print("❌ Error toggling like: \(error.localizedDescription)")
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
}

#Preview {
    MediaDetailView(item: MediaItem(
        id: "1",
        userId: "user1",
        username: "John Doe",
        mediaURL: "https://example.com/image.jpg",
        mediaType: .photo,
        caption: "Having a great time at Disney World!",
        location: MediaItem.LocationInfo(
            latitude: 28.4177,
            longitude: -81.5812,
            parkName: "Disney World",
            rideName: "Space Mountain"
        ),
        tags: ["Disney", "Fun", "Family"],
        appliedFilter: "Vibrant",
        frameTheme: "Disney World"
    ))
}
