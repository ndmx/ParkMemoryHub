import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins
import ARKit
import AVFoundation

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var caption = ""
    @State private var selectedFilter: FilterType = .none
    @State private var isProcessing = false
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var locationInfo: MediaItem.LocationInfo?
    @State private var overlayOffset: CGSize = .zero
    
    // iOS 18 Camera Enhancement States
    @State private var isDepthSensingEnabled = false
    @State private var depthData: AVDepthData?
    @State private var showFloatingToolbar = true
    @State private var cameraFlashMode: AVCaptureDevice.FlashMode = .auto
    
    enum FilterType: String, CaseIterable {
        case none = "None"
        case sepia = "Sepia"
        case mono = "Mono"
        case vibrant = "Vibrant"
        case noir = "Noir"
        // iOS 18 Enhanced Filters
        case dramatic = "Dramatic"
        case vivid = "Vivid"
        case brilliant = "Brilliant"
        case amusement = "Amusement"
        case bokeh = "Bokeh"
        case portrait = "Portrait"
        
        var filterName: String {
            switch self {
            case .none: return ""
            case .sepia: return "CISepiaTone"
            case .mono: return "CIPhotoEffectMono"
            case .vibrant: return "CIVibrance"
            case .noir: return "CIPhotoEffectNoir"
            // iOS 18 Enhanced CoreImage Filters
            case .dramatic: return "CIPhotoEffectProcess"
            case .vivid: return "CIColorControls"
            case .brilliant: return "CIExposureAdjust"
            case .amusement: return "CIColorPosterize"
            case .bokeh: return "CIMorphologyGradient"
            case .portrait: return "CIDepthBlurEffect"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "circle"
            case .sepia: return "sun.max"
            case .mono: return "circle.grid.2x2"
            case .vibrant: return "sparkles"
            case .noir: return "moon"
            case .dramatic: return "bolt.fill"
            case .vivid: return "paintbrush.pointed"
            case .brilliant: return "star.fill"
            case .amusement: return "party.popper"
            case .bokeh: return "camera.aperture"
            case .portrait: return "person.crop.circle"
            }
        }
        
        var isDepthRequired: Bool {
            switch self {
            case .bokeh, .portrait:
                return true
            default:
                return false
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Image Preview + movable caption overlay
                ZStack(alignment: .bottom) {
                    if let processedImage = processedImage {
                        Image(uiImage: processedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .cornerRadius(Theme.cornerRadiusL)
                            .themeShadow(.small)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusL)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 400)
                            .overlay(
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                    
                                    Text("Select or take a photo")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                    // Movable caption overlay (15px above bottom by default)
                    if !caption.isEmpty {
                        Text(caption)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.5))
                            )
                            .offset(overlayOffset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        overlayOffset = value.translation.applying(.init(translationX: 0, y: -15))
                                    }
                            )
                            .padding(.bottom, 15)
                    }
                }
                
                // Enhanced Capture Buttons with iOS 18 Styling
                if selectedImage == nil {
                    VStack(spacing: 16) {
                        // Floating Toolbar for Camera Options
                        if showFloatingToolbar, #available(iOS 18.0, *) {
                            HStack(spacing: 12) {
                                Button(action: { toggleDepthSensing() }) {
                                    Label(isDepthSensingEnabled ? "Depth On" : "Depth Off", 
                                          systemImage: isDepthSensingEnabled ? "eye.fill" : "eye.slash")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                Button(action: { toggleFlashMode() }) {
                                    Label(flashModeText, systemImage: flashModeIcon)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                Button(action: { showFloatingToolbar.toggle() }) {
                                    Image(systemName: "chevron.up")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .shadow(radius: 4)
                        }
                        
                        // Main Capture Buttons
                        HStack(spacing: 20) {
                            Button(action: { 
                                triggerHapticFeedback()
                                showCamera = true 
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Camera")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background {
                                    if #available(iOS 18.0, *) {
                                        Theme.accentMeshGradient
                                    } else {
                                        Color.blue
                                    }
                                }
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                                .themeShadow(.medium)
                            }
                            
                            Button(action: { 
                                triggerHapticFeedback()
                                showImagePicker = true 
                            }) {
                                HStack {
                                    Image(systemName: "photo.fill")
                                    Text("Library")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background {
                                    if #available(iOS 18.0, *) {
                                        Theme.primaryMeshGradient
                                    } else {
                                        Color.green
                                    }
                                }
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                                .themeShadow(.medium)
                            }
                        }
                    }
                }
                
                // Enhanced Filter Selection with iOS 18 Styling
                if selectedImage != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Filters")
                                .font(.headline)
                            
                            Spacer()
                            
                            if selectedFilter.isDepthRequired {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.fill")
                                        .foregroundColor(isDepthSensingEnabled ? .green : .orange)
                                    Text(isDepthSensingEnabled ? "Depth On" : "Depth Off")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(FilterType.allCases, id: \.self) { filter in
                                    Button(action: { 
                                        applyFilter(filter)
                                        HapticManager.shared.lightTap()
                                    }) {
                                        VStack(spacing: 8) {
                                            // Filter Icon
                                            Image(systemName: filter.icon)
                                                .font(.title2)
                                                .foregroundColor(selectedFilter == filter ? .white : Theme.primaryColor)
                                                .frame(width: 44, height: 44)
                                                .background {
                                                    if selectedFilter == filter {
                                                        if #available(iOS 18.0, *) {
                                                            Theme.accentMeshGradient
                                                                .clipShape(Circle())
                                                        } else {
                                                            Circle()
                                                                .fill(Theme.primaryColor)
                                                        }
                                                    } else {
                                                        Circle()
                                                            .fill(Theme.backgroundSecondary)
                                                            .stroke(Theme.primaryColor.opacity(0.3), lineWidth: 1)
                                                    }
                                                }
                                            
                                            // Filter Name
                                            Text(filter.rawValue)
                                                .font(.caption)
                                                .foregroundColor(selectedFilter == filter ? Theme.primaryColor : .secondary)
                                                .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                        }
                                        .scaleEffect(selectedFilter == filter ? 1.05 : 1.0)
                                        .animation(Theme.springAnimation, value: selectedFilter)
                                    }
                                    .disabled(filter.isDepthRequired && !isDepthSensingEnabled)
                                    .opacity(filter.isDepthRequired && !isDepthSensingEnabled ? 0.5 : 1.0)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
                
                // Enhanced Caption Input with iOS 18.5 Features
                if selectedImage != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Caption")
                                .font(.headline)
                            
                            Spacer()
                            
                            // iOS 18.5 Emoji Toolbar
                            if #available(iOS 18.0, *) {
                                HStack(spacing: 8) {
                                    ForEach(["😍", "🎢", "🎠", "🎡", "🎪", "🌟"], id: \.self) { emoji in
                                        Button(action: {
                                            caption += emoji
                                            triggerHapticFeedback()
                                        }) {
                                            Text(emoji)
                                                .font(.title2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: Capsule())
                            }
                        }
                        .padding(.horizontal)
                        
                        // Enhanced Text Field with Dynamic Sizing
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Share your park memories...", text: $caption, axis: .vertical)
                                .textFieldStyle(.plain)
                                .themedFormFieldBackground(cornerRadius: Theme.cornerRadiusL)
                                .lineLimit(2...8)
                                .font(.body)
                                .animation(Theme.animationFast, value: caption.count)
                                .padding(.horizontal)
                            
                            // Character Count and Suggestions
                            HStack {
                                if #available(iOS 18.0, *) {
                                    Text("💭 Suggested: #memories #\(locationInfo?.parkName?.replacingOccurrences(of: " ", with: "").lowercased() ?? "themepark")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .onTapGesture {
                                            caption += " #memories"
                                            if let park = locationInfo?.parkName?.replacingOccurrences(of: " ", with: "").lowercased() {
                                                caption += " #\(park)"
                                            }
                                            triggerHapticFeedback()
                                        }
                                }
                                
                                Spacer()
                                
                                Text("\(caption.count)/280")
                                    .font(.caption)
                                    .foregroundColor(caption.count > 280 ? .red : .secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Location Info
                if let locationInfo = locationInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                if let parkName = locationInfo.parkName {
                                    Text(parkName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                if let rideName = locationInfo.rideName {
                                    Text(rideName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Upload Button
                if selectedImage != nil {
                    Button(action: uploadImage) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "icloud.and.arrow.up.fill")
                                Text("Share Memory")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .primaryActionBackground()
                        .padding(.horizontal)
                    }
                    .disabled(isProcessing)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Capture Memory")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
                .zoomTransition()
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(Theme.cornerRadiusL)
        }
        .sheet(isPresented: $showCamera) {
            CameraView(selectedImage: $selectedImage)
                .zoomTransition()
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(Theme.cornerRadiusL)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                processedImage = image.orientationFixed()
                selectedFilter = .none
                // Reset movable caption overlay to default (15px above bottom)
                overlayOffset = .zero
            }
        }
        .alert("Upload Result", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .task {
            // Load location info asynchronously
            locationInfo = await locationManager.getLocationInfo()
        }
    }
    
    private func applyFilter(_ filter: FilterType) {
        guard let image = selectedImage else { return }
        selectedFilter = filter
        
        if filter == .none {
            processedImage = image
            return
        }
        
        guard let ciImage = CIImage(image: image.orientationFixed()) else { return }
        let context = CIContext()
        
        var outputImage = ciImage
        
        switch filter {
        case .sepia:
            let sepiaFilter = CIFilter.sepiaTone()
            sepiaFilter.inputImage = ciImage
            sepiaFilter.intensity = 0.8
            outputImage = sepiaFilter.outputImage ?? ciImage
            
        case .mono:
            let monoFilter = CIFilter.photoEffectMono()
            monoFilter.inputImage = ciImage
            outputImage = monoFilter.outputImage ?? ciImage
            
        case .vibrant:
            let vibrantFilter = CIFilter.vibrance()
            vibrantFilter.inputImage = ciImage
            vibrantFilter.amount = 1.0
            outputImage = vibrantFilter.outputImage ?? ciImage
            
        case .noir:
            let noirFilter = CIFilter.photoEffectNoir()
            noirFilter.inputImage = ciImage
            outputImage = noirFilter.outputImage ?? ciImage
            
        // iOS 18 Enhanced Filters
        case .dramatic:
            let dramaticFilter = CIFilter.photoEffectProcess()
            dramaticFilter.inputImage = ciImage
            outputImage = dramaticFilter.outputImage ?? ciImage
            
        case .vivid:
            let vividFilter = CIFilter.colorControls()
            vividFilter.inputImage = ciImage
            vividFilter.saturation = 1.5
            vividFilter.brightness = 0.1
            vividFilter.contrast = 1.2
            outputImage = vividFilter.outputImage ?? ciImage
            
        case .brilliant:
            let brilliantFilter = CIFilter.exposureAdjust()
            brilliantFilter.inputImage = ciImage
            brilliantFilter.ev = 0.7
            outputImage = brilliantFilter.outputImage ?? ciImage
            
        case .amusement:
            let amusementFilter = CIFilter.colorPosterize()
            amusementFilter.inputImage = ciImage
            amusementFilter.levels = 6
            outputImage = amusementFilter.outputImage ?? ciImage
            
        case .bokeh:
            if isDepthSensingEnabled, #available(iOS 18.0, *) {
                let bokehFilter = CIFilter.morphologyGradient()
                bokehFilter.inputImage = ciImage
                bokehFilter.radius = 5
                outputImage = bokehFilter.outputImage ?? ciImage
            } else {
                // Fallback bokeh effect without depth data
                let blurFilter = CIFilter.gaussianBlur()
                blurFilter.inputImage = ciImage
                blurFilter.radius = 3
                outputImage = blurFilter.outputImage ?? ciImage
            }
            
        case .portrait:
            if isDepthSensingEnabled, #available(iOS 18.0, *) {
                // Advanced portrait mode with depth sensing
                // Using gaussian blur with masking for portrait effect since depthBlurEffect isn't available
                let portraitFilter = CIFilter.maskedVariableBlur()
                portraitFilter.inputImage = ciImage
                portraitFilter.radius = 8
                outputImage = portraitFilter.outputImage ?? ciImage
            } else {
                // Fallback portrait effect
                let portraitFilter = CIFilter.gaussianBlur()
                portraitFilter.inputImage = ciImage
                portraitFilter.radius = 2
                outputImage = portraitFilter.outputImage ?? ciImage
            }
            
        case .none:
            break
        }
        
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            processedImage = UIImage(cgImage: cgImage).orientationFixed()
        }
    }
    
    private func uploadImage() {
        guard let image = processedImage,
              let user = firebaseService.currentUser else { return }
        
        isProcessing = true
        
        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
                }
                
                let locationInfo = await locationManager.getLocationInfo()
                let tags = locationInfo?.parkName.map { [$0] } ?? []
                
                // Get user's actual username from profile
                let userProfile = try await firebaseService.getUserProfile(userId: user.uid)
                let username = userProfile?.username ?? user.email ?? "Unknown"
                
                _ = try await firebaseService.uploadMedia(
                    imageData,
                    userId: user.uid,
                    username: username,
                    caption: caption.isEmpty ? nil : caption,
                    location: locationInfo,
                    tags: tags,
                    appliedFilter: selectedFilter.rawValue,
                    frameTheme: locationInfo?.parkName
                )
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.alertMessage = "Memory shared successfully!"
                    self.showAlert = true
                    
                    // Celebrate successful share with haptic feedback
                    HapticManager.shared.shareSuccess()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.dismiss()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.alertMessage = "Failed to upload: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - iOS 18 Camera Enhancement Functions
    
    private func toggleDepthSensing() {
        triggerHapticFeedback()
        isDepthSensingEnabled.toggle()
    }
    
    private func toggleFlashMode() {
        triggerHapticFeedback()
        switch cameraFlashMode {
        case .auto:
            cameraFlashMode = .on
        case .on:
            cameraFlashMode = .off
        case .off:
            cameraFlashMode = .auto
        @unknown default:
            cameraFlashMode = .auto
        }
    }
    
    private var flashModeText: String {
        switch cameraFlashMode {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        @unknown default: return "Auto"
        }
    }
    
    private var flashModeIcon: String {
        switch cameraFlashMode {
        case .auto: return "bolt.badge.automatic"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        @unknown default: return "bolt.badge.automatic"
        }
    }
    
    private func triggerHapticFeedback() {
        HapticManager.shared.lightTap()
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - UIImage Orientation Helper
fileprivate extension UIImage {
    func orientationFixed() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}

#Preview {
    CaptureView()
}
