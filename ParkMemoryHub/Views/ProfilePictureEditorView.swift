import SwiftUI
import UIKit
import Vision
import CoreImage.CIFilterBuiltins
import FirebaseStorage

struct ProfilePictureEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var selectedImage: UIImage?
    @State private var croppedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var cropRect: CGRect = .zero
    @State private var faceDetected = false
    
    let userProfile: UserProfile?
    let onProfileUpdated: (UserProfile) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                Text("Set Profile Picture")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Current/Preview Image
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 200)
                    
                    if let croppedImage = croppedImage {
                        Image(uiImage: croppedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                            )
                    } else {
                        VStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.gray)
                            Text("No Photo")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onTapGesture {
                    showImagePicker = true
                }
                
                // Instructions
                if selectedImage != nil && !faceDetected {
                    Text("Face detection in progress...")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                } else if faceDetected {
                    Text("✅ Face detected and cropped!")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    Text("Tap the circle above to take or select a photo")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: { showImagePicker = true }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Take New Photo")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    if croppedImage != nil {
                        Button(action: saveProfilePicture) {
                            if isProcessing {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("Saving...")
                                }
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Profile Picture")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(croppedImage != nil ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isProcessing || croppedImage == nil)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ProfileImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                processImageForFaceDetection(image)
            }
        }
        .alert("Profile Picture", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func processImageForFaceDetection(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNDetectFaceRectanglesRequest { request, _ in
            guard let results = request.results as? [VNFaceObservation],
                  let firstFace = results.first else {
                DispatchQueue.main.async {
                    // No face detected, use center crop
                    self.croppedImage = self.centerCropToSquare(image)
                    self.faceDetected = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.croppedImage = self.cropToFace(image, faceObservation: firstFace)
                self.faceDetected = true
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    private func cropToFace(_ image: UIImage, faceObservation: VNFaceObservation) -> UIImage {
        let imageSize = image.size
        let faceRect = faceObservation.boundingBox
        
        // Convert normalized coordinates to image coordinates
        let faceX = faceRect.origin.x * imageSize.width
        let faceY = (1 - faceRect.origin.y - faceRect.height) * imageSize.height
        let width = faceRect.width * imageSize.width
        let height = faceRect.height * imageSize.height
        
        // Expand the crop area to include more context
        let expandedSize = max(width, height) * 1.5
        let expandedX = faceX + width/2 - expandedSize/2
        let expandedY = faceY + height/2 - expandedSize/2
        
        let cropRect = CGRect(
            x: max(0, expandedX),
            y: max(0, expandedY),
            width: min(expandedSize, imageSize.width - max(0, expandedX)),
            height: min(expandedSize, imageSize.height - max(0, expandedY))
        )
        
        return cropImage(image, to: cropRect) ?? centerCropToSquare(image)
    }
    
    private func centerCropToSquare(_ image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let centerX = (image.size.width - size) / 2
        let centerY = (image.size.height - size) / 2
        let cropRect = CGRect(x: centerX, y: centerY, width: size, height: size)
        
        return cropImage(image, to: cropRect) ?? image
    }
    
    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private func resizeImageForAvatar(_ image: UIImage) -> UIImage {
        let targetSize = CGSize(width: 300, height: 300) // Standard avatar size
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    private func saveProfilePicture() {
        guard let image = croppedImage,
              let user = firebaseService.currentUser else { return }
        
        // Resize image to standard avatar size before uploading
        let resizedImage = resizeImageForAvatar(image)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else { return }
        
        isProcessing = true
        
        Task {
            do {
                // Upload to Firebase Storage
                let filename = "profile_\(user.uid)_\(UUID().uuidString).jpg"
                let storageRef = Storage.storage().reference().child("profiles/\(filename)")
                
                print("🔄 Uploading profile picture to: profiles/\(filename)")
                print("📤 User ID: \(user.uid)")
                print("📦 Image data size: \(imageData.count) bytes")
                
                _ = try await storageRef.putDataAsync(imageData)
                print("✅ Profile picture uploaded successfully")
                
                let downloadURL = try await storageRef.downloadURL()
                print("🔗 Download URL: \(downloadURL.absoluteString)")
                
                // Update user profile with new avatar URL
                try await firebaseService.updateUserProfile(userId: user.uid, updates: [
                    "avatarURL": downloadURL.absoluteString
                ])
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.alertMessage = "Profile picture saved successfully!"
                    self.showAlert = true
                    
                    // Create updated user profile with new avatar URL
                    if var updatedProfile = self.userProfile {
                        updatedProfile.avatarURL = downloadURL.absoluteString
                        self.onProfileUpdated(updatedProfile)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.dismiss()
                    }
                }
            } catch {
                print("❌ Profile picture upload failed: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.alertMessage = "Failed to save profile picture: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
}

struct ProfileImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ProfileImagePicker
        
        init(_ parent: ProfileImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ProfilePictureEditorView(userProfile: nil) { _ in }
}
