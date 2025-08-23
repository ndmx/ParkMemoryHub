import SwiftUI
import MapKit
import CoreHaptics

// Modern iOS 18+ Map API - MapAnnotationItem no longer needed

struct RadarView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var familyMembers: [UserProfile] = []
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 28.4177, longitude: -81.5812), // Default to Disney World
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var selectedMember: UserProfile?
    @State private var showPingAlert = false
    @State private var pingMessage = ""
    @State private var isLoading = false
    @State private var showARView = false
    @State private var engine: CHHapticEngine?
    @State private var isVisible = false
    @State private var memberLocations: [String: CLLocationCoordinate2D] = [:]
    @State private var currentUserProfile: UserProfile?
    
    // MARK: - Sub-Views for Complex Expression Breaking

    private var headerView: some View {
        HStack {
            Text("Family Radar")
                .font(Theme.titleFont)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            HStack(spacing: Theme.spacingS) {
                Button(action: { showARView = true }) {
                    Image(systemName: "arkit")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.accentColor)
                        .clipShape(Circle())
                        .themeShadow(.small)
                }
                .accessibilityLabel("Open AR Family Radar")
                .accessibilityHint("View family members in augmented reality")

                Button(action: refreshLocations) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.primaryColor)
                        .clipShape(Circle())
                        .themeShadow(.small)
                }
                .accessibilityLabel("Refresh Locations")
                .accessibilityHint("Update family member locations")
            }
        }
        .padding(Theme.spacingM)
        .glassmorphism(material: Theme.glassmorphismThin, cornerRadius: 0)
        .themeShadow(.medium)
    }

    private var mapContent: some View {
        Map(position: $mapPosition) {
            // Current user's location with profile picture
            if let currentUser = currentUserProfile,
               let location = locationManager.currentLocation {
                Annotation(currentUser.username, coordinate: location.coordinate) {
                    ProfileLocationAnnotation(user: currentUser, isCurrentUser: true)
                }
            }
            
            // Family member annotations with profile pictures
            ForEach(familyMembers) { member in
                Annotation(member.username, coordinate: getMemberLocation(member)) {
                    ProfileLocationAnnotation(user: member, isCurrentUser: false)
                        .onTapGesture {
                            selectedMember = member
                        }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var mapOverlays: some View {
        VStack {
            // Top glassmorphism overlay
            HStack {
                Spacer()
                VStack(spacing: Theme.spacingS) {
                    if let park = locationManager.currentPark {
                        Text(park)
                            .font(Theme.captionFont)
                            .foregroundColor(.white)
                            .padding(.horizontal, Theme.spacingM)
                            .padding(.vertical, Theme.spacingS)
                            .glassmorphism(material: Theme.glassmorphismThick, cornerRadius: Theme.cornerRadiusM)
                    }

                    if let ride = locationManager.currentRide {
                        Text(ride)
                            .font(Theme.captionFont)
                            .foregroundColor(.white)
                            .padding(.horizontal, Theme.spacingM)
                            .padding(.vertical, Theme.spacingS)
                            .glassmorphism(material: Theme.glassmorphismThick, cornerRadius: Theme.cornerRadiusM)
                    }
                }
                .padding(.top, Theme.spacingL)
                .padding(.trailing, Theme.spacingM)
            }

            Spacer()

            // Bottom glassmorphism overlay
            LinearGradient(
                colors: [Color.black.opacity(0.3), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 100)
            .glassmorphism(material: Theme.glassmorphismThin, cornerRadius: 0)
            .allowsHitTesting(false)
        }
    }

    private var locationPermissionOverlay: some View {
        VStack {
            Spacer()
            Button(action: { locationManager.requestLocationPermission() }) {
                HStack {
                    Image(systemName: "location.slash.fill")
                    Text("Enable Location Access")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.bottom, 100)
        }
    }

    private var currentLocationButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: centerOnCurrentLocation) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.primaryColor)
                        .clipShape(Circle())
                        .themeShadow(.medium)
                }
                .accessibilityLabel("Center on Current Location")
                .accessibilityHint("Move map to your current position")
                .padding(.trailing, Theme.spacingM)
                .padding(.bottom, 100)
            }
        }
    }

    private var mapSection: some View {
        ZStack {
            mapContent
                .overlay(mapOverlays)

            // Location permission button
            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                locationPermissionOverlay
            }

            // Current location button
            currentLocationButton
        }
    }

    private var familyMemberList: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.spacingM) {
                    ForEach(familyMembers) { member in
                        FamilyMemberCard(
                            member: member,
                            onPing: { pingMember(member) }
                        )
                        .offset(y: isVisible ? 0 : 20)
                        .opacity(isVisible ? 1 : 0)
                        .onAppear {
                            withAnimation(Theme.springAnimation.delay(Double(familyMembers.firstIndex(of: member) ?? 0) * 0.1)) {
                                isVisible = true
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.spacingM)
            }
            .padding(.vertical, Theme.spacingM)
        }
        .background(Theme.backgroundPrimary)
        .glassmorphism(material: Theme.glassmorphismThin, cornerRadius: Theme.cornerRadiusL)
        .themeShadow(.medium)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            mapSection

            // Family member list with bottom sheet
            if !familyMembers.isEmpty {
                familyMemberList
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member)
        }
        .alert("Send Ping", isPresented: $showPingAlert) {
            TextField("Message (optional)", text: $pingMessage)
            Button("Send") {
                sendPing()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Send a location ping to \(selectedMember?.username ?? "family member")")
        }
        .onAppear {
            print("🏠 RadarView: onAppear - Starting initialization")
            loadFamilyMembers()
            locationManager.requestLocationPermission()
            setupHaptics()
            
            // Update map position to current location when available (only if significantly different)
            if let location = locationManager.currentLocation {
                print("📍 RadarView: Found current location, checking if map needs centering")
                
                // Get current center from map position
                let currentCenter: CLLocationCoordinate2D
                switch mapPosition {
                case .region(let region):
                    currentCenter = region.center
                case .camera(let camera):
                    currentCenter = camera.centerCoordinate
                default:
                    currentCenter = CLLocationCoordinate2D(latitude: 28.4177, longitude: -81.5812) // Default
                }
                
                let newCenter = location.coordinate
                
                // Only update if the distance is significant (more than ~100 meters)
                let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
                    .distance(from: CLLocation(latitude: newCenter.latitude, longitude: newCenter.longitude))
                
                if distance > 100 {
                    print("📍 RadarView: Centering map on current location (distance: \(Int(distance))m)")
                    withAnimation(.easeInOut(duration: 1.0)) {
                        mapPosition = .region(MKCoordinateRegion(
                            center: newCenter,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                }
            } else {
                print("⚠️ RadarView: No current location available")
            }
        }
        .sheet(isPresented: $showARView) {
            ARRadarView(familyMembers: familyMembers)
        }
    }
    
    private func loadFamilyMembers() {
        guard firebaseService.currentUser != nil else { 
            print("⚠️ RadarView: No current user, skipping family member load")
            return 
        }
        
        print("🔄 RadarView: Loading family members...")
        Task {
            do {
                let familyCode = try await firebaseService.getCurrentFamilyCode() ?? ""
                guard !familyCode.isEmpty else {
                    print("❌ RadarView: No family code found")
                    ErrorManager.shared.handleError("No family code found. Please check your profile.")
                    return
                }
                
                // Load current user profile
                if let currentUserId = firebaseService.currentUser?.uid {
                    let currentUser = try await firebaseService.getUserProfile(userId: currentUserId)
                    DispatchQueue.main.async {
                        self.currentUserProfile = currentUser
                    }
                }
                
                print("👥 RadarView: Fetching members for family code: \(familyCode)")
                let members = try await firebaseService.getFamilyMembers(familyCode: familyCode)
                print("✅ RadarView: Found \(members.count) family members")
                
                DispatchQueue.main.async {
                    // Filter members based on privacy settings and exclude current user
                    self.familyMembers = members.filter { 
                        $0.shareLocation && $0.id != firebaseService.currentUser?.uid 
                    }
                    print("📍 RadarView: \(self.familyMembers.count) members sharing location")
                }
            } catch {
                print("❌ RadarView: Error loading family members: \(error)")
                DispatchQueue.main.async {
                    ErrorManager.shared.handleError(error)
                }
            }
        }
    }
    
    private func refreshLocations() {
        loadFamilyMembers()
        centerOnCurrentLocation()
    }
    
    private func centerOnCurrentLocation() {
        if let location = locationManager.currentLocation {
            print("🎯 RadarView: Manually centering on current location")
            withAnimation(.easeInOut(duration: 1.0)) {
                mapPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        } else {
            print("⚠️ RadarView: Cannot center - no location available, requesting permission")
            // Request location permission if not available
            locationManager.requestLocationPermission()
        }
    }
    
    private func getMemberLocation(_ member: UserProfile) -> CLLocationCoordinate2D {
        // In a real app, this would come from the member's actual location
        // For demo purposes, we'll use consistent locations based on member ID
        
        // If we already have a location for this member, use it
        if let existingLocation = memberLocations[member.id] {
            return existingLocation
        }
        
        // Generate a consistent location based on member ID hash
        let baseLat = 28.4177  // Disney World center
        let baseLon = -81.5812
        let hash = member.id.hashValue
        let normalizedHash = Double(abs(hash % 1000)) / 1000.0  // 0.0 to 1.0
        
        // Create consistent but varied locations around Disney World
        let angle = normalizedHash * 2 * Double.pi
        let distance = 0.005 + (normalizedHash * 0.005)  // 0.5km to 1km radius
        
        let latitude = baseLat + distance * cos(angle)
        let longitude = baseLon + distance * sin(angle)
        
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        memberLocations[member.id] = location  // Cache it
        
        return location
    }
    
    private func pingMember(_ member: UserProfile) {
        guard firebaseService.currentUser != nil else { return }
        selectedMember = member
        showPingAlert = true
    }
    
    private func sendPing() {
        guard let member = selectedMember, let user = firebaseService.currentUser else { return }
        
        Task {
            do {
                try await firebaseService.sendPingNotification(
                    to: member.id,
                    from: user.uid,
                    message: pingMessage
                )
                
                DispatchQueue.main.async {
                    // Trigger haptic feedback
                    triggerHaptic()
                    
                    // Reset state
                    selectedMember = nil
                    pingMessage = ""
                    
                    // Show success feedback
                    // You could add a toast notification here
                }
            } catch {
                print("Failed to send ping: \(error)")
            }
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Failed to start haptic engine: \(error)")
        }
    }
    
    private func triggerHaptic() {
        guard let engine = engine else { return }
        
        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to trigger haptic: \(error)")
        }
    }
}

struct MemberAnnotationView: View {
    let member: UserProfile
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.spacingXS) {
                AsyncImage(url: URL(string: member.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundColor(Theme.primaryColor)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .themeShadow(.small)
                
                Text(member.username)
                    .font(Theme.captionFont)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .scaleEffect(1.0)
            .animation(Theme.springAnimation, value: member.id)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FamilyMemberCard: View {
    let member: UserProfile
    let onPing: () -> Void
    @State private var isPressed = false
    
    // Different colors for different family members
    private var memberColor: Color {
        let colors: [Color] = [.purple, .orange, .green, .pink, .cyan, .yellow]
        let index = abs(member.id.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        VStack(spacing: Theme.spacingS) {
            // Profile picture with colored ring
            Group {
                if let avatarURL = member.avatarURL, !avatarURL.isEmpty {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        UserInitialsView(username: member.username)
                    }
                } else {
                    UserInitialsView(username: member.username)
                }
            }
            .frame(width: 55, height: 55)
            .clipShape(Circle())
            .overlay(Circle().stroke(memberColor, lineWidth: 3))
            .themeShadow(.small)
            
            Text(member.username)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Button(action: onPing) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(memberColor)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(Theme.springAnimation, value: isPressed)
            }
            .accessibilityLabel("Send location ping to \(member.username)")
            .accessibilityHint("Tap to send a location ping")
            .onTapGesture {
                withAnimation(Theme.springAnimation) {
                    isPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(Theme.springAnimation) {
                        isPressed = false
                    }
                }
            }
        }
        .frame(width: 85)
        .padding(.vertical, Theme.spacingS)
        .background(Theme.backgroundSecondary)
        .cornerRadius(Theme.cornerRadiusM)
        .themeShadow(.small)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(Theme.springAnimation, value: isPressed)
    }
}

struct MemberDetailView: View {
    let member: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AsyncImage(url: URL(string: member.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                
                VStack(spacing: 8) {
                    Text(member.username)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(member.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("Member since \(member.createdAt, style: .date)")
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.green)
                        Text("Last active \(member.lastActive, style: .relative)")
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Member Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func getMemberLocation(member: UserProfile) -> CLLocationCoordinate2D {
        // Stub: In real implementation, fetch from Firestore "locations" collection or UserProfile
        // For demo, return random coordinates near default location
        return CLLocationCoordinate2D(latitude: 28.4177 + Double.random(in: -0.01...0.01),
                                      longitude: -81.5812 + Double.random(in: -0.01...0.01))
    }
}

#Preview {
    RadarView()
        .environmentObject(FirebaseService.shared)
}
