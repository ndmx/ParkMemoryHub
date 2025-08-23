# ParkMemory Hub 🎢📸

A family-oriented iOS app designed for group trips to Disney World and Universal Studios Orlando. Capture and share memories while coordinating with your family in real-time.

## ✨ Features

### 🎯 Core Functionalities

- **MemoryMingle**: Shared photo album with real-time syncing
- **ReuniteRadar**: Location tracking and family member pinging
- **ParkSync**: Activity planning with group voting
- **Kid Mode**: Simplified interface for younger family members

### 🔐 Authentication & Profiles
- Email/password signup and login
- Family group joining via shared codes
- User profiles with customizable settings
- Secure data with Firebase backend

### 📸 MemoryMingle (Photo Sharing)
- Camera and photo library integration
- Real-time photo sharing with family
- Photo filters and effects
- Location-based automatic tagging
- Disney/Universal themed frames
- Captions and comments

### 📍 ReuniteRadar (Location Services)
- Real-time family member locations
- Interactive map with park boundaries
- Location-based pinging system
- Privacy controls for location sharing
- Integration with planned activities

### 📅 ParkSync (Planning)
- Create and schedule activities
- Group voting system (Yes/Maybe/No)
- Location-based activity suggestions
- Real-time itinerary updates
- Notifications for changes

## 🛠️ Technical Stack

- **Frontend**: SwiftUI (iOS 17+)
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Location**: CoreLocation + MapKit
- **Image Processing**: CoreImage filters
- **Architecture**: MVVM with ObservableObject

## 📱 Requirements

- iOS 17.0+
- iPhone 14 Pro or newer (optimized)
- Xcode 15.0+
- Apple Developer Account (for TestFlight)

## 🚀 Setup Instructions

### 1. Prerequisites
- Install [Xcode](https://apps.apple.com/us/app/xcode/id497799835) from the App Store
- Create an [Apple Developer Account](https://developer.apple.com/) ($99/year)
- Set up [Firebase Project](https://console.firebase.google.com/)

### 2. Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Enable the following services:
   - Authentication (Email/Password)
   - Firestore Database
   - Storage
   - Realtime Database
4. Download `GoogleService-Info.plist`
5. Add it to your Xcode project

### 3. Xcode Project Setup
1. Open `ParkMemoryHub.xcodeproj` in Xcode
2. Add Firebase dependencies:
   - File → Add Packages
   - Enter: `https://github.com/firebase/firebase-ios-sdk`
   - Select: Auth, Firestore, Storage, Database
3. Add `GoogleService-Info.plist` to your project
4. Set minimum iOS deployment target to 17.0

### 4. Build and Run
1. Select your target device (iPhone 14 Pro+ recommended)
2. Press ⌘+R to build and run
3. Grant necessary permissions when prompted

## 📁 Project Structure

```
ParkMemoryHub/
├── Models/
│   ├── UserProfile.swift      # User data model
│   ├── MediaItem.swift        # Photo/video model
│   └── Activity.swift         # Planning model
├── Services/
│   ├── FirebaseService.swift  # Firebase operations
│   └── LocationManager.swift  # GPS handling
├── Views/
│   ├── AuthView.swift         # Login/signup
│   ├── MainTabView.swift      # Tab navigation
│   ├── AlbumView.swift        # Memory sharing
│   ├── CaptureView.swift      # Photo capture
│   ├── RadarView.swift        # Location tracking
│   ├── PlannerView.swift      # Activity planning
│   ├── ProfileView.swift      # User settings
│   └── MediaDetailView.swift  # Memory details
└── Assets.xcassets/           # Images and colors
```

## 🔧 Configuration

### Firebase Rules
Set up Firestore security rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /media/{mediaId} {
      allow read, write: if request.auth != null;
    }
    match /activities/{activityId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Storage Rules
Set up Firebase Storage rules:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /media/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 📱 TestFlight Deployment

### 1. Archive Build
1. In Xcode: Product → Archive
2. Wait for archive completion
3. Click "Distribute App"

### 2. Upload to App Store Connect
1. Select "App Store Connect"
2. Choose "Upload"
3. Follow upload process

### 3. Configure TestFlight
1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Create new app (match bundle ID)
3. Add internal testers (up to 25)
4. Submit for beta review if needed

### 4. Install on Devices
1. Testers receive email invite
2. Download TestFlight app
3. Redeem invitation code
4. Install ParkMemory Hub

## 🎨 Customization

### Kid Mode Features
- Larger touch targets
- Colorful animations
- Simplified navigation
- Family-friendly icons

### Theme Integration
- Disney World color schemes
- Universal Studios branding
- Park-specific frames and overlays
- Seasonal themes

## 🔒 Privacy & Security

- All data is private to family groups
- Location sharing is opt-in
- No external data sharing
- Firebase encryption
- GDPR compliant

## 🐛 Troubleshooting

### Common Issues
1. **Firebase not connecting**: Check `GoogleService-Info.plist` is added
2. **Location not working**: Verify permission settings in device
3. **Photos not uploading**: Check Firebase Storage rules
4. **Build errors**: Ensure iOS 17+ deployment target

### Debug Tips
- Use Xcode console for Firebase logs
- Test on multiple simulators for group features
- Verify network connectivity
- Check Firebase project settings

## 📈 Future Enhancements

- Push notifications
- Offline mode improvements
- Advanced photo editing
- Social sharing features
- Multi-language support
- Apple Watch companion app

## 🤝 Contributing

This is a personal project, but suggestions are welcome! Feel free to:
- Report bugs
- Suggest features
- Improve documentation
- Optimize performance

## 📄 License

This project is for personal use. Please respect Disney and Universal Studios trademarks.

## 🙏 Acknowledgments

- Disney World and Universal Studios for inspiration
- Firebase team for excellent backend services
- Apple for SwiftUI and iOS development tools
- Family and friends for testing and feedback

---

**Happy Park Hopping! 🎢✨**

For support or questions, please refer to the in-app help section or contact through the app.
