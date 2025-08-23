import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// Test class to verify Firebase configuration
class FirebaseConfigTest {
    static func testFirebaseServices() {
        print("🧪 Testing Firebase Services...")
        
        // Test Auth
        let _ = Auth.auth()
        print("✅ Firebase Auth: OK")
        
        // Test Firestore
        let _ = Firestore.firestore()
        print("✅ Firebase Firestore: OK")
        
        // Test Storage
        let _ = Storage.storage()
        print("✅ Firebase Storage: OK")
        
        print("🎯 Firebase Services Test Complete!")
    }
    
    static func testFirebaseConnection() async {
        print("🌐 Testing Firebase Connection...")
        
        do {
            // Try to access Firestore (this will test the connection)
            let db = Firestore.firestore()
            let _ = try await db.collection("test").document("test").getDocument()
            print("✅ Firebase Connection: OK")
        } catch {
            print("❌ Firebase Connection: Failed - \(error)")
            print("💡 This might be expected if you haven't set up Firestore rules yet")
        }
    }
}
