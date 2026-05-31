import CloudKit
import SwiftUI
import UIKit

/// A circle share ready to hand to `UICloudSharingController`.
struct PreparedShare: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

/// Wraps `UICloudSharingController` so an owner can invite people to the circle
/// and manage participants (including removing them, which revokes access).
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeCoordinator() -> Coordinator {
        Coordinator(share: share)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        private let share: CKShare

        init(share: CKShare) {
            self.share = share
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            share[CKShare.SystemFieldKey.title] as? String ?? "Park Memory Circle"
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            // The controller surfaces its own error UI; nothing further to do.
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}
    }
}
