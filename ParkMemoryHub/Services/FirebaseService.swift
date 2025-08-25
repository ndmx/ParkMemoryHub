import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var currentUser: FirebaseAuth.User?
    @Published var isAuthenticated = false
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        let _ = auth.addStateDidChangeListener { [weak self] (auth: Auth, user: FirebaseAuth.User?) in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    // MARK: - Authentication
    func signUp(email: String, password: String, username: String, familyCode: String) async throws -> FirebaseAuth.User {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            
            let userProfile = UserProfile(
                id: result.user.uid,
                username: username,
                email: email,
                familyCode: familyCode
            )
            
            try await saveUserProfile(userProfile)
            return result.user
        } catch let error as NSError {
            if let authErrorCode = AuthErrorCode(rawValue: error.code) {
                switch authErrorCode {
                case .emailAlreadyInUse:
                    throw NSError(domain: "FirebaseService", code: 409, userInfo: [NSLocalizedDescriptionKey: "Email is already in use."])
                case .weakPassword:
                    throw NSError(domain: "FirebaseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Password is too weak. Please use at least 6 characters."])
                case .invalidEmail:
                    throw NSError(domain: "FirebaseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid email format."])
                default:
                    throw error
                }
            }
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            
            // Update last active time
            try await updateLastActive(userId: result.user.uid)
            
            return result.user
        } catch let error as NSError {
            if let authErrorCode = AuthErrorCode(rawValue: error.code) {
                switch authErrorCode {
                case .userNotFound:
                    throw NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No account found with this email."])
                case .wrongPassword:
                    throw NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Incorrect password."])
                case .invalidEmail:
                    throw NSError(domain: "FirebaseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid email format."])
                default:
                    throw error
                }
            }
            throw error
        }
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    // MARK: - User Profile
    func saveUserProfile(_ profile: UserProfile) async throws {
        try await db.collection("users").document(profile.id).setData([
            "username": profile.username,
            "email": profile.email,
            "avatarURL": profile.avatarURL ?? "",
            "isKidMode": profile.isKidMode,
            "familyCode": profile.familyCode,
            "shareLocation": profile.shareLocation,
            "shareMedia": profile.shareMedia,
            "shareProfile": profile.shareProfile,
            "createdAt": profile.createdAt,
            "lastActive": profile.lastActive
        ])
    }
    
    func getUserProfile(userId: String) async throws -> UserProfile? {
        let document = try await db.collection("users").document(userId).getDocument()
        guard let data = document.data() else { return nil }
        
        // Parse dates from Firestore Timestamp
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let lastActive = (data["lastActive"] as? Timestamp)?.dateValue() ?? Date()
        
        return UserProfile(
            id: userId,
            username: data["username"] as? String ?? "",
            email: data["email"] as? String ?? "",
            avatarURL: data["avatarURL"] as? String,
            isKidMode: data["isKidMode"] as? Bool ?? false,
            familyCode: data["familyCode"] as? String ?? "",
            shareLocation: data["shareLocation"] as? Bool ?? true,
            shareMedia: data["shareMedia"] as? Bool ?? true,
            shareProfile: data["shareProfile"] as? Bool ?? true,
            createdAt: createdAt,
            lastActive: lastActive
        )
    }
    
    func getFamilyMembers(familyCode: String) async throws -> [UserProfile] {
        let snapshot = try await db.collection("users")
            .whereField("familyCode", isEqualTo: familyCode)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            
            // Parse dates from Firestore Timestamp
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let lastActive = (data["lastActive"] as? Timestamp)?.dateValue() ?? Date()
            
            return UserProfile(
                id: document.documentID,
                username: data["username"] as? String ?? "",
                email: data["email"] as? String ?? "",
                avatarURL: data["avatarURL"] as? String,
                isKidMode: data["isKidMode"] as? Bool ?? false,
                familyCode: data["familyCode"] as? String ?? "",
                shareLocation: data["shareLocation"] as? Bool ?? true,
                shareMedia: data["shareMedia"] as? Bool ?? true,
                shareProfile: data["shareProfile"] as? Bool ?? true,
                createdAt: createdAt,
                lastActive: lastActive
            )
        }
    }
    
    // MARK: - Profile Updates
    func updateLastActive(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "lastActive": Timestamp(date: Date())
        ])
    }
    
    func updateAvatar(userId: String, avatarURL: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "avatarURL": avatarURL
        ])
    }
    
    func updateUserProfile(userId: String, updates: [String: Any]) async throws {
        try await db.collection("users").document(userId).updateData(updates)
    }
    
    // MARK: - Media Items
    func uploadMedia(
        _ imageData: Data,
        userId: String,
        username: String,
        caption: String?,
        location: MediaItem.LocationInfo?,
        tags: [String],
        appliedFilter: String?,
        frameTheme: String?
    ) async throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("media/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        // Get the user's family code
        let familyCode = try await getCurrentFamilyCode() ?? ""
        
        let mediaItem = MediaItem(
            id: UUID().uuidString,
            userId: userId,
            username: username,
            mediaURL: downloadURL.absoluteString,
            mediaType: .photo,
            caption: caption,
            location: location,
            tags: tags,
            appliedFilter: appliedFilter,
            frameTheme: frameTheme,
            familyCode: familyCode
        )
        
        try await saveMediaItem(mediaItem)
        return mediaItem.id
    }
    
    func saveMediaItem(_ item: MediaItem) async throws {
        try await db.collection("media").document(item.id).setData([
            "userId": item.userId,
            "username": item.username,
            "mediaURL": item.mediaURL,
            "mediaType": item.mediaType.rawValue,
            "caption": item.caption ?? "",
            "location": item.location.map { [
                "latitude": $0.latitude,
                "longitude": $0.longitude,
                "parkName": $0.parkName ?? "",
                "rideName": $0.rideName ?? ""
            ] } ?? [:],
            "tags": item.tags,
            "appliedFilter": item.appliedFilter ?? "",
            "frameTheme": item.frameTheme ?? "",
            "createdAt": item.createdAt,
            "likes": item.likes,
            "familyCode": item.familyCode
        ])
    }
    
    func getFamilyMedia(familyCode: String) async throws -> [MediaItem] {
        let snapshot = try await db.collection("media")
            .whereField("familyCode", isEqualTo: familyCode)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let mediaType = MediaItem.MediaType(rawValue: data["mediaType"] as? String ?? "") else { return nil }
            
            let locationData = data["location"] as? [String: Any]
            let location = locationData.map { locData in
                MediaItem.LocationInfo(
                    latitude: locData["latitude"] as? Double ?? 0,
                    longitude: locData["longitude"] as? Double ?? 0,
                    parkName: locData["parkName"] as? String,
                    rideName: locData["rideName"] as? String
                )
            }
            
            var item = MediaItem(
                id: document.documentID,
                userId: data["userId"] as? String ?? "",
                username: data["username"] as? String ?? "",
                mediaURL: data["mediaURL"] as? String ?? "",
                mediaType: mediaType,
                caption: data["caption"] as? String,
                location: location,
                tags: data["tags"] as? [String] ?? [],
                appliedFilter: data["appliedFilter"] as? String,
                frameTheme: data["frameTheme"] as? String
            )
            // Persist likes from Firestore
            let likes = data["likes"] as? [String] ?? []
            item.likes = likes
            return item
        }
    }
    
    // MARK: - Activities
    func saveActivity(_ activity: Activity) async throws {
        try await db.collection("activities").document(activity.id).setData([
            "title": activity.title,
            "description": activity.description ?? "",
            "location": activity.location.map { [
                "latitude": $0.latitude,
                "longitude": $0.longitude,
                "parkName": $0.parkName ?? "",
                "rideName": $0.rideName ?? "",
                "address": $0.address ?? ""
            ] } ?? [:],
            "scheduledTime": activity.scheduledTime as Any,
            "createdBy": activity.createdBy,
            "familyCode": activity.familyCode,
            "createdAt": activity.createdAt,
            "votes": activity.votes.mapValues { $0.rawValue },
            "status": activity.status.rawValue
        ])
    }
    
    func updateActivityVotes(activityId: String, userId: String, vote: Activity.VoteType) async throws {
        try await db.collection("activities").document(activityId).updateData([
            "votes.\(userId)": vote.rawValue
        ])
    }

    func voteOnActivity(activityId: String, voteType: Activity.VoteType) async throws {
        guard let userId = currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await updateActivityVotes(activityId: activityId, userId: userId, vote: voteType)
    }
    
    // MARK: - Location Updates
    func updateUserLocation(userId: String, latitude: Double, longitude: Double) async throws {
        try await db.collection("users").document(userId).updateData([
            "location": GeoPoint(latitude: latitude, longitude: longitude),
            "lastActive": Timestamp()
        ])
    }
    
    // MARK: - Notifications
    func sendPingNotification(to userId: String, from senderId: String, message: String) async throws {
        let data: [String: Any] = [
            "toUserId": userId,
            "fromUserId": senderId,
            "message": message,
            "timestamp": Timestamp(),
            "type": "ping"
        ]
        try await db.collection("notifications").addDocument(data: data)
    }
    
    func getUnreadNotifications(familyCode: String) async throws -> [DocumentSnapshot] {
        let snapshot = try await db.collection("notifications")
            .whereField("familyCode", isEqualTo: familyCode)
            .whereField("isRead", isEqualTo: false)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return snapshot.documents
    }
    
    func getUnreadMedia(familyCode: String) async throws -> [DocumentSnapshot] {
        let snapshot = try await db.collection("media")
            .whereField("familyCode", isEqualTo: familyCode)
            .whereField("isViewed", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents
    }
    
    func getPendingActivities(familyCode: String) async throws -> [Activity] {
        let snapshot = try await db.collection("activities")
            .whereField("familyCode", isEqualTo: familyCode)
            .whereField("status", isEqualTo: "pending")
            .order(by: "scheduledTime", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            
            guard let title = data["title"] as? String,
                  let createdBy = data["createdBy"] as? String,
                  let familyCode = data["familyCode"] as? String,
                  let statusString = data["status"] as? String,
                  let status = Activity.ActivityStatus(rawValue: statusString) else {
                return nil
            }
            
            let locationData = data["location"] as? [String: Any]
            let location = locationData.map { locData in
                Activity.LocationInfo(
                    latitude: locData["latitude"] as? Double ?? 0,
                    longitude: locData["longitude"] as? Double ?? 0,
                    parkName: locData["parkName"] as? String,
                    rideName: locData["rideName"] as? String,
                    address: locData["address"] as? String
                )
            }
            
            let votes = data["votes"] as? [String: String] ?? [:]
            let parsedVotes = votes.compactMapValues { Activity.VoteType(rawValue: $0) }
            
            return Activity(
                id: document.documentID,
                title: title,
                description: data["description"] as? String,
                location: location,
                scheduledTime: (data["scheduledTime"] as? Timestamp)?.dateValue(),
                createdBy: createdBy,
                familyCode: familyCode,
                votes: parsedVotes,
                status: status
            )
        }
    }
    
    func sendSupportMessage(userId: String, message: String) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "message": message,
            "timestamp": Timestamp(),
            "type": "support"
        ]
        try await db.collection("support").addDocument(data: data)
    }
    
    // MARK: - User Preferences
    func updateUserPreferences(userId: String, preferences: [String: Any]) async throws {
        try await db.collection("users").document(userId).updateData([
            "preferences": preferences,
            "lastUpdated": Timestamp()
        ])
    }

    // MARK: - Activities
    func getFamilyActivities(familyCode: String) async throws -> [Activity] {
        let query = db.collection("activities")
            .whereField("familyCode", isEqualTo: familyCode)
            .order(by: "createdAt", descending: true)
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            
            guard let title = data["title"] as? String,
                  let createdBy = data["createdBy"] as? String,
                  let familyCode = data["familyCode"] as? String,
                  let statusString = data["status"] as? String,
                  let status = Activity.ActivityStatus(rawValue: statusString) else {
                return nil
            }
            
            let locationData = data["location"] as? [String: Any]
            let location = locationData.map { locData in
                Activity.LocationInfo(
                    latitude: locData["latitude"] as? Double ?? 0,
                    longitude: locData["longitude"] as? Double ?? 0,
                    parkName: locData["parkName"] as? String,
                    rideName: locData["rideName"] as? String,
                    address: locData["address"] as? String
                )
            }
            
            let votes = data["votes"] as? [String: String] ?? [:]
            let parsedVotes = votes.compactMapValues { Activity.VoteType(rawValue: $0) }
            
            return Activity(
                id: document.documentID,
                title: title,
                description: data["description"] as? String,
                location: location,
                scheduledTime: (data["scheduledTime"] as? Timestamp)?.dateValue(),
                createdBy: createdBy,
                familyCode: familyCode,
                votes: parsedVotes,
                status: status
            )
        }
    }
    
    // MARK: - Pagination Support
    func getFamilyMedia(familyCode: String, limit: Int, lastDocument: DocumentSnapshot?) async throws -> ([MediaItem], DocumentSnapshot?) {
        var query = db.collection("media")
            .whereField("familyCode", isEqualTo: familyCode)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await query.getDocuments()
        let items: [MediaItem] = snapshot.documents.compactMap { document in
            let data = document.data()
            guard let mediaType = MediaItem.MediaType(rawValue: data["mediaType"] as? String ?? "") else { return nil }
            
            let locationData = data["location"] as? [String: Any]
            let location = locationData.map { locData in
                MediaItem.LocationInfo(
                    latitude: locData["latitude"] as? Double ?? 0,
                    longitude: locData["longitude"] as? Double ?? 0,
                    parkName: locData["parkName"] as? String,
                    rideName: locData["rideName"] as? String
                )
            }
            
            return MediaItem(
                id: document.documentID,
                userId: data["userId"] as? String ?? "",
                username: data["username"] as? String ?? "",
                mediaURL: data["mediaURL"] as? String ?? "",
                mediaType: mediaType,
                caption: data["caption"] as? String,
                location: location,
                tags: data["tags"] as? [String] ?? [],
                appliedFilter: data["appliedFilter"] as? String,
                frameTheme: data["frameTheme"] as? String
            )
        }
        
        return (items, snapshot.documents.last)
    }
    
    // MARK: - Family Code Management
    func getCurrentFamilyCode() async throws -> String? {
        guard let userId = currentUser?.uid else { return nil }
        let document = try await db.collection("users").document(userId).getDocument()
        guard let data = document.data() else { return nil }
        return data["familyCode"] as? String
    }
    
    // MARK: - Media Likes Management
    func toggleLike(mediaId: String, isLiked: Bool) async throws {
        guard let userId = currentUser?.uid else { throw NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]) }
        
        let mediaRef = db.collection("media").document(mediaId)
        
        if isLiked {
            try await mediaRef.updateData([
                "likes": FieldValue.arrayUnion([userId])
            ])
        } else {
            try await mediaRef.updateData([
                "likes": FieldValue.arrayRemove([userId])
            ])
        }
    }
    
    // MARK: - Testing & Diagnostics
    func testFirebaseConnection() async -> Bool {
        do {
            // Test basic Firestore access
            let _ = try await db.collection("test").document("connection").getDocument()
            print("✅ Firebase connection test successful")
            return true
        } catch {
            print("❌ Firebase connection test failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func getFirebaseStatus() -> [String: Bool] {
        return [
            "Auth": true,
            "Firestore": true,
            "Storage": true
        ]
    }
    
    // MARK: - Delete Functions
    
    func deleteMediaItem(_ mediaItem: MediaItem) async throws {
        // Delete from Firestore
        try await db.collection("media").document(mediaItem.id).delete()
        
        // Delete from Storage if URL exists
        if !mediaItem.mediaURL.isEmpty {
            let storage = Storage.storage()
            let storageRef = storage.reference(forURL: mediaItem.mediaURL)
            try await storageRef.delete()
        }
    }
    
    func deleteActivity(_ activity: Activity) async throws {
        // Delete from Firestore
        try await db.collection("activities").document(activity.id).delete()
    }
}
