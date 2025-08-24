import SwiftUI
import AVFoundation
import CoreLocation

enum CameraFilter: String, CaseIterable {
    case none = "None"
    case vivid = "Vivid"
    case dramatic = "Dramatic"
    case brilliant = "Brilliant"
    case mono = "Mono"
    case noir = "Noir"
    case vintage = "Vintage"
    case chrome = "Chrome"
    case fade = "Fade"
    case instant = "Instant"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .none: return "camera"
        case .vivid: return "sun.max.fill"
        case .dramatic: return "bolt.fill"
        case .brilliant: return "sparkles"
        case .mono: return "circle.lefthalf.filled"
        case .noir: return "moon.fill"
        case .vintage: return "camera.vintage"
        case .chrome: return "metallurgy"
        case .fade: return "cloud.fill"
        case .instant: return "camera.aperture"
        }
    }
}

struct InstantCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var locationManager = LocationManager.shared
    @State private var location: String = "Fetching location..."
    @State private var isDepthEnabled = false
    @State private var isAutoMode = true
    @State private var flashMode: AVCaptureDevice.FlashMode = .auto
    @State private var showFilters = false
    @State private var showLibrary = false
    @State private var capturedImage: UIImage?
    @State private var showCapturedImageView = false

    @State private var currentUsername = "Loading..."
    @State private var textPosition: CGSize = .zero
    @State private var selectedFilter: CameraFilter = .none
    

    
    var body: some View {
        NavigationStack {
            ZStack {
                cameraPreviewView
                overlayContent
                

            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    cameraControls
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .zoomTransition()
        .animation(.snappy(duration: 0.3), value: isDepthEnabled)
        .animation(.snappy(duration: 0.3), value: isAutoMode)
        .sheet(isPresented: $showLibrary) {
            PhotoPickerView { selectedImage in
                handleCapturedPhoto(selectedImage)
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSelectionView(selectedFilter: $selectedFilter) {
                showFilters = false
            }
        }
        .sheet(isPresented: $showCapturedImageView) {
            if let image = capturedImage {
                CapturedImageUploadView(image: image, username: currentUsername) {
                    showCapturedImageView = false
                    capturedImage = nil
                }
            }
        }
    }
    
    private func handleCapturedPhoto(_ image: UIImage) {
        print("🖼️ Image captured, size: \(image.size)")
        capturedImage = image
        
        // Always show preview - let user decide what to do
        DispatchQueue.main.async {
            self.showCapturedImageView = true
        }
    }
    

    

    
    private func fetchCurrentUsername() async {
        guard let userId = FirebaseService.shared.currentUser?.uid else { return }
        
        do {
            if let userProfile = try await FirebaseService.shared.getUserProfile(userId: userId) {
                await MainActor.run {
                    currentUsername = userProfile.username
                }
            }
        } catch {
            print("❌ Failed to fetch username: \(error)")
            await MainActor.run {
                currentUsername = "Anonymous"
            }
        }
    }
}



extension InstantCameraView {
    private var cameraPreviewView: some View {
        Group {
            if let previewLayer = cameraManager.previewLayer {
                CameraPreviewUIView(previewLayer: previewLayer)
                    .ignoresSafeArea()
            } else {
                // Loading state while camera initializes
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView("Starting Camera...")
                            .foregroundStyle(.white)
                    )
            }
        }
                    .onAppear {
                // Set up camera manager callback
                cameraManager.onPhotoCaptured = { image in
                    self.handleCapturedPhoto(image)
                }
                Task {
                    // Run camera setup on background queue for best performance
                    await Task.detached(priority: .userInitiated) {
                        await cameraManager.setupCamera()
                    }.value
                    
                    await fetchCurrentLocation()
                    await fetchCurrentUsername()
                }
            }
    }
    
    private var overlayContent: some View {
        VStack {
            Spacer()
            
            // Text overlays positioned higher up
            overlayStamps
                .padding(.bottom, 200)
            
            Spacer()
            
            // Tabs always at the bottom
            bottomCarousel
        }
    }
    
    private var overlayStamps: some View {
        HStack {
            timestampStamp
            Spacer()
            locationStamp
        }
        .padding(.horizontal)
        .offset(textPosition)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    textPosition = gesture.translation
                }
        )
    }
    
    private var timestampStamp: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formattedTimestamp())
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
            
            Text("Live")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0.5)
        }
    }
    
    private var locationStamp: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(.caption, design: .rounded))
            Text(location)
                .font(.system(.caption, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0.5)
    }
    
    private var bottomCarousel: some View {
        VStack(spacing: 20) {
            // Main circular capture button
            captureButton
            
            // Other tabs in horizontal row at the very bottom
            HStack(spacing: 12) {
                libraryButton
                depthButton
                previewModeButton
                effectsButton
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 30) // Stick to bottom with safe area
    }
    
    private var libraryButton: some View {
        Button(action: { 
            HapticManager.shared.lightTap()
            showLibrary = true 
        }) {
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                Text("Library")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 70, height: 60)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.gradient)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var depthButton: some View {
        Button(action: { 
            HapticManager.shared.lightTap()
            isDepthEnabled.toggle() 
        }) {
            VStack(spacing: 4) {
                Image(systemName: isDepthEnabled ? "eye.fill" : "eye.slash")
                    .font(.title2)
                Text("Depth")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 70, height: 60)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill((isDepthEnabled ? Color.green : Color.purple).gradient)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var previewModeButton: some View {
        Button(action: { 
            HapticManager.shared.lightTap()
            // Always use preview mode now
        }) {
            VStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.title2)
                Text("Preview")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 70, height: 60)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.gradient)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var effectsButton: some View {
        Button(action: { 
            HapticManager.shared.lightTap()
            showFilters = true 
        }) {
            VStack(spacing: 4) {
                Image(systemName: selectedFilter.icon)
                    .font(.title2)
                Text(selectedFilter == .none ? "Effects" : selectedFilter.displayName)
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 70, height: 60)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill((selectedFilter == .none ? Color.indigo : Color.blue).gradient)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var captureButton: some View {
        Button(action: {
            HapticManager.shared.cameraShutter()
            Task {
                await cameraManager.capturePhoto()
            }
        }) {
            Circle()
                .stroke(.white, lineWidth: 4)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(.clear)
                        .frame(width: 72, height: 72)
                )
        }
    }
    
    private var closeButton: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            dismiss()
        }) {
            Text("Cancel")
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
    }
    
    private var cameraControls: some View {
        HStack(spacing: 12) {
            flashButton
            flipButton
        }
    }
    
    private var flashButton: some View {
        Button(action: { 
            HapticManager.shared.lightTap()
            toggleFlashMode() 
        }) {
            Image(systemName: flashModeIcon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
        }
    }
    
    private var flipButton: some View {
        Button(action: { 
            HapticManager.shared.lightTap()
            cameraManager.flipCamera() 
        }) {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
        }
    }
    
    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE HH:mm"
        return formatter.string(from: Date())
    }
    
    private func fetchCurrentLocation() async {
        await MainActor.run {
            if let currentLocation = locationManager.currentLocation {
                let geocoder = CLGeocoder()
                Task {
                    do {
                        let placemarks = try await geocoder.reverseGeocodeLocation(currentLocation)
                        await MainActor.run {
                            self.location = placemarks.first?.name ?? "Unknown Location"
                        }
                    } catch {
                        await MainActor.run {
                            self.location = "Location Unavailable"
                        }
                    }
                }
            } else {
                self.location = "No Location"
            }
        }
    }
    
    private func toggleFlashMode() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        @unknown default:
            flashMode = .auto
        }
        cameraManager.setFlashMode(flashMode)
    }
    
    private var flashModeIcon: String {
        switch flashMode {
        case .auto: return "bolt.badge.automatic"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        @unknown default: return "bolt.badge.automatic"
        }
    }
}

// MARK: - Camera Manager
@MainActor
class CameraManager: ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentCamera: AVCaptureDevice?
    var onPhotoCaptured: ((UIImage) -> Void)?
    
    func setupCamera() async {
        guard await requestCameraPermission() else { return }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        session.sessionPreset = .photo
        
        // Add video input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: camera) else { 
            session.commitConfiguration()
            return 
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            currentCamera = camera
        }
        
        // Add photo output
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
        }
        
        session.commitConfiguration()
        
        // Setup preview layer on main thread
        await MainActor.run {
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            
            self.captureSession = session
            self.previewLayer = preview
        }
        
        // Start capture session (already on background thread)
        session.startRunning()
    }
    
    private func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            switch status {
            case .authorized:
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            default:
                continuation.resume(returning: false)
            }
        }
    }
    
    func capturePhoto() async {
        guard let output = photoOutput else { 
            print("❌ No photo output available")
            return 
        }
        
        print("📸 Capturing photo...")
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        let delegate = PhotoCaptureDelegate { image in
            await MainActor.run {
                self.onPhotoCaptured?(image)
            }
        }
        output.capturePhoto(with: settings, delegate: delegate)
    }
    
    func flipCamera() {
        guard let session = captureSession else { return }
        
        // Perform camera reconfiguration on background queue for better performance
        Task.detached(priority: .userInitiated) {
            session.beginConfiguration()
            
            // Remove current input
            if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
                session.removeInput(currentInput)
                
                // Switch camera position
                let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
                
                // Get new camera
                if let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                   let newInput = try? AVCaptureDeviceInput(device: newCamera) {
                    
                    if session.canAddInput(newInput) {
                        session.addInput(newInput)
                        await MainActor.run {
                            self.currentCamera = newCamera
                        }
                        print("📷 Camera flipped to \(newPosition == .front ? "front" : "back")")
                    }
                }
            }
            
            session.commitConfiguration()
        }
    }
    
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        // Implementation for flash mode setting
    }
}

// MARK: - Camera Preview UIView
struct CameraPreviewUIView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Photo Capture Delegate
class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let onPhotoCapture: (UIImage) async -> Void
    
    init(onPhotoCapture: @escaping (UIImage) async -> Void) {
        self.onPhotoCapture = onPhotoCapture
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Handle captured photo
        if let error = error {
            print("❌ Error capturing photo: \(error)")
            HapticManager.shared.error()
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: imageData) else { 
            print("❌ Failed to create image from captured data")
            HapticManager.shared.error()
            return 
        }
        
        print("✅ Photo captured successfully")
        HapticManager.shared.success()
        
        // Save to photo library
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        print("📱 Photo saved to library")
        
        // Pass image to callback for upload interface
        Task {
            await onPhotoCapture(uiImage)
        }
    }
}

// MARK: - Photo Picker View
struct PhotoPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImageSelected: (UIImage) -> Void
    
    init(onImageSelected: @escaping (UIImage) -> Void = { _ in }) {
        self.onImageSelected = onImageSelected
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                print("📷 Photo selected from library: \(image.size)")
                HapticManager.shared.success()
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Captured Image Upload View
struct CapturedImageUploadView: View {
    let image: UIImage
    let username: String
    let onDismiss: () -> Void
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var caption = ""
    @State private var isUploading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Captured photo
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Caption input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a caption")
                        .font(.headline)
                    
                    TextField("What's happening?", text: $caption, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Upload button
                Button(action: uploadPhoto) {
                    if isUploading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Uploading...")
                        }
                    } else {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("Share to Family")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isUploading)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Share Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .alert("Photo Upload", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    onDismiss()
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func uploadPhoto() {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isUploading = true
        HapticManager.shared.lightTap()
        
        Task {
            do {
                // Upload image to Firebase Storage
                let uploadResult = try await firebaseService.uploadMedia(
                    imageData,
                    userId: firebaseService.currentUser?.uid ?? "",
                    username: username,
                    caption: caption.isEmpty ? nil : caption,
                    location: nil,
                    tags: [],
                    appliedFilter: nil,
                    frameTheme: nil
                )
                
                await MainActor.run {
                    isUploading = false
                    alertMessage = "Photo uploaded successfully!"
                    showAlert = true
                    HapticManager.shared.success()
                    print("✅ Photo uploaded successfully with ID: \(uploadResult)")
                }
                
            } catch {
                await MainActor.run {
                    isUploading = false
                    alertMessage = "Failed to upload photo: \(error.localizedDescription)"
                    showAlert = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - Filter Selection View
struct FilterSelectionView: View {
    @Binding var selectedFilter: CameraFilter
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    Text("Camera Filters")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundStyle(.blue)
                }
                .padding()
                
                Divider()
                
                // Filter Grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(CameraFilter.allCases, id: \.self) { filter in
                            FilterCard(
                                filter: filter,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                                HapticManager.shared.lightTap()
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Filter Card
struct FilterCard: View {
    let filter: CameraFilter
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Filter Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                        .frame(height: 80)
                    
                    Image(systemName: filter.icon)
                        .font(.title)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                
                // Filter Name
                Text(filter.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .blue : .primary)
                    .fontWeight(isSelected ? .medium : .regular)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InstantCameraView()
}
