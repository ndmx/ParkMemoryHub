import CoreLocation
import PhotosUI
import SwiftUI

struct MemoriesRoute: View {
    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        MemoriesView(
            repository: dependencies.memories,
            familyRepository: dependencies.family,
            activeGroup: dependencies.activeGroup,
            circleSync: dependencies.circleSync
        )
    }
}

struct MemoriesView: View {
    private let cardWidth: CGFloat = 168

    @StateObject private var viewModel: MemoriesViewModel
    @State private var isShowingNewMemory = false
    @State private var selectedMemory: ParkMemory?
    @State private var searchText = ""

    init(
        repository: (any MemoryRepository)? = nil,
        familyRepository: (any FamilyRepository)? = nil,
        activeGroup: GroupSpace? = nil,
        circleSync: (any CircleSyncing)? = nil
    ) {
        let previewDependencies = AppDependencies.preview()
        let memoryRepository = repository ?? previewDependencies.memories
        let familyRepository = familyRepository ?? previewDependencies.family
        let activeGroup = activeGroup ?? previewDependencies.activeGroup
        let circleSync = circleSync ?? previewDependencies.circleSync
        _viewModel = StateObject(
            wrappedValue: MemoriesViewModel(
                repository: memoryRepository,
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
                    ProgressView("Loading memories...")
                } else if viewModel.memories.isEmpty {
                    MemoriesEmptyState {
                        isShowingNewMemory = true
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            MemoriesSummary(
                                memoryCount: viewModel.memories.count,
                                taggedCount: viewModel.memories.filter { !$0.tags.isEmpty }.count,
                                locatedCount: viewModel.memories.filter { $0.location != nil }.count
                            )

                            if filteredMemories.isEmpty {
                                ContentUnavailableView(
                                    "No Matches",
                                    systemImage: "magnifyingglass",
                                    description: Text("Try another caption, tag, or location.")
                                )
                                .padding(.top, 36)
                            } else {
                                LazyVGrid(columns: gridColumns, spacing: 14) {
                                    ForEach(filteredMemories) { memory in
                                        Button {
                                            selectedMemory = memory
                                        } label: {
                                            MemoryCard(memory: memory, creatorName: viewModel.creatorName(for: memory))
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                viewModel.deleteMemory(memory)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Memories")
            .searchable(text: $searchText, prompt: "Search memories")
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
                    .accessibilityLabel("Sync Memories with iCloud")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingNewMemory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Memory")
                }
            }
            .sheet(isPresented: $isShowingNewMemory) {
                NewMemoryView(isSaving: viewModel.isSaving) { caption, tags, location, mediaDataItems in
                    viewModel.createMemory(
                        caption: caption,
                        tags: tags,
                        location: location,
                        mediaDataItems: mediaDataItems
                    )
                }
            }
            .sheet(item: $selectedMemory) { memory in
                MemoryDetailView(memory: memory, creatorName: viewModel.creatorName(for: memory)) {
                    selectedMemory = nil
                    viewModel.deleteMemory(memory)
                }
            }
            .alert("Memory Error", isPresented: errorBinding) {
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
                Text(viewModel.statusMessage ?? "Memories synced.")
            }
            .onAppear {
                viewModel.loadMemories()
            }
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: 14)
        ]
    }

    private var filteredMemories: [ParkMemory] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return viewModel.memories
        }

        return viewModel.memories.filter { memory in
            memory.caption.localizedCaseInsensitiveContains(query)
                || memory.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                || memory.location?.name?.localizedCaseInsensitiveContains(query) == true
                || memory.location?.areaName?.localizedCaseInsensitiveContains(query) == true
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

private struct MemoriesSummary: View {
    let memoryCount: Int
    let taggedCount: Int
    let locatedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Highlights")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                MemoryMetric(title: "Saved", value: "\(memoryCount)", systemImage: "photo.stack", tint: .blue)
                MemoryMetric(title: "Tagged", value: "\(taggedCount)", systemImage: "tag.fill", tint: .purple)
                MemoryMetric(title: "Places", value: "\(locatedCount)", systemImage: "mappin.and.ellipse", tint: .green)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct MemoryMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MemoriesEmptyState: View {
    let addMemory: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Highlights Yet", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Save your first memory with photos, a caption, and an optional location to start your shared highlights.")
        } actions: {
            Button {
                addMemory()
            } label: {
                Label("Add Memory", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

private struct MemoryCard: View {
    private let cardWidth: CGFloat = 168
    private let mediaHeight: CGFloat = 148
    private let cardHeight: CGFloat = 286

    let memory: ParkMemory
    let creatorName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                MemoryMediaPreview(memory: memory, contentMode: .fill)
                    .frame(width: cardWidth - 20, height: mediaHeight)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if memory.displayMediaItems.count > 1 {
                    Label("\(memory.displayMediaItems.count)", systemImage: "photo.stack.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.62), in: Capsule())
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(memory.caption.isEmpty ? "Untitled memory" : memory.caption)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42, alignment: .topLeading)

                HStack(spacing: 5) {
                    Image(systemName: "person.crop.circle")
                    Text(creatorName.map { "Added by \($0)" } ?? "Added on this device")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                    Text(memory.createdAt, style: .date)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let place = memory.location?.name {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(place)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if !memory.tags.isEmpty {
                    Text(memory.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)

            Spacer(minLength: 0)
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .top)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.secondary.opacity(0.12))
        )
    }
}

@MainActor
private final class MemoryLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
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
            let namedLocation = await parkLocation(from: location)
            currentLocation = namedLocation
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

private struct CurrentLocationStatusView: View {
    @ObservedObject var locationProvider: MemoryLocationProvider

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

private struct NewMemoryView: View {
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
    @StateObject private var locationProvider = MemoryLocationProvider()
    @State private var caption = ""
    @State private var tagText = ""
    @State private var locationMode: LocationMode = .none
    @State private var customPlaceName = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhotoDataItems: [Data] = []
    @State private var selectedImages: [UIImage] = []

    let isSaving: Bool
    let onCreate: (String, [String], ParkLocation?, [Data]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Photos") {
                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 12, matching: .images) {
                        if let selectedImage = selectedImages.first {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))

                                if selectedImages.count > 1 {
                                    Label("\(selectedImages.count)", systemImage: "photo.stack.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(.black.opacity(0.62), in: Capsule())
                                        .padding(10)
                                }
                            }
                        } else {
                            Label("Choose Photos", systemImage: "photo.badge.plus")
                                .frame(maxWidth: .infinity, minHeight: 110)
                        }
                    }
                    .buttonStyle(.plain)

                    if selectedImages.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { _, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 54, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if !selectedPhotoDataItems.isEmpty {
                        Button(role: .destructive) {
                            selectedPhotoItems = []
                            selectedPhotoDataItems = []
                            selectedImages = []
                        } label: {
                            Label("Remove Photos", systemImage: "xmark.circle")
                        }
                    }
                }

                Section("Memory") {
                    TextField("Caption", text: $caption, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)

                    TextField("Tags separated by commas", text: $tagText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
                        CurrentLocationStatusView(locationProvider: locationProvider)
                    case .custom:
                        TextField("Place name", text: $customPlaceName)
                    }
                }
            }
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onCreate(caption, parsedTags, location, selectedPhotoDataItems)
                        dismiss()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!canCreate || isSaving)
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                loadPhotos(from: newItems)
            }
            .onChange(of: locationMode) { _, newMode in
                if newMode == .current, locationProvider.currentLocation == nil {
                    locationProvider.requestCurrentLocation()
                }
            }
        }
    }

    private var canCreate: Bool {
        let hasMemoryContent = !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedPhotoDataItems.isEmpty
        let hasRequiredLocation = locationMode != .current || locationProvider.currentLocation != nil
        return hasMemoryContent && hasRequiredLocation
    }

    private var parsedTags: [String] {
        tagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            var loadedData: [Data] = []
            var loadedImages: [UIImage] = []

            for item in items {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        continue
                    }

                    loadedData.append(data)
                    loadedImages.append(image)
                } catch {
                    continue
                }
            }

            selectedPhotoDataItems = loadedData
            selectedImages = loadedImages
        }
    }
}

private struct MemoryDetailView: View {
    let memory: ParkMemory
    let creatorName: String?
    let deleteMemory: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if memory.displayMediaItems.count > 1 {
                        TabView {
                            ForEach(memory.displayMediaItems) { item in
                                MemoryMediaPreview(mediaItem: item, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .padding(.horizontal, 1)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .frame(height: 320)
                    } else {
                        MemoryMediaPreview(memory: memory, contentMode: .fit)
                            .aspectRatio(4 / 3, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(memory.caption.isEmpty ? "Untitled memory" : memory.caption)
                            .font(.title2.weight(.semibold))

                        Text(memory.createdAt, format: .dateTime.weekday().month().day().hour().minute())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Label(creatorName.map { "Added by \($0)" } ?? "Added on this device", systemImage: "person.crop.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if memory.displayMediaItems.count > 1 {
                            Text("\(memory.displayMediaItems.count) photos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let location = memory.location {
                        DetailBlock(title: "Location") {
                            Text([location.name, location.areaName].compactMap { $0 }.joined(separator: ", "))
                                .foregroundStyle(.secondary)

                            if let latitude = location.latitude, let longitude = location.longitude {
                                Text(String(format: "%.4f, %.4f", latitude, longitude))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if !memory.tags.isEmpty {
                        DetailBlock(title: "Tags") {
                            FlowTagList(tags: memory.tags)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        deleteMemory()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete Memory")
                }
            }
        }
    }
}

private struct MemoryMediaPreview: View {
    enum ContentMode {
        case fill
        case fit
    }

    private let mediaKind: ParkMemory.MediaKind
    private let mediaURL: URL?
    private let hasMediaReference: Bool
    var contentMode: ContentMode = .fill

    init(memory: ParkMemory, contentMode: ContentMode = .fill) {
        let item = memory.displayMediaItems.first
        self.mediaKind = item?.kind ?? memory.mediaKind
        self.mediaURL = item?.localFileURL ?? memory.localFileURL
        self.hasMediaReference = item?.localFileURL != nil
            || item?.localMediaFilename != nil
            || memory.localFileURL != nil
            || memory.localMediaFilename != nil
        self.contentMode = contentMode
    }

    init(mediaItem: ParkMemory.MediaItem, contentMode: ContentMode = .fill) {
        self.mediaKind = mediaItem.kind
        self.mediaURL = mediaItem.localFileURL
        self.hasMediaReference = mediaItem.localFileURL != nil || mediaItem.localMediaFilename != nil
        self.contentMode = contentMode
    }

    var body: some View {
        GeometryReader { proxy in
            if let image = localImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledForMemoryPreview(contentMode)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                Rectangle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: mediaKind == .photo ? "photo" : "video")
                                .font(.system(size: 34))
                                .foregroundStyle(.blue)

                            if hasMediaReference {
                                Text("Photo unavailable")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
            }
        }
        .clipped()
    }

    private var localImage: UIImage? {
        guard let url = mediaURL else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return UIImage(data: data)
    }
}

private extension Image {
    @ViewBuilder
    func scaledForMemoryPreview(_ contentMode: MemoryMediaPreview.ContentMode) -> some View {
        switch contentMode {
        case .fill:
            self.scaledToFill()
        case .fit:
            self.scaledToFit()
        }
    }
}

private struct DetailBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlowTagList: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1), in: Capsule())
            }
        }
    }
}

#Preview {
    let repository = InMemoryMemoryRepository(memories: [
        ParkMemory(
            caption: "Favorite afternoon moment",
            tags: ["family", "highlights"],
            location: ParkLocation(
                name: "Riverfront"
            )
        )
    ])

    MemoriesView(repository: repository)
}
