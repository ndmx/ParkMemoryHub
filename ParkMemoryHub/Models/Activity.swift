import Foundation
import FirebaseFirestore
import CoreLocation

struct Activity: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let location: LocationInfo?
    let scheduledTime: Date?
    let createdBy: String
    let familyCode: String
    let createdAt: Date
    let votes: [String: VoteType] // userId: VoteType
    let status: ActivityStatus
    
    enum VoteType: String, Codable, CaseIterable {
        case yes = "yes"
        case no = "no"
        case maybe = "maybe"
    }
    
    enum ActivityStatus: String, Codable, CaseIterable {
        case planned = "planned"
        case confirmed = "confirmed"
        case completed = "completed"
        case cancelled = "cancelled"
    }
    
    struct LocationInfo: Codable {
        let latitude: Double
        let longitude: Double
        let parkName: String?
        let rideName: String?
        let address: String?
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    var voteCount: Int {
        votes.values.filter { $0 == .yes }.count
    }
    
    var totalVoters: Int {
        votes.count
    }
    
    init(
        id: String,
        title: String,
        description: String? = nil,
        location: LocationInfo? = nil,
        scheduledTime: Date? = nil,
        createdBy: String,
        familyCode: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.location = location
        self.scheduledTime = scheduledTime
        self.createdBy = createdBy
        self.familyCode = familyCode
        self.createdAt = Date()
        self.votes = [:]
        self.status = .planned
    }
    
    // Full initializer for Firestore conversion
    init(
        id: String,
        title: String,
        description: String? = nil,
        location: LocationInfo? = nil,
        scheduledTime: Date? = nil,
        createdBy: String,
        familyCode: String,
        votes: [String: VoteType],
        status: ActivityStatus
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.location = location
        self.scheduledTime = scheduledTime
        self.createdBy = createdBy
        self.familyCode = familyCode
        self.createdAt = Date()
        self.votes = votes
        self.status = status
    }
}
