# iOS Version Requirements

## Current Target: iOS 18.0+

### 📱 Minimum iOS Version: 18.0
**Deployment Target:** `IPHONEOS_DEPLOYMENT_TARGET = 18.0`

### 🚨 IMPORTANT: Do NOT lower the iOS version below 18.0

#### Why iOS 18.0+ is Required:

1. **Modern Map API (iOS 17+)**
   - Uses `Map` with `MapContentBuilder`
   - Modern `Annotation` API instead of deprecated `MapAnnotation`
   - Better performance and features

2. **SwiftUI Features**
   - Enhanced Map integration
   - Improved async/await support
   - Better animation and transition APIs

3. **Privacy Manifest (iOS 17+)**
   - Required `PrivacyInfo.xcprivacy` for App Store
   - Location and API usage declarations

4. **Camera & Vision (iOS 17+)**
   - Enhanced face detection APIs
   - Better camera integration
   - Improved image processing

### 🔧 Key APIs Requiring iOS 18.0+:

- `Map(position:)` initializer
- Modern `Annotation` with closures
- Enhanced `AsyncImage` features
- Latest Firebase compatibility

### ⚠️ Breaking Changes if Lowering Version:

If you need to support older iOS versions, you will need to:

1. **Rewrite Map Implementation** 
   - Use deprecated `MapAnnotation` API
   - Handle coordinate region binding manually
   - Lose modern Map features

2. **Update Privacy Handling**
   - Different privacy manifest requirements
   - Modified location permission flows

3. **Camera Integration Changes**
   - Different Vision framework APIs
   - Modified camera picker implementation

### 📋 Project Configuration Checklist:

- [x] `IPHONEOS_DEPLOYMENT_TARGET = 18.0` in all build configurations
- [x] Modern Map API implementation (`Map` with `MapContentBuilder`)
- [x] NavigationStack instead of deprecated NavigationView
- [x] Modern toolbar API (`.toolbar(.hidden)` vs `.navigationBarHidden`)
- [x] Modern dismiss environment (`@Environment(\.dismiss)` vs `presentationMode`)
- [x] Privacy manifest (`PrivacyInfo.xcprivacy`)
- [x] iOS 18+ Firebase SDK version
- [x] Modern SwiftUI features utilized

### 🔄 To Update iOS Version (if needed):

1. Update `IPHONEOS_DEPLOYMENT_TARGET` in `project.pbxproj`
2. Test all Map functionality 
3. Verify camera/Vision features
4. Check Firebase compatibility
5. Update this documentation

---

**Last Updated:** December 2024  
**Current iOS Target:** 18.0+  
**Recommended:** Keep at iOS 18.0+ for optimal performance and features
