import SwiftUI

struct AlbumView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var mediaItems: [MediaItem] = []
    @State private var isLoading = false
    @State private var showCaptureView = false
    @State private var showInstantCamera = false
    @State private var selectedMediaItem: MediaItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Family Memories")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { 
                    HapticManager.shared.lightTap()
                    showInstantCamera = true 
                }) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background {
                            if #available(iOS 18.0, *) {
                                Theme.accentMeshGradient
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Theme.primaryColor)
                            }
                        }
                        .themeShadow(.medium)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading memories...")
                    .font(.headline)
                Spacer()
            } else if mediaItems.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No memories yet!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text("Tap the camera button to capture your first memory")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                VStack(spacing: 12) {
                    // Swipe hint for first time users
                    if mediaItems.count > 0 {
                        HStack {
                            Text("💡 Swipe left on memories to delete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .opacity(0.7)
                    }
                    
                    List {
                        ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                            MediaItemCard(
                                item: item,
                                onTap: {
                                    selectedMediaItem = item
                                },
                                onDelete: {
                                    deleteMemoryAtIndex(index)
                                }
                            )
                            .contextMenu {
                                Button {
                                    HapticManager.shared.lightTap()
                                    saveImageToPhotos(from: item)
                                } label: {
                                    Label("Save to Photos", systemImage: "square.and.arrow.down")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteMemoryAtIndex(index)
                                } label: {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Delete")
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.red)
                                    )
                                }
                                .tint(.clear)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loadMediaItems()
        }
        .refreshable {
            await loadMediaItemsAsync()
        }
        .sheet(isPresented: $showCaptureView, onDismiss: {
            loadMediaItems()
        }) {
            CaptureView()
                .zoomTransition()
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(Theme.cornerRadiusL)
        }
        .sheet(item: $selectedMediaItem) { mediaItem in
            MediaDetailView(item: mediaItem)
                .zoomTransition()
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(Theme.cornerRadiusL)
        }
        .fullScreenCover(isPresented: $showInstantCamera) {
            InstantCameraView()
        }
    }
    
    private func saveImageToPhotos(from item: MediaItem) {
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
    
    private func loadMediaItems() {
        guard firebaseService.currentUser != nil else { return }
        
        Task {
            await loadMediaItemsAsync()
        }
    }
    
    private func loadMediaItemsAsync() async {
        guard firebaseService.currentUser != nil else { return }
        
        DispatchQueue.main.async {
            isLoading = true
        }
        
        do {
            let familyCode = try await firebaseService.getCurrentFamilyCode() ?? ""
            let items = try await firebaseService.getFamilyMedia(familyCode: familyCode)
            
            DispatchQueue.main.async {
                self.mediaItems = items
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                // Handle error
            }
        }
    }
    
    private func deleteMemory(_ mediaItem: MediaItem) {
        // Enhanced haptic feedback for delete action
        HapticManager.shared.deleteConfirm()
        
        Task {
            do {
                // Delete from Firebase
                try await firebaseService.deleteMediaItem(mediaItem)
                
                // Update UI on main thread
                await MainActor.run {
                    mediaItems.removeAll { $0.id == mediaItem.id }
                    // Success haptic feedback
                    HapticManager.shared.success()
                }
            } catch {
                print("❌ Error deleting memory: \(error.localizedDescription)")
                // Error haptic feedback
                await MainActor.run {
                    HapticManager.shared.error()
                }
                // Could add an alert here for user feedback
            }
        }
    }
    
    private func deleteMemoryAtIndex(_ index: Int) {
        guard index < mediaItems.count else { return }
        let mediaItem = mediaItems[index]
        
        // Enhanced haptic feedback for delete action
        HapticManager.shared.deleteConfirm()
        
        Task {
            do {
                // Delete from Firebase
                try await firebaseService.deleteMediaItem(mediaItem)
                
                // Update UI on main thread
                await MainActor.run {
                    mediaItems.remove(at: index)
                    // Success haptic feedback
                    HapticManager.shared.success()
                }
            } catch {
                print("❌ Error deleting memory at index \(index): \(error.localizedDescription)")
                // Error haptic feedback
                await MainActor.run {
                    HapticManager.shared.error()
                }
                // Could add an alert here for user feedback
            }
        }
    }
}

struct MediaItemCard: View {
    let item: MediaItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            onTap()
        }) {
            ZStack(alignment: .bottomLeading) {
                // Media content with fixed aspect ratio for compactness
                AsyncImage(url: URL(string: item.mediaURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill) // Fixed 16:9 aspect ratio
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL))
                
                // Compact overlays for text information
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.username)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // Delete button overlay
                        Button(action: {
                            HapticManager.shared.deleteConfirm()
                            onDelete()
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(.red.opacity(0.8), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Caption with line limit for compactness
                    if let caption = item.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    
                    // Single location tag (no duplicates)
                    if let location = item.location?.parkName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(12)
                .background {
                    // Gradient overlay for text readability
                    LinearGradient(
                        colors: [.black.opacity(0.7), .black.opacity(0.3), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL))
                
                // Firebase upload timestamp in top-right
                VStack {
                    HStack {
                        Spacer()
                        Text(formattedUploadTime())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                if #available(iOS 18.0, *) {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.8)
                                } else {
                                    Capsule()
                                        .fill(.black.opacity(0.4))
                                }
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL))
            .themeShadow(.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedUploadTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE HH:mm" // e.g., "Saturday 14:47"
        return formatter.string(from: item.createdAt)
    }
}

#Preview {
    AlbumView()
        .environmentObject(FirebaseService.shared)
}
