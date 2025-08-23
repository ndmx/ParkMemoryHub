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
            Text("Photo Library")
        }
        .sheet(isPresented: $showFilters) {
            Text("Camera Filters")
        }
    }
    
    private var cameraPreviewView: some View {
        CameraPreviewUIView(previewLayer: cameraManager.previewLayer)
            .ignoresSafeArea()
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
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedTimestamp())
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("Live")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(12)
        .background {
            if #available(iOS 18.0, *) {
                Theme.primaryMeshGradient
                    .opacity(0.7)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
            } else {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusM)
                    .fill(.ultraThinMaterial)
            }
        }
        .opacity(0.9)
    }
    
    private var locationStamp: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(.caption, design: .rounded))
            Text(location)
                .font(.system(.caption, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if #available(iOS 18.0, *) {
                Theme.accentMeshGradient
                    .opacity(0.6)
                    .clipShape(Capsule())
            } else {
                Capsule()
                    .fill(.regularMaterial)
            }
        }
        .opacity(0.8)
    }
    
    private var bottomCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                libraryButton
                depthButton
                autoModeButton
                effectsButton
                captureButton
            }
            .padding(.horizontal)
        }
        .scrollContentBackground(.hidden)
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.7)
                .scaleEffect(phase.isIdentity ? 1 : 0.95)
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
        }
    }
    
    private var captureButton: some View {
        Button(action: { 
            HapticManager.shared.cameraShutter()
            cameraManager.capturePhoto()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                Text("Capture")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 70, height: 60)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.red.gradient)
            }
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
    var previewLayer: AVCaptureVideoPreviewLayer?
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
        
        // Setup preview layer
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        
        captureSession = session
        previewLayer = preview
        
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
    
    func capturePhoto() {
        guard let output = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: PhotoCaptureDelegate())
    }
    
    func flipCamera() {
        // Implementation for camera flip
        // This would switch between front and back camera
    }
    
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        // Implementation for flash mode setting
    }
}

// MARK: - Camera Preview UIView
struct CameraPreviewUIView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        if let layer = previewLayer {
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = previewLayer {
            layer.frame = uiView.bounds
        }
    }
}

// MARK: - Photo Capture Delegate
class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Handle captured photo
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        // Process and save the image
    }
}

#Preview {
    InstantCameraView()
}
