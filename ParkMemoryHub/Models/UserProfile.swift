import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    let email: String
    let avatarURL: String?
    let isKidMode: Bool
    let familyCode: String
    let shareLocation: Bool
    let shareMedia: Bool
    let shareProfile: Bool
    let createdAt: Date
    let lastActive: Date
    let activityNotifications: Bool // Added
    let mediaNotifications: Bool
    let pingNotifications: Bool
    let locationUpdates: Bool
    
    init(id: String, username: String, email: String, avatarURL: String? = nil,
         isKidMode: Bool = false, familyCode: String, shareLocation: Bool = true,
         shareMedia: Bool = true, shareProfile: Bool = true,
         activityNotifications: Bool = true, mediaNotifications: Bool = true,
         pingNotifications: Bool = true, locationUpdates: Bool = true) {
        self.id = id
        self.username = username
        self.email = email
        self.avatarURL = avatarURL
        self.isKidMode = isKidMode
        self.familyCode = familyCode
        self.shareLocation = shareLocation
        self.shareMedia = shareMedia
        self.shareProfile = shareProfile
        self.createdAt = Date()
        self.lastActive = Date()
        self.activityNotifications = activityNotifications
        self.mediaNotifications = mediaNotifications
        self.pingNotifications = pingNotifications
        self.locationUpdates = locationUpdates
    }
    
    // Custom initializer for creating from Firestore data
    init(id: String, username: String, email: String, avatarURL: String?, isKidMode: Bool,
         familyCode: String, shareLocation: Bool, shareMedia: Bool, shareProfile: Bool,
         createdAt: Date, lastActive: Date,
         activityNotifications: Bool = true, mediaNotifications: Bool = true,
         pingNotifications: Bool = true, locationUpdates: Bool = true) {
        self.id = id
        self.username = username
        self.email = email
        self.avatarURL = avatarURL
        self.isKidMode = isKidMode
        self.familyCode = familyCode
        self.shareLocation = shareLocation
        self.shareMedia = shareMedia
        self.shareProfile = shareProfile
        self.createdAt = createdAt
        self.lastActive = lastActive
        self.activityNotifications = activityNotifications
        self.mediaNotifications = mediaNotifications
        self.pingNotifications = pingNotifications
        self.locationUpdates = locationUpdates
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case avatarURL
        case isKidMode
        case familyCode
        case shareLocation
        case shareMedia
        case shareProfile
        case createdAt
        case lastActive
        case activityNotifications
        case mediaNotifications
        case pingNotifications
        case locationUpdates
    }
}
