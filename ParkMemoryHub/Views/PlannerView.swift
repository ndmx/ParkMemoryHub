import SwiftUI

struct PlannerView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var activities: [Activity] = []
    @State private var isLoading = false
    @State private var showNewActivitySheet = false
    @State private var selectedActivity: Activity?
    @State private var locationInfo: MediaItem.LocationInfo?
    @State private var familyCode: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Park Planner")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showNewActivitySheet = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background {
                            if #available(iOS 18.0, *) {
                                Theme.accentMeshGradient
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Theme.primaryColor)
                            }
                        }
                        .themeShadow(.medium)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading activities...")
                    .font(.headline)
                Spacer()
            } else if activities.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No activities planned yet!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text("Tap the + button to plan your first activity")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                VStack(spacing: 12) {
                    // Swipe hint for first time users
                    if activities.count > 0 {
                        HStack {
                            Text("💡 Swipe left on activities to delete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .opacity(0.7)
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                                ActivityCard(
                                    activity: activity,
                                    onVote: { voteType in
                                        voteOnActivity(activity, voteType: voteType)
                                    },
                                    onTap: {
                                        selectedActivity = activity
                                    },
                                    onDelete: {
                                        deleteActivityAtIndex(index)
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteActivityAtIndex(index)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showNewActivitySheet, onDismiss: {
            loadActivities()
        }) {
            NewActivityView()
                .zoomTransition()
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(Theme.cornerRadiusL)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedActivity) { activity in
            ActivityDetailView(activity: activity)
                .zoomTransition()
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(Theme.cornerRadiusL)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            loadActivities()
        }
        .refreshable {
            await loadActivitiesAsync()
        }
    }
    
    private func loadActivities() {
        Task {
            await loadActivitiesAsync()
        }
    }
    
    private func loadActivitiesAsync() async {
        guard firebaseService.currentUser != nil else { return }
        
        DispatchQueue.main.async {
            isLoading = true
        }
        
        do {
            familyCode = try await firebaseService.getCurrentFamilyCode() ?? ""
            let loadedActivities = try await firebaseService.getFamilyActivities(familyCode: familyCode)

            DispatchQueue.main.async {
                self.activities = self.sortActivities(loadedActivities)
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                // Handle error
            }
        }
    }
    
    private func voteOnActivity(_ activity: Activity, voteType: Activity.VoteType) {
        guard firebaseService.currentUser != nil else { return }
        
        // Haptic feedback for voting
        HapticManager.shared.vote(isPositive: voteType == .yes)
        
        Task {
            do {
                try await firebaseService.updateActivityVotes(
                    activityId: activity.id,
                    userId: firebaseService.currentUser!.uid,
                    vote: voteType
                )
                
                // Reload activities to show updated votes
                await loadActivitiesAsync()
                
                // Success feedback
                await MainActor.run {
                    HapticManager.shared.lightTap()
                }
            } catch {
                print("Failed to vote: \(error)")
                // Error feedback
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func deleteActivity(_ activity: Activity) {
        // Enhanced haptic feedback for delete action
        HapticManager.shared.deleteConfirm()
        
        Task {
            do {
                // Delete from Firebase
                try await firebaseService.deleteActivity(activity)
                
                // Update UI on main thread
                await MainActor.run {
                    activities.removeAll { $0.id == activity.id }
                    // Success haptic feedback
                    HapticManager.shared.success()
                }
            } catch {
                print("❌ Error deleting activity: \(error.localizedDescription)")
                // Error haptic feedback
                await MainActor.run {
                    HapticManager.shared.error()
                }
                // Could add an alert here for user feedback
            }
        }
    }
    
    private func deleteActivityAtIndex(_ index: Int) {
        guard index < activities.count else { return }
        let activity = activities[index]
        
        // Enhanced haptic feedback for delete action
        HapticManager.shared.deleteConfirm()
        
        Task {
            do {
                // Delete from Firebase
                try await firebaseService.deleteActivity(activity)
                
                // Update UI on main thread
                await MainActor.run {
                    activities.remove(at: index)
                    // Success haptic feedback
                    HapticManager.shared.success()
                }
            } catch {
                print("❌ Error deleting activity at index \(index): \(error.localizedDescription)")
                // Error haptic feedback
                await MainActor.run {
                    HapticManager.shared.error()
                }
                // Could add an alert here for user feedback
            }
        }
    }
    
    private func sortActivities(_ activities: [Activity]) -> [Activity] {
        return activities.sorted { activity1, activity2 in
            // First, prioritize activities with "yes" votes
            let activity1HasYes = activity1.votes.values.contains(.yes)
            let activity2HasYes = activity2.votes.values.contains(.yes)
            
            if activity1HasYes != activity2HasYes {
                return activity1HasYes && !activity2HasYes
            }
            
            // Then sort by scheduled time (earliest first)
            guard let time1 = activity1.scheduledTime,
                  let time2 = activity2.scheduledTime else {
                // If one has no time and other has time, prioritize the one with time
                if activity1.scheduledTime != nil { return true }
                if activity2.scheduledTime != nil { return false }
                // If both have no time, sort by creation time
                return activity1.createdAt > activity2.createdAt
            }
            
            return time1 < time2
        }
    }
}

struct ActivityCard: View {
    let activity: Activity
    let onVote: (Activity.VoteType) -> Void
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let description = activity.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        // Visible delete button
                        Button(action: {
                            onDelete()
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        
                        Text(activity.status.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .cornerRadius(8)
                        
                        if let scheduledTime = activity.scheduledTime {
                            Text(scheduledTime, style: .time)
                                .font(.caption)
                                .foregroundColor(isTimePast(scheduledTime) ? .red : .secondary)
                        }
                    }
                }
                
                // Location info
                if let location = activity.location {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if let parkName = location.parkName {
                                Text(parkName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            if let rideName = location.rideName {
                                Text(rideName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Voting section
                VStack(spacing: 12) {
                    HStack {
                        Text("Votes:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(activity.voteCount) / \(activity.totalVoters)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        VoteButton(
                            title: "Yes",
                            count: activity.votes.values.filter { $0 == .yes }.count,
                            isSelected: false, // You'd check if current user voted yes
                            color: .green
                        ) {
                            onVote(.yes)
                        }
                        
                        VoteButton(
                            title: "Maybe",
                            count: activity.votes.values.filter { $0 == .maybe }.count,
                            isSelected: false, // You'd check if current user voted maybe
                            color: .orange
                        ) {
                            onVote(.maybe)
                        }
                        
                        VoteButton(
                            title: "No",
                            count: activity.votes.values.filter { $0 == .no }.count,
                            isSelected: false, // You'd check if current user voted no
                            color: .red
                        ) {
                            onVote(.no)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch activity.status {
        case .planned: return .blue
        case .confirmed: return .green
        case .completed: return .purple
        case .cancelled: return .red
        }
    }
    
    private func isTimePast(_ time: Date) -> Bool {
        return time < Date()
    }
}

struct VoteButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : color)
                
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct NewActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var title = ""
    @State private var description = ""
    @State private var scheduledTime: Date = Date()
    @State private var includeLocation = false
    @State private var isCreating = false
    @State private var locationInfo: MediaItem.LocationInfo?
    @State private var familyCode: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Activity Details") {
                    TextField("Activity Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3)
                    
                    DatePicker("Scheduled Time", selection: $scheduledTime, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Location") {
                    Toggle("Include current location", isOn: $includeLocation)
                    
                    if includeLocation, let currentLocationInfo = locationInfo {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                if let parkName = currentLocationInfo.parkName {
                                    Text(parkName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                if let rideName = currentLocationInfo.rideName {
                                    Text(rideName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createActivity()
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
        .task {
            // Load location info and family code asynchronously
            locationInfo = await locationManager.getLocationInfo()
            do {
                familyCode = try await firebaseService.getCurrentFamilyCode() ?? ""
            } catch {
                print("Failed to load family code: \(error)")
            }
        }
    }

    private func createActivity() {
        guard firebaseService.currentUser != nil else { return }
        
        isCreating = true
        
        Task {
            do {
                let currentLocationInfo = includeLocation ? await locationManager.getLocationInfo() : nil

                let activity = Activity(
                    id: UUID().uuidString,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    location: currentLocationInfo.map { locInfo in
                        Activity.LocationInfo(
                            latitude: locInfo.latitude,
                            longitude: locInfo.longitude,
                            parkName: locInfo.parkName,
                            rideName: locInfo.rideName,
                            address: nil
                        )
                    },
                    scheduledTime: scheduledTime,
                    createdBy: firebaseService.currentUser!.uid,
                    familyCode: familyCode
                )
                
                try await firebaseService.saveActivity(activity)
                
                DispatchQueue.main.async {
                    self.isCreating = false
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCreating = false
                    // Handle error
                }
            }
        }
    }
}

struct ActivityDetailView: View {
    let activity: Activity
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(activity.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if let description = activity.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text(activity.status.rawValue.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(statusColor.opacity(0.2))
                                .foregroundColor(statusColor)
                                .cornerRadius(12)
                            
                            Spacer()
                            
                            if let scheduledTime = activity.scheduledTime {
                                Text(scheduledTime, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Location
                    if let location = activity.location {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    if let parkName = location.parkName {
                                        Text(parkName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    if let rideName = location.rideName {
                                        Text(rideName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Voting results
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Voting Results")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            VoteResultRow(
                                title: "Yes",
                                count: activity.votes.values.filter { $0 == .yes }.count,
                                total: activity.totalVoters,
                                color: .green
                            )
                            
                            VoteResultRow(
                                title: "Maybe",
                                count: activity.votes.values.filter { $0 == .maybe }.count,
                                total: activity.totalVoters,
                                color: .orange
                            )
                            
                            VoteResultRow(
                                title: "No",
                                count: activity.votes.values.filter { $0 == .no }.count,
                                total: activity.totalVoters,
                                color: .red
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Activity Details")
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
    
    private var statusColor: Color {
        switch activity.status {
        case .planned: return .blue
        case .confirmed: return .green
        case .completed: return .purple
        case .cancelled: return .red
        }
    }
}

struct VoteResultRow: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            
            ProgressView(value: percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .frame(width: 30, alignment: .trailing)
        }
    }

}

#Preview {
    PlannerView()
        .environmentObject(FirebaseService.shared)
}
