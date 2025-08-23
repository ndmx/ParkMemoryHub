import SwiftUI

struct AlbumView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var mediaItems: [MediaItem] = []
    @State private var isLoading = false
    @State private var showCaptureView = false
    @State private var selectedMediaItem: MediaItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Family Memories")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showCaptureView = true }) {
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
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(mediaItems) { item in
                            MediaItemCard(item: item) {
                                selectedMediaItem = item
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteMemory(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
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
}

struct MediaItemCard: View {
    let item: MediaItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Media content
                AsyncImage(url: URL(string: item.mediaURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
                
                // Item details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.username)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(item.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let caption = item.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    if let location = item.location?.parkName {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !item.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(item.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AlbumView()
        .environmentObject(FirebaseService.shared)
}
