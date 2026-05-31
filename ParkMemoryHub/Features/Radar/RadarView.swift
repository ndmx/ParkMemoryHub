import CoreLocation
import SwiftUI

struct RadarRoute: View {
    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        RadarView(
            familyRepository: dependencies.family,
            activeGroup: dependencies.activeGroup,
            circleSync: dependencies.circleSync
        )
    }
}

struct RadarView: View {
    @Environment(\.openURL) private var openURL

    @StateObject private var viewModel: RadarViewModel
    @StateObject private var locationProvider = RadarLocationProvider()

    init(
        familyRepository: any FamilyRepository,
        activeGroup: GroupSpace,
        circleSync: any CircleSyncing
    ) {
        _viewModel = StateObject(
            wrappedValue: RadarViewModel(
                familyRepository: familyRepository,
                activeGroup: activeGroup,
                circleSync: circleSync
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading circle...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            RadarSummary(
                                group: viewModel.activeGroup,
                                members: viewModel.members,
                                currentMember: viewModel.currentMember
                            )

                            CurrentRadarLocationCard(
                                locationProvider: locationProvider,
                                currentMember: viewModel.currentMember,
                                isSavingLocation: viewModel.isSavingLocation
                            )

                            VStack(spacing: 10) {
                                ForEach(viewModel.members) { member in
                                    FamilyMemberCard(
                                        member: member,
                                        currentMember: viewModel.currentMember,
                                        openMap: {
                                            openMap(for: member)
                                        },
                                        toggleSharing: {
                                            viewModel.toggleSharing(for: member)
                                        }
                                    )
                                    .accessibilityLabel(accessibilityLabel(for: member))
                                    .accessibilityAction(named: Text("Open in Maps")) {
                                        openMap(for: member)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Radar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.loadMembers()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh Radar")
                }
            }
            .alert("Radar Error", isPresented: errorBinding) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong.")
            }
            .onAppear {
                viewModel.loadMembers()
            }
            .onChange(of: locationProvider.currentLocation) { _, location in
                guard let location else { return }
                viewModel.updateCurrentLocation(location)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private func openMap(for member: FamilyMember) {
        guard member.sharesLocation else {
            viewModel.errorMessage = "\(member.displayName) is not sharing location."
            return
        }

        guard let mapURL = member.appleMapsURL else {
            viewModel.errorMessage = "Location coordinates are unavailable for \(member.displayName)."
            return
        }

        openURL(mapURL)
    }

    private func accessibilityLabel(for member: FamilyMember) -> String {
        if member.sharesLocation, member.lastKnownLocation?.hasCoordinates == true {
            return "Open \(member.displayName) in Maps"
        }

        return "\(member.displayName) location unavailable"
    }
}

@MainActor
private final class RadarLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var currentLocation: ParkLocation?
    @Published private(set) var isRequestingLocation = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var shouldRequestLocationAfterAuthorization = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestCurrentLocation() {
        errorMessage = nil
        shouldRequestLocationAfterAuthorization = true

        switch locationManager.authorizationStatus {
        case .notDetermined:
            isRequestingLocation = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isRequestingLocation = true
            locationManager.requestLocation()
        case .denied, .restricted:
            isRequestingLocation = false
            errorMessage = "Location access is off. You can enable it in Settings."
        @unknown default:
            isRequestingLocation = false
            errorMessage = "Location is unavailable right now."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard shouldRequestLocationAfterAuthorization else { return }

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                isRequestingLocation = false
                errorMessage = "Location access is off. You can enable it in Settings."
            case .notDetermined:
                break
            @unknown default:
                isRequestingLocation = false
                errorMessage = "Location is unavailable right now."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            currentLocation = await parkLocation(from: location)
            isRequestingLocation = false
            shouldRequestLocationAfterAuthorization = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isRequestingLocation = false
            errorMessage = "Unable to get your location. Please try again."
        }
    }

    private func parkLocation(from location: CLLocation) async -> ParkLocation {
        let coordinate = location.coordinate

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            let placeName = placemark?.name ?? placemark?.subLocality ?? placemark?.locality
            let areaName = [placemark?.locality, placemark?.administrativeArea]
                .compactMap { $0 }
                .joined(separator: ", ")

            return ParkLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                name: placeName,
                areaName: areaName.isEmpty ? nil : areaName
            )
        } catch {
            return ParkLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                name: "Current Location"
            )
        }
    }
}

private struct RadarSummary: View {
    let group: GroupSpace
    let members: [FamilyMember]
    let currentMember: FamilyMember?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.displayName)
                    .font(.title3.weight(.semibold))

                Text("Live circle locations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                SummaryMetric(
                    title: "Members",
                    value: "\(members.count)",
                    systemImage: "person.3.fill",
                    tint: .blue
                )

                SummaryMetric(
                    title: "Sharing",
                    value: "\(members.filter(\.sharesLocation).count)",
                    systemImage: "location.fill",
                    tint: .green
                )
            }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var statusText: String {
        guard let currentMember else {
            return "Load your group to see current sharing status."
        }

        if currentMember.sharesLocation {
            return "Your location is visible to this group while sharing is on."
        }

        return "Your location sharing is off."
    }
}

private struct CurrentRadarLocationCard: View {
    @ObservedObject var locationProvider: RadarLocationProvider
    let currentMember: FamilyMember?
    let isSavingLocation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 38, height: 38)
                    .background(.blue.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Your Location")
                        .font(.headline)

                    Text(currentLocationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if locationProvider.isRequestingLocation || isSavingLocation {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(locationProvider.isRequestingLocation ? "Getting your location..." : "Updating radar...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = locationProvider.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                locationProvider.requestCurrentLocation()
            } label: {
                Label("Update My Location", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(locationProvider.isRequestingLocation || isSavingLocation)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.secondary.opacity(0.12))
        )
    }

    private var currentLocationText: String {
        guard currentMember?.sharesLocation == true else {
            return "Sharing is off"
        }

        guard let location = currentMember?.lastKnownLocation else {
            return "No location shared yet"
        }

        let locationText = [location.name, location.areaName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        return locationText.isEmpty ? "Location shared" : locationText
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FamilyMemberCard: View {
    let member: FamilyMember
    let currentMember: FamilyMember?
    let openMap: () -> Void
    let toggleSharing: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(member.isCurrentUser ? .blue.opacity(0.14) : .purple.opacity(0.14))

                Text(initials)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(member.isCurrentUser ? .blue : .purple)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.headline)

                    if member.isCurrentUser {
                        Text("This Device")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.blue.opacity(0.1), in: Capsule())
                    }
                }

                Text(locationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let distanceText {
                    Text(distanceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastSeenAt = member.lastSeenAt {
                    Text("Last seen \(lastSeenAt, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isCurrentMember {
                Button {
                    toggleSharing()
                } label: {
                    Image(systemName: member.sharesLocation ? "location.fill" : "location.slash")
                        .foregroundStyle(member.sharesLocation ? .green : .secondary)
                        .frame(width: 36, height: 36)
                        .background(.secondary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(member.sharesLocation ? "Turn Off My Location Sharing" : "Turn On My Location Sharing")
                .accessibilityAddTraits(.isButton)
            } else {
                Image(systemName: member.sharesLocation ? "location.fill" : "location.slash")
                    .foregroundStyle(member.sharesLocation ? .green : .secondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.secondary.opacity(0.12))
        )
        .overlay(alignment: .bottomTrailing) {
            if canOpenInMaps {
                Label("Map", systemImage: "map")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .padding(12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openMap()
        }
    }

    private var isCurrentMember: Bool {
        member.id == currentMember?.id
    }

    private var canOpenInMaps: Bool {
        member.sharesLocation && member.lastKnownLocation?.hasCoordinates == true
    }

    private var initials: String {
        member.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var locationText: String {
        guard member.sharesLocation else {
            return "Location sharing is off"
        }

        guard let location = member.lastKnownLocation else {
            return "No location yet"
        }

        return [location.name, location.areaName]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var distanceText: String? {
        guard !isCurrentMember,
              member.sharesLocation,
              currentMember?.sharesLocation == true,
              let memberLocation = member.lastKnownLocation?.coreLocation,
              let currentLocation = currentMember?.lastKnownLocation?.coreLocation else {
            return nil
        }

        let distance = memberLocation.distance(from: currentLocation)
        if distance < 1609.34 {
            let feet = distance * 3.28084
            return "\(Int(feet.rounded())) ft from you"
        }

        let miles = distance / 1609.34
        return String(format: "%.1f mi from you", miles)
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    RadarView(
        familyRepository: dependencies.family,
        activeGroup: dependencies.activeGroup,
        circleSync: dependencies.circleSync
    )
}

private extension ParkLocation {
    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var coreLocation: CLLocation? {
        guard let latitude, let longitude else {
            return nil
        }

        return CLLocation(latitude: latitude, longitude: longitude)
    }
}

private extension FamilyMember {
    var appleMapsURL: URL? {
        guard let latitude = lastKnownLocation?.latitude,
              let longitude = lastKnownLocation?.longitude else {
            return nil
        }

        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: displayName)
        ]
        return components?.url
    }
}
