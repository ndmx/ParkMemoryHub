import SwiftUI
import RealityKit
import ARKit

struct ARRadarView: View {
    let familyMembers: [UserProfile]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMember: UserProfile?
    @State private var arSupported = ARWorldTrackingConfiguration.isSupported

    var body: some View {
        NavigationStack {
            ZStack {
                if arSupported {
                    ARViewContainer(familyMembers: familyMembers, selectedMember: $selectedMember)
                        .ignoresSafeArea()
                } else {
                    // Fallback view for unsupported devices
                    VStack(spacing: Theme.spacingL) {
                        Image(systemName: "arkit.slash")
                            .font(.system(size: 80))
                            .foregroundColor(Theme.textSecondary)

                        Text("AR Not Supported")
                            .font(Theme.headlineFont)

                        Text("Your device doesn't support AR features. The standard radar view is still available.")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.spacingL)

                        Button("Continue with Standard View") {
                            dismiss()
                        }
                        .font(Theme.bodyFont)
                        .foregroundColor(.white)
                        .padding(Theme.spacingM)
                        .background(Theme.primaryColor)
                        .cornerRadius(Theme.cornerRadiusM)
                    }
                    .padding(Theme.spacingL)
                }

                // Overlay UI (only show when AR is supported)
                if arSupported {
                    VStack {
                        // Header
                        HStack {
                            Text("AR Family Radar")
                                .font(Theme.headlineFont)
                                .foregroundColor(.white)
                                .padding(Theme.spacingM)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(Theme.cornerRadiusM)

                            Spacer()

                            Button("Exit AR") {
                                dismiss()
                            }
                            .font(Theme.bodyFont)
                            .foregroundColor(.white)
                            .padding(Theme.spacingM)
                            .background(Theme.accentColor)
                            .cornerRadius(Theme.cornerRadiusM)
                        }
                        .padding(Theme.spacingM)

                        Spacer()

                        // Family member list
                        if !familyMembers.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.spacingM) {
                                    ForEach(familyMembers) { member in
                                        ARMemberCard(
                                            member: member,
                                            isSelected: selectedMember?.id == member.id
                                        ) {
                                            selectedMember = member
                                        }
                                    }
                                }
                                .padding(.horizontal, Theme.spacingM)
                            }
                            .padding(.vertical, Theme.spacingM)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(Theme.cornerRadiusL)
                            .padding(.horizontal, Theme.spacingM)
                            .padding(.bottom, Theme.spacingL)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ARViewContainer: UIViewRepresentable {
    let familyMembers: [UserProfile]
    @Binding var selectedMember: UserProfile?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: true)

        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)

        // Add family member anchors
        addFamilyMemberAnchors(to: arView)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update anchors when family members change
        updateFamilyMemberAnchors(in: uiView)
    }

    private func addFamilyMemberAnchors(to arView: ARView) {
        for (index, member) in familyMembers.enumerated() {
            let anchor = ARAnchor(name: member.id, transform: generateMemberTransform(at: index))
            arView.session.add(anchor: anchor)

            // Add visual representation
            let entity = createMemberEntity(for: member)
            let anchorEntity = AnchorEntity(.anchor(identifier: anchor.identifier))
            anchorEntity.addChild(entity)
            arView.scene.addAnchor(anchorEntity)
        }
    }

    private func updateFamilyMemberAnchors(in arView: ARView) {
        // Remove existing anchors
        arView.scene.anchors.removeAll()

        // Add updated anchors
        addFamilyMemberAnchors(to: arView)
    }

    private func generateMemberTransform(at index: Int) -> simd_float4x4 {
        // Generate positions in a circle around the user
        let radius: Float = 2.0
        let angle = Float(index) * (2.0 * .pi / Float(familyMembers.count))
        let xPosition = radius * cos(angle)
        let zPosition = radius * sin(angle)

        var transform = matrix_identity_float4x4
        transform.columns.3.x = xPosition
        transform.columns.3.z = zPosition
        transform.columns.3.y = 0.5 // Slightly above ground

        return transform
    }

    private func createMemberEntity(for member: UserProfile) -> Entity {
        let entity = Entity()

        // Create avatar sphere
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.3),
            materials: [SimpleMaterial(color: UIColor(Theme.primaryColor), isMetallic: false)]
        )

        // Add username label
        let textEntity = createTextEntity(for: member.username)
        textEntity.position = [0, 0.5, 0]

        entity.addChild(sphere)
        entity.addChild(textEntity)

        return entity
    }

    private func createTextEntity(for text: String) -> Entity {
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.2),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )

        let textEntity = ModelEntity(
            mesh: textMesh,
            materials: [SimpleMaterial(color: .white, isMetallic: false)]
        )

        return textEntity
    }
}

struct ARMemberCard: View {
    let member: UserProfile
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.spacingS) {
                AsyncImage(url: URL(string: member.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(isSelected ? Theme.accentColor : Color.white, lineWidth: 2))

                Text(member.username)
                    .font(Theme.captionFont)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(Theme.spacingS)
            .background(isSelected ? Theme.accentColor.opacity(0.8) : Color.black.opacity(0.6))
            .cornerRadius(Theme.cornerRadiusM)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(Theme.springAnimation, value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ARRadarView_Previews: PreviewProvider {
    static var previews: some View {
        ARRadarView(familyMembers: [])
    }
}
