import CoreLocation
import SwiftUI

struct PlannerRoute: View {
    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        PlannerView(
            activitiesRepository: dependencies.activities,
            familyRepository: dependencies.family,
            activeGroup: dependencies.activeGroup,
            circleSync: dependencies.circleSync
        )
    }
}

struct PlannerView: View {
    @StateObject private var viewModel: PlannerViewModel
    @State private var isShowingNewActivity = false
    @State private var selectedActivity: ParkActivity?

    init(
        activitiesRepository: any ActivityRepository,
        familyRepository: any FamilyRepository,
        activeGroup: GroupSpace,
        circleSync: any CircleSyncing
    ) {
        _viewModel = StateObject(
            wrappedValue: PlannerViewModel(
                activitiesRepository: activitiesRepository,
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
                    ProgressView("Loading plans...")
                } else if viewModel.activities.isEmpty {
                    PlannerEmptyState {
                        isShowingNewActivity = true
                    }
                } else {
                    List {
                        PlannerSummary(
                            activities: viewModel.activities,
                            memberCount: viewModel.members.count
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                        ForEach(viewModel.activities) { activity in
                            Button {
                                selectedActivity = activity
                            } label: {
                                ActivityRow(
                                    activity: activity,
                                    currentMemberID: viewModel.currentMember?.id,
                                    creatorName: viewModel.creatorName(for: activity),
                                    memberCount: viewModel.members.count,
                                    onVote: { vote in
                                        viewModel.vote(on: activity, vote: vote)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteActivity(activity)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.bottom, 24, for: .scrollContent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appScreenBackground(.chrome)
            .navigationTitle("Planner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.syncWithICloud()
                    } label: {
                        if viewModel.isSyncingICloud {
                            ProgressView()
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                    }
                    .disabled(viewModel.isSyncingICloud)
                    .accessibilityLabel("Sync Planner with iCloud")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingNewActivity = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Plan")
                }
            }
            .sheet(isPresented: $isShowingNewActivity) {
                NewActivityView(
                    members: viewModel.members,
                    currentMemberID: viewModel.currentMember?.id
                ) { title, notes, scheduledAt, location, visibility, sharedWithMemberIDs in
                    viewModel.createActivity(
                        title: title,
                        notes: notes,
                        scheduledAt: scheduledAt,
                        location: location,
                        visibility: visibility,
                        sharedWithMemberIDs: sharedWithMemberIDs
                    )
                }
            }
            .sheet(item: $selectedActivity) { activity in
                let currentActivity = viewModel.activities.first { $0.id == activity.id } ?? activity
                ActivityDetailView(
                    activity: currentActivity,
                    currentMemberID: viewModel.currentMember?.id,
                    creatorName: viewModel.creatorName(for: currentActivity),
                    memberNamesByID: viewModel.memberNamesByID,
                    memberCount: viewModel.members.count,
                    onVote: { vote in
                        viewModel.vote(on: currentActivity, vote: vote)
                    },
                    onStatusChange: { status in
                        viewModel.updateStatus(for: currentActivity, status: status)
                    }
                )
            }
            .alert("Planner Error", isPresented: errorBinding) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong.")
            }
            .alert("iCloud Sync", isPresented: statusBinding) {
                Button("OK") {
                    viewModel.statusMessage = nil
                }
            } message: {
                Text(viewModel.statusMessage ?? "Planner synced.")
            }
            .onAppear {
                viewModel.load()
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

    private var statusBinding: Binding<Bool> {
        Binding(
            get: { viewModel.statusMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.statusMessage = nil
                }
            }
        )
    }
}

private struct PlannerSummary: View {
    let activities: [ParkActivity]
    let memberCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Lumina.Space.sm) {
            Text("Group plans")
                .font(Lumina.Typo.display(26, weight: .semibold))
                .foregroundStyle(Lumina.Color.textPrimary)

            HStack(spacing: Lumina.Space.sm) {
                PlannerMetric(title: "Plans", value: "\(activities.count)", systemImage: "calendar", tint: Lumina.Status.info)
                PlannerMetric(title: "Confirmed", value: "\(confirmedCount)", systemImage: "checkmark.seal.fill", tint: Lumina.Status.success)
                PlannerMetric(title: "Members", value: "\(memberCount)", systemImage: "person.3.fill", tint: Lumina.Status.highlight)
            }

            if let nextPlan {
                Label {
                    Text("Next: \(nextPlan.title)")
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var confirmedCount: Int {
        activities.filter { $0.status == .confirmed }.count
    }

    private var nextPlan: ParkActivity? {
        activities.first { $0.scheduledAt != nil && $0.status != .completed && $0.status != .cancelled }
    }
}

private struct PlannerMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Lumina.Space.xs) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: Circle())

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Lumina.Color.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundStyle(Lumina.Color.textSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Lumina.Space.sm)
        .background(Lumina.Color.overlay, in: RoundedRectangle(cornerRadius: Lumina.Radius.md, style: .continuous))
    }
}

private struct PlannerEmptyState: View {
    let addActivity: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 54))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No Plans Yet")
                    .font(.title3.weight(.semibold))

                Text("Add your first plan to organize rides, meals, meetup spots, or anything your circle should track.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                addActivity()
            } label: {
                Label("Add Plan", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .appReadableSurface(cornerRadius: 18)
        .padding(24)
    }
}

private struct ActivityRow: View {
    let activity: ParkActivity
    let currentMemberID: FamilyMember.ID?
    let creatorName: String?
    let memberCount: Int
    let onVote: (ParkActivity.Vote) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.title)
                        .font(.headline)

                    if !activity.notes.isEmpty {
                        Text(activity.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Text(creatorName.map { "Added by \($0)" } ?? "Added on this device")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(activity.visibility.title, systemImage: activity.visibility.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(activity.status.rawValue.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 8) {
                if let scheduledAt = activity.scheduledAt {
                    Label {
                        Text(scheduledAt, format: .dateTime.month().day().hour().minute())
                    } icon: {
                        Image(systemName: "clock")
                    }
                }

                if let place = activity.location?.name {
                    Label(place, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Label("\(activity.yesVoteCount) of \(memberCount) yes", systemImage: "person.2.fill")
                    .foregroundStyle(Lumina.Status.success)

                if activity.votesByMemberID.isEmpty {
                    Text("No votes yet")
                        .foregroundStyle(Lumina.Color.textSubtle)
                }
            }
            .font(.caption)

            HStack(spacing: 8) {
                ForEach(ParkActivity.Vote.allCases, id: \.self) { vote in
                    Button {
                        onVote(vote)
                    } label: {
                        HStack(spacing: 4) {
                            Text(vote.title)
                            Text("\(count(for: vote))")
                        }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(isSelected(vote) ? Lumina.Color.onAccent : vote.color)
                        .background(isSelected(vote) ? vote.color : vote.color.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Lumina.Space.md)
        .appGlassBlock(cornerRadius: 16)
    }

    private var statusColor: Color {
        activity.status.color
    }

    private func count(for vote: ParkActivity.Vote) -> Int {
        activity.votesByMemberID.values.filter { $0 == vote }.count
    }

    private func isSelected(_ vote: ParkActivity.Vote) -> Bool {
        guard let currentMemberID else { return false }
        return activity.votesByMemberID[currentMemberID] == vote
    }
}

private struct NewActivityView: View {
    private enum LocationMode: String, CaseIterable {
        case none
        case current
        case custom

        var title: String {
            switch self {
            case .none:
                return "None"
            case .current:
                return "Current"
            case .custom:
                return "Custom"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationProvider = PlanLocationProvider()
    @State private var title = ""
    @State private var notes = ""
    @State private var includeDate = true
    @State private var scheduledAt = Date()
    @State private var locationMode: LocationMode = .none
    @State private var customPlaceName = ""
    @State private var visibility: ParkActivity.Visibility = .circle
    @State private var selectedMemberIDs = Set<FamilyMember.ID>()

    let members: [FamilyMember]
    let currentMemberID: FamilyMember.ID?
    let onCreate: (String, String, Date?, ParkLocation?, ParkActivity.Visibility, [FamilyMember.ID]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    TextField("Plan title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Time") {
                    Toggle("Add a time", isOn: $includeDate)

                    if includeDate {
                        DatePicker("When", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Location") {
                    Picker("Location", selection: $locationMode) {
                        ForEach(LocationMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch locationMode {
                    case .none:
                        EmptyView()
                    case .current:
                        PlanCurrentLocationStatusView(locationProvider: locationProvider)
                    case .custom:
                        TextField("Place name", text: $customPlaceName)
                    }
                }

                Section("Share") {
                    Picker("Share", selection: $visibility) {
                        ForEach(ParkActivity.Visibility.allCases, id: \.self) { visibility in
                            Text(visibility.title).tag(visibility)
                        }
                    }

                    if visibility == .selectedMembers {
                        if shareableMembers.isEmpty {
                            Text("Add members to this circle before choosing specific people.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(shareableMembers) { member in
                                Toggle(member.displayName, isOn: selectedBinding(for: member.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if locationMode == .current, locationProvider.currentLocation == nil {
                            locationProvider.requestCurrentLocation()
                            return
                        }

                        onCreate(
                            title,
                            notes,
                            includeDate ? scheduledAt : nil,
                            location,
                            visibility,
                            visibility == .selectedMembers ? Array(selectedMemberIDs) : []
                        )
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
            .onChange(of: locationMode) { _, newMode in
                if newMode == .current, locationProvider.currentLocation == nil {
                    locationProvider.requestCurrentLocation()
                }
            }
        }
    }

    private var canCreate: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRequiredLocation = locationMode != .current || locationProvider.currentLocation != nil
        return hasTitle && hasRequiredLocation
    }

    private var shareableMembers: [FamilyMember] {
        members.filter { member in
            member.id != currentMemberID
        }
    }

    private func selectedBinding(for memberID: FamilyMember.ID) -> Binding<Bool> {
        Binding(
            get: { selectedMemberIDs.contains(memberID) },
            set: { isSelected in
                if isSelected {
                    selectedMemberIDs.insert(memberID)
                } else {
                    selectedMemberIDs.remove(memberID)
                }
            }
        )
    }

    private var location: ParkLocation? {
        switch locationMode {
        case .none:
            return nil
        case .current:
            return locationProvider.currentLocation
        case .custom:
            let cleanPlaceName = customPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanPlaceName.isEmpty else {
                return nil
            }

            return ParkLocation(name: cleanPlaceName)
        }
    }
}

@MainActor
private final class PlanLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
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
            errorMessage = "Location access is off. You can enable it in Settings or enter a place name."
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
                errorMessage = "Location access is off. You can enable it in Settings or enter a place name."
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
            errorMessage = "Unable to get your location. You can try again or enter a place name."
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

private struct PlanCurrentLocationStatusView: View {
    @ObservedObject var locationProvider: PlanLocationProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if locationProvider.isRequestingLocation {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Getting your location...")
                        .foregroundStyle(.secondary)
                }
            } else if let location = locationProvider.currentLocation {
                Label(locationTitle(location), systemImage: "location.fill")
                    .foregroundStyle(.primary)

                Button {
                    locationProvider.requestCurrentLocation()
                } label: {
                    Label("Update Location", systemImage: "arrow.clockwise")
                }
            } else {
                Button {
                    locationProvider.requestCurrentLocation()
                } label: {
                    Label("Use Current Location", systemImage: "location")
                }
            }

            if let errorMessage = locationProvider.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func locationTitle(_ location: ParkLocation) -> String {
        let nameParts = [location.name, location.areaName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        if nameParts.isEmpty {
            return "Current Location"
        }

        return nameParts.joined(separator: ", ")
    }
}

private struct ActivityDetailView: View {
    let activity: ParkActivity
    let currentMemberID: FamilyMember.ID?
    let creatorName: String?
    let memberNamesByID: [FamilyMember.ID: String]
    let memberCount: Int
    let onVote: (ParkActivity.Vote) -> Void
    let onStatusChange: (ParkActivity.Status) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Plan") {
                    Text(activity.title)
                    if !activity.notes.isEmpty {
                        Text(activity.notes)
                    }

                    Label(creatorName.map { "Added by \($0)" } ?? "Added on this device", systemImage: "person.crop.circle")
                        .foregroundStyle(.secondary)
                }

                Section("Sharing") {
                    Label(activity.visibility.title, systemImage: activity.visibility.systemImage)
                        .foregroundStyle(.secondary)

                    if activity.visibility == .selectedMembers {
                        let names = sharedMemberNames
                        Text(names.isEmpty ? "Only selected members" : names.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }

                if let scheduledAt = activity.scheduledAt {
                    Section("Time") {
                        Text(scheduledAt, format: .dateTime.weekday().month().day().hour().minute())
                    }
                }

                if let location = activity.location {
                    Section("Location") {
                        Text([location.name, location.areaName].compactMap { $0 }.joined(separator: ", "))
                        if let latitude = location.latitude, let longitude = location.longitude {
                            Text(String(format: "%.4f, %.4f", latitude, longitude))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Status") {
                    ForEach(ParkActivity.Status.allCases, id: \.self) { status in
                        Button {
                            onStatusChange(status)
                        } label: {
                            HStack {
                                Label(status.title, systemImage: status.systemImage)
                                    .foregroundStyle(status.color)

                                Spacer()

                                if activity.status == status {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(status.color)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Votes") {
                    HStack(spacing: 8) {
                        ForEach(ParkActivity.Vote.allCases, id: \.self) { vote in
                            Button {
                                onVote(vote)
                            } label: {
                                Text(vote.title)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .foregroundStyle(isCurrentVote(vote) ? Lumina.Color.onAccent : vote.color)
                                    .background(isCurrentVote(vote) ? vote.color : vote.color.opacity(0.14), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Label("\(activity.yesVoteCount) of \(memberCount) members voted yes", systemImage: "person.2.fill")
                        .foregroundStyle(.secondary)

                    ForEach(ParkActivity.Vote.allCases, id: \.self) { vote in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(vote.title)
                                Spacer()
                                Text("\(activity.votesByMemberID.values.filter { $0 == vote }.count)")
                                    .foregroundStyle(vote.color)
                            }

                            let voterNames = names(for: vote)
                            if !voterNames.isEmpty {
                                Text(voterNames.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func isCurrentVote(_ vote: ParkActivity.Vote) -> Bool {
        guard let currentMemberID else { return false }
        return activity.votesByMemberID[currentMemberID] == vote
    }

    private func names(for vote: ParkActivity.Vote) -> [String] {
        activity.votesByMemberID
            .filter { $0.value == vote }
            .map { memberID, _ in
                if memberID == currentMemberID {
                    return "You"
                }

                return memberNamesByID[memberID] ?? "Member"
            }
            .sorted()
    }

    private var sharedMemberNames: [String] {
        activity.sharedWithMemberIDs.map { memberID in
            if memberID == currentMemberID {
                return "You"
            }

            return memberNamesByID[memberID] ?? "Member"
        }
        .sorted()
    }
}

private extension ParkActivity.Status {
    var title: String {
        switch self {
        case .planned:
            return "Planned"
        case .confirmed:
            return "Confirmed"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }

    var systemImage: String {
        switch self {
        case .planned:
            return "calendar"
        case .confirmed:
            return "checkmark.seal.fill"
        case .completed:
            return "flag.checkered"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .planned:
            return Lumina.Status.pending
        case .confirmed:
            return Lumina.Status.success
        case .completed:
            return Lumina.Status.neutral
        case .cancelled:
            return Lumina.Status.danger
        }
    }
}

private extension ParkActivity.Vote {
    var title: String {
        switch self {
        case .yes:
            return "Yes"
        case .maybe:
            return "Maybe"
        case .no:
            return "No"
        }
    }

    var color: Color {
        switch self {
        case .yes:
            return Lumina.Status.success
        case .maybe:
            return Lumina.Status.warning
        case .no:
            return Lumina.Status.danger
        }
    }
}

private extension ParkActivity.Visibility {
    var title: String {
        switch self {
        case .circle:
            return "Circle"
        case .selectedMembers:
            return "Some Members"
        case .onlyMe:
            return "Only Me"
        }
    }

    var systemImage: String {
        switch self {
        case .circle:
            return "person.3.fill"
        case .selectedMembers:
            return "person.2.fill"
        case .onlyMe:
            return "person.fill"
        }
    }
}

#Preview {
    let group = GroupSpace(displayName: "Family Trip")
    let current = FamilyMember(groupID: group.id, displayName: "Me", isCurrentUser: true)
    let activity = ParkActivity(
        groupID: group.id,
        createdByMemberID: current.id,
        title: "Evening walk",
        notes: "Meet near the main entrance before dinner.",
        location: ParkLocation(
            name: "Main Entrance"
        ),
        scheduledAt: Date().addingTimeInterval(3600),
        votesByMemberID: [current.id: .yes]
    )

    PlannerView(
        activitiesRepository: InMemoryActivityRepository(activities: [activity]),
        familyRepository: InMemoryFamilyRepository(currentMember: current),
        activeGroup: group,
        circleSync: NoOpCircleSync()
    )
}
