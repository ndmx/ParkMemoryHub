import Foundation
import FirebaseFirestore
import CoreLocation

struct MediaItem: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let mediaURL: String
    let mediaType: MediaType
    let caption: String?
    let location: LocationInfo?
    let tags: [String]
    let appliedFilter: String?
    let frameTheme: String?
    let createdAt: Date
    let likes: [String] // Array of user IDs who liked
    let familyCode: String // Added for consistency with Firestore rules
    
    enum MediaType: String, Codable, CaseIterable {
        case photo = "photo"
        case video = "video"
    }
    
    struct LocationInfo: Codable {
        let latitude: Double
        let longitude: Double
        let parkName: String?
        let rideName: String?
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    init(
        id: String,
        userId: String,
        username: String,
        mediaURL: String,
        mediaType: MediaType,
        caption: String? = nil,
        location: LocationInfo? = nil,
        tags: [String] = [],
        appliedFilter: String? = nil,
        frameTheme: String? = nil,
        familyCode: String = ""
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.mediaURL = mediaURL
        self.mediaType = mediaType
        self.caption = caption
        self.location = location
        self.tags = tags
        self.appliedFilter = appliedFilter
        self.frameTheme = frameTheme
        self.createdAt = Date()
        self.likes = []
        self.familyCode = familyCode
    }
}
