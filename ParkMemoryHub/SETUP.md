## GoogleService-Info.plist

This file contains client keys used by Firebase/Google SDKs and should not be committed.

Steps:
1. Download your `GoogleService-Info.plist` from the Firebase Console for this iOS app bundle ID.
2. Place it at `ParkMemoryHub/GoogleService-Info.plist` (root of the app target directory).
3. Ensure it is added to the Xcode target (Build Phases → Copy Bundle Resources).
4. The file is ignored by git via the root `.gitignore`.

Regenerating keys:
- If a key was exposed, rotate it in Google Cloud Console → APIs & Services → Credentials.
- Add API/application restrictions to the regenerated key.

# ParkMemory Hub - Complete Setup Guide

## 🚀 Overview
ParkMemory Hub is a modern iOS app for families to share memories, track locations, and plan activities while visiting theme parks. This guide covers the complete setup process for all features.

## 📋 Prerequisites
- Xcode 15.0+ (iOS 18.0+ target)
- iOS 18.0+ device for testing
- Firebase project with Authentication, Firestore, and Storage enabled
- Apple Developer Account for device testing

## 🔧 Firebase Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing
3. Enable Authentication, Firestore, and Storage

### 2. Configure Authentication
1. In Firebase Console → Authentication → Sign-in method
2. Enable Email/Password authentication
3. Add your app's bundle identifier

### 3. Configure Firestore
1. In Firebase Console → Firestore Database
2. Create database in test mode initially
3. Deploy the security rules from `firestore.rules`

### 4. Configure Storage
1. In Firebase Console → Storage
2. Create storage bucket
3. Set security rules to allow authenticated users

### 5. Download Configuration
1. Download `GoogleService-Info.plist`
2. Add to your Xcode project (ensure it's in the target)

## 📱 Xcode Project Setup

### 1. Add Required Frameworks
In your Xcode project, add these frameworks:
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseStorage`
- `FirebaseMessaging` (for push notifications)
- `CoreLocation`
- `MapKit`
- `ARKit`
- `RealityKit`
- `CoreHaptics`

### 2. Configure Info.plist
Ensure your `Info.plist` includes all the permissions and background modes from the provided `Info.plist` file.

### 3. Add Background Modes
In Xcode → Target → Signing & Capabilities:
- Background Modes
  - Location updates
  - Remote notifications

## 🔐 Security Configuration

### 1. Firestore Security Rules
Deploy the security rules from `firestore.rules` to your Firebase project:

```bash
firebase deploy --only firestore:rules
```

### 2. Storage Security Rules
Set Firebase Storage rules to:

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

## 📍 Location Services Setup

### 1. Location Permissions
The app automatically requests location permissions. Ensure your `Info.plist` has the proper usage descriptions.

### 2. Background Location
Background location updates are configured for continuous family tracking.

### 3. Geofencing
The app supports geofencing for park area detection.

## 🎯 AR Features Setup

### 1. ARKit Requirements
- iOS 11.0+ device with A9 processor or newer
- The app automatically detects AR support and provides fallbacks

### 2. Camera Permissions
AR features require camera access for world tracking.

## 🔔 Push Notifications Setup

### 1. Firebase Cloud Messaging
1. In Firebase Console → Project Settings → Cloud Messaging
2. Download `GoogleService-Info.plist` (if not already done)
3. Add your APNs authentication key

### 2. iOS Push Notifications
1. In Apple Developer Console → Certificates, Identifiers & Profiles
2. Create APNs authentication key
3. Upload to Firebase Console

## 🎨 Theme and UI Configuration

### 1. Color Assets
Create these color sets in your asset catalog:
- `PrimaryBlue`
- `AccentPurple`
- `SecondaryGreen`
- `WarningOrange`
- `ErrorRed`

### 2. Custom Fonts (Optional)
The app uses system fonts by default, but you can add custom fonts for a unique look.

## 🧪 Testing

### 1. Firebase Connection Test
The app includes a Firebase connection test. Use the `FirebaseConfigTest.swift` to verify connectivity.

### 2. Location Testing
- Test on physical device (simulator location is limited)
- Test background location updates
- Test geofencing functionality

### 3. AR Testing
- Test on ARKit-compatible devices
- Verify fallback behavior on unsupported devices

## 🚨 Common Issues and Solutions

### 1. Firebase Connection Errors
- Verify `GoogleService-Info.plist` is in the target
- Check Firebase project configuration
- Verify network connectivity

### 2. Location Permission Issues
- Check `Info.plist` usage descriptions
- Verify location services are enabled on device
- Check app permissions in Settings

### 3. AR Crashes
- Verify device supports ARKit
- Check camera permissions
- Test on physical device

### 4. Build Errors
- Ensure all frameworks are properly linked
- Check deployment target compatibility
- Verify Swift version compatibility

## 📊 Performance Optimization

### 1. Image Loading
- The app uses `AsyncImage` for efficient image loading
- Consider implementing `SDWebImageSwiftUI` for advanced caching

### 2. Location Updates
- Location updates are throttled to every 30 seconds when moving
- Background location is optimized for battery life

### 3. Data Pagination
- Media and activities support pagination for large datasets
- Implement lazy loading in your views

## 🔒 Privacy and Compliance

### 1. GDPR Compliance
- User data is stored only in Firebase
- Users can request data export
- Account deletion is supported

### 2. COPPA Compliance
- Kid Mode provides simplified interface
- Parental controls for family management

### 3. Data Security
- All data is encrypted in transit
- Firebase security rules enforce access control
- User authentication is required for all features

## 🚀 Deployment

### 1. App Store Preparation
- Test on multiple devices and iOS versions
- Verify all permissions work correctly
- Test background modes thoroughly

### 2. Production Firebase
- Switch from test mode to production
- Update security rules for production
- Configure proper error monitoring

### 3. Beta Testing
- Use TestFlight for beta distribution
- Test with real family groups
- Verify location features in real parks

## 📞 Support

For technical support or questions:
- Check the in-app Help & FAQ section
- Use the Contact Support feature
- Review Firebase documentation for backend issues

## 🔄 Updates and Maintenance

### 1. Regular Updates
- Keep Firebase SDKs updated
- Monitor Firebase Console for usage and errors
- Update security rules as needed

### 2. Feature Additions
- The modular architecture supports easy feature additions
- Follow the existing patterns for new views and services
- Maintain consistency with the established theme system

---

**Note**: This setup guide covers the complete configuration for all features. Ensure you test thoroughly on physical devices before deploying to production.
