# ParkMemory Hub 🎢📸

A family-oriented iOS app designed for group trips. Capture and share memories while coordinating with your family in real-time.

## ✨ Features

### 🎯 Core Functionalities

- **MemoryMingle**: Shared photo album with real-time syncing
- **ReuniteRadar**: Location tracking and family member pinging
- **ParkSync**: Activity planning with group voting
// Removed Kid Mode feature. The app supports accessibility via Dynamic Type, VoiceOver, and high-contrast colors.

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

- iOS 18.0+
- iPhone 14 Pro or newer (optimized)
- Xcode 15.0+
- Apple Developer Account (for TestFlight)

## 🚀 Setup Instructions

### 1. Prerequisites
- Install [Xcode](https://apps.apple.com/us/app/xcode/id497799835) from the App Store
- Create an [Apple Developer Account](https://developer.apple.com/) ($99/year)
- Set up [Firebase Project](https://console.firebase.google.com/)


### 2. Xcode Project Setup
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

## 🎨 Customization

### Accessibility
The app supports Dynamic Type, VoiceOver, and high-contrast colors for inclusive use.
- Larger touch targets
- Colorful animations
- Simplified navigation
- Family-friendly icons

### Theme Integration
- Disney World color schemes
- Universal Studios branding

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

- A trip toDisney World and Universal Studios for inspiration
- Firebase team for excellent backend services
- Apple for SwiftUI and iOS development tools
- Family and friends for testing and feedback

---

**Happy Park Hopping! 🎢✨**

For support or questions, please refer to the in-app help section or contact through the app.
