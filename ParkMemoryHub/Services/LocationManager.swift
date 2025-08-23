import Foundation
import CoreLocation
import Combine
import Firebase
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import BackgroundTasks
import CoreHaptics

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var monitoredRegions: Set<CLRegion> = []
    @Published var currentPark: String?
    @Published var currentRide: String?
    
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    // Disney World and Universal Studios coordinates
    private let disneyWorld = CLLocation(latitude: 28.4177, longitude: -81.5812)
    private let universalStudios = CLLocation(latitude: 28.4744, longitude: -81.4674)
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationManager.startUpdatingLocation()
        isLocationEnabled = true
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLocationEnabled = false
    }
    
    func getCurrentPark() async -> String? {
        guard let currentLocation = currentLocation else { return nil }
        
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(currentLocation)
            return placemarks.first?.name ?? placemarks.first?.locality
        } catch {
            // Fallback to distance-based detection for known parks
            let disneyDistance = currentLocation.distance(from: disneyWorld)
            let universalDistance = currentLocation.distance(from: universalStudios)
            
            // If within 5km of a known park
            if disneyDistance < 5000 {
                return "Disney World"
            } else if universalDistance < 5000 {
                return "Universal Studios"
            }
            
            return nil
        }
    }
    
    func getCurrentRide() -> String? {
        guard currentLocation != nil else { return nil }

        // This would be expanded with actual ride coordinates
        // For now, return a placeholder
        return nil
    }
    
    // MARK: - Geofencing
    func setupGeofence(for coordinate: CLLocationCoordinate2D, identifier: String, radius: CLLocationDistance = 100) {
        let region = CLCircularRegion(
            center: coordinate,
            radius: radius,
            identifier: identifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        locationManager.startMonitoring(for: region)
        monitoredRegions.insert(region)
    }
    
    func removeGeofence(withIdentifier identifier: String) {
        let regionsToRemove = monitoredRegions.filter { $0.identifier == identifier }
        for region in regionsToRemove {
            locationManager.stopMonitoring(for: region)
            monitoredRegions.remove(region)
        }
    }
    
    // MARK: - Real-time Location Updates
    func startRealTimeUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationManager.startUpdatingLocation()
        isLocationEnabled = true
        
        // Start updating location to Firebase
        startFirebaseLocationUpdates()
    }
    
    private func startFirebaseLocationUpdates() {
        guard let currentUser = FirebaseAuth.Auth.auth().currentUser else { return }
        
        // Update location every 30 seconds when moving
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            guard let location = self.currentLocation else { return }
            
            Task {
                do {
                    try await FirebaseService.shared.updateUserLocation(
                        userId: currentUser.uid,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                } catch {
                    print("Failed to update location in Firebase: \(error)")
                }
            }
        }
        
        // Schedule background sync
        scheduleBackgroundSync()
    }
    
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.parkmemoryhub.locationSync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 1 minute from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background sync: \(error)")
        }
    }
    
    func performBackgroundSync() async {
        guard let currentUser = FirebaseAuth.Auth.auth().currentUser,
              let location = currentLocation else { return }
        
        do {
            try await FirebaseService.shared.updateUserLocation(
                userId: currentUser.uid,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        } catch {
            print("Background sync failed: \(error)")
        }
    }
    
    func getLocationInfo() async -> MediaItem.LocationInfo? {
        guard let currentLocation = currentLocation else { return nil }
        
        let parkName = await getCurrentPark()
        
        return MediaItem.LocationInfo(
            latitude: currentLocation.coordinate.latitude,
            longitude: currentLocation.coordinate.longitude,
            parkName: parkName,
            rideName: getCurrentRide()
        )
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            self.currentLocation = location
            self.currentRide = self.getCurrentRide()

            // Handle async park detection
            Task {
                self.currentPark = await self.getCurrentPark()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startRealTimeUpdates()
            } else {
                self.stopLocationUpdates()
            }
        }
    }
    
    // MARK: - Geofencing Delegate Methods
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        DispatchQueue.main.async {
            self.handleRegionEvent(region: region, event: "entered")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        DispatchQueue.main.async {
            self.handleRegionEvent(region: region, event: "exited")
        }
    }
    
    private func handleRegionEvent(region: CLRegion, event: String) {
        // Trigger haptic feedback
        if #available(iOS 13.0, *) {
            triggerGeofenceHaptic()
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Location Update"
        content.body = "You \(event) \(region.identifier)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func triggerGeofenceHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            
            // Stop engine after haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                engine.stop()
            }
        } catch {
            print("Failed to trigger geofence haptic: \(error)")
        }
    }
}
