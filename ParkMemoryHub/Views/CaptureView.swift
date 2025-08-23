import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

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
    
    enum FilterType: String, CaseIterable {
        case none = "None"
        case sepia = "Sepia"
        case mono = "Mono"
        case vibrant = "Vibrant"
        case noir = "Noir"
        
        var filterName: String {
            switch self {
            case .none: return ""
            case .sepia: return "CISepiaTone"
            case .mono: return "CIPhotoEffectMono"
            case .vibrant: return "CIVibrance"
            case .noir: return "CIPhotoEffectNoir"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Image Preview
                if let processedImage = processedImage {
                    Image(uiImage: processedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    RoundedRectangle(cornerRadius: 12)
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
                
                // Capture Buttons
                if selectedImage == nil {
                    HStack(spacing: 20) {
                        Button(action: { showCamera = true }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Camera")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: { showImagePicker = true }) {
                            HStack {
                                Image(systemName: "photo.fill")
                                Text("Library")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                
                // Filter Selection
                if selectedImage != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filters")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(FilterType.allCases, id: \.self) { filter in
                                    Button(action: { applyFilter(filter) }) {
                                        Text(filter.rawValue)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Caption Input
                if selectedImage != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Caption")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextField("Add a caption...", text: $caption, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3)
                            .padding(.horizontal)
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
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
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
        }
        .sheet(isPresented: $showCamera) {
            CameraView(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                processedImage = image
                selectedFilter = .none
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
        
        guard let ciImage = CIImage(image: image) else { return }
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
            
        case .none:
            break
        }
        
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            processedImage = UIImage(cgImage: cgImage)
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

#Preview {
    CaptureView()
}
