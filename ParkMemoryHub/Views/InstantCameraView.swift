import SwiftUI
import AVFoundation
import CoreLocation

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
            PhotoPickerView()
        }
        .sheet(isPresented: $showFilters) {
            Text("Camera Filters")
        }
    }
    
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
            Task {
                await cameraManager.setupCamera()
                await fetchCurrentLocation()
            }
        }
    }
    
    private var overlayContent: some View {
        VStack {
            Spacer()
            overlayStamps
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
        .padding(.bottom, 140)
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
            // Main capture button centered
            captureButton
            
            // Other options in horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    libraryButton
                    depthButton
                    autoModeButton
                    effectsButton
                }
                .padding(.horizontal)
            }
            .scrollContentBackground(.hidden)
            .scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.7)
                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
            }
        }
        .padding(.bottom, 40)
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
    
    private var autoModeButton: some View {
        Button(action: { 
            HapticManager.shared.lightTap()
            isAutoMode.toggle() 
        }) {
            VStack(spacing: 4) {
                Image(systemName: isAutoMode ? "bolt.circle.fill" : "bolt.circle")
                    .font(.title2)
                Text("Auto")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 70, height: 60)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill((isAutoMode ? Color.orange : Color.gray).gradient)
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
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                Text("Effects")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 70, height: 60)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.indigo.gradient)
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
            Image(systemName: "xmark")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
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
                .background(.ultraThinMaterial, in: Circle())
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
                .background(.ultraThinMaterial, in: Circle())
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
    
    func setupCamera() async {
        guard await requestCameraPermission() else { return }
        
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        // Add video input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: camera) else { return }
        
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
        
        // Setup preview layer on main thread
        await MainActor.run {
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            
            self.captureSession = session
            self.previewLayer = preview
        }
        
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
        
        let delegate = PhotoCaptureDelegate()
        output.capturePhoto(with: settings, delegate: delegate)
    }
    
    func flipCamera() {
        guard let session = captureSession else { return }
        
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
                    currentCamera = newCamera
                    print("📷 Camera flipped to \(newPosition == .front ? "front" : "back")")
                }
            }
        }
        
        session.commitConfiguration()
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
        DispatchQueue.main.async {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            print("📱 Photo saved to library")
        }
    }
}

// MARK: - Photo Picker View
struct PhotoPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
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
                print("📷 Photo selected from library")
                HapticManager.shared.success()
                // Handle the selected image here
                // You could save it or process it as needed
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    InstantCameraView()
}
