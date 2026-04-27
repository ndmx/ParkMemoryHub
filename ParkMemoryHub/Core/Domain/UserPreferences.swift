import Foundation

struct UserPreferences: Codable, Equatable, Sendable {
    var shareLocation: Bool
    var shareMemories: Bool
    var shareProfile: Bool
    var activityNotifications: Bool
    var memoryNotifications: Bool
    var pingNotifications: Bool

    init(
        shareLocation: Bool = true,
        shareMemories: Bool = true,
        shareProfile: Bool = true,
        activityNotifications: Bool = true,
        memoryNotifications: Bool = true,
        pingNotifications: Bool = true
    ) {
        self.shareLocation = shareLocation
        self.shareMemories = shareMemories
        self.shareProfile = shareProfile
        self.activityNotifications = activityNotifications
        self.memoryNotifications = memoryNotifications
        self.pingNotifications = pingNotifications
    }
}

