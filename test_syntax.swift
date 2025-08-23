// Simple test to verify syntax fixes
import Foundation

// Test UserProfile Equatable conformance
struct TestUserProfile: Identifiable, Codable, Equatable {
    let id: String
    let username: String

    static func == (lhs: TestUserProfile, rhs: TestUserProfile) -> Bool {
        lhs.id == rhs.id
    }
}

// Test ColorScheme enum usage
enum TestColorScheme {
    case light, dark
}

// Test the fixes
let profiles = [TestUserProfile(id: "1", username: "test")]
if let index = profiles.firstIndex(of: TestUserProfile(id: "1", username: "test")) {
    print("Found at index: \(index)")
}

// Test Date to Any conversion
let testDate: Date? = Date()
let dict: [String: Any] = ["date": testDate as Any]

print("Syntax test completed successfully!")
