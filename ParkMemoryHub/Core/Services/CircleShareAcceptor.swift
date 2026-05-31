import CloudKit
import Foundation

/// Accepts a `CKShare` the user tapped (an iCloud share link) and records this
/// device as a participant of that circle.
enum CircleShareAcceptor {
    static func accept(_ metadata: CKShare.Metadata) async throws {
        guard let rootRecordID = metadata.hierarchicalRootRecordID,
              let circleID = UUID(uuidString: rootRecordID.recordName) else {
            throw CircleSyncError.circleUnavailable
        }

        let containerIdentifier = metadata.containerIdentifier
        let container = CKContainer(identifier: containerIdentifier)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.qualityOfService = .userInitiated
            operation.acceptSharesResultBlock = { result in
                continuation.resume(with: result)
            }
            container.add(operation)
        }

        let zoneID = rootRecordID.zoneID
        let displayName = (metadata.share[CKShare.SystemFieldKey.title] as? String) ?? "Shared Circle"

        try FileDeviceIdentityStore.joinCircle(
            circleID: circleID,
            displayName: displayName,
            zoneName: zoneID.zoneName,
            zoneOwnerName: zoneID.ownerName
        )

        // New zone — drop any stale change tokens so the first sync reads it fully.
        await FileChangeTokenStore().reset()
    }
}
