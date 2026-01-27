//
//  RecordingsListView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI
import AVFoundation

struct RecordingsListView: View {
    @EnvironmentObject var userSession: UserSession
    let filterProject: Project?
    
    @State private var recordings: [RecordingItem] = []
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: RecordingItem?
    @State private var itemToEdit: RecordingItem?
    @State private var showingEditAlert = false
    @State private var editedName = ""
    
    init(filterProject: Project? = nil) {
        self.filterProject = filterProject
    }
    
    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            
            if recordings.isEmpty {
                emptyStateView
            } else {
                recordingsList
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Recordings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            loadRecordings()
        }
        .alert("Delete Recording", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    deleteRecording(item)
                }
            }
        } message: {
            Text("Are you sure you want to delete this recording?")
        }
        .alert("Edit Recording Name", isPresented: $showingEditAlert) {
            TextField("Recording Name", text: $editedName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let item = itemToEdit {
                    updateRecordingName(item, newName: editedName)
                }
            }
        } message: {
            Text("Enter a name for this recording")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.largeSpacing) {
            Spacer()

            Image(systemName: "video.slash")
                .font(.system(size: 80))
                .foregroundStyle(Color.textMuted)

            Text("No Recordings")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 12) {
                Text("Practice makes perfect!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.textPrimary)

                Text("Start recording to get AI feedback on your presentation skills")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.largeSpacing)

            // Call-to-action button
            NavigationLink(destination: RecordingSetupView()) {
                HStack {
                    Image(systemName: "video.fill")
                        .font(.system(size: 18))

                    Text("Record Your First Presentation")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: Theme.buttonHeight)
                .foregroundStyle(Color.bg)
                .background(.primary)
                .cornerRadius(Theme.cornerRadius)
                .padding(.horizontal, Theme.largeSpacing)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
    }
    
    private var recordingsList: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                ForEach(recordings) { recording in
                    RecordingRow(
                        recording: recording,
                        videoURL: recording.url,
                        userSession: userSession,
                        onDelete: {
                            itemToDelete = recording
                            showingDeleteAlert = true
                        },
                        onEdit: {
                            itemToEdit = recording
                            editedName = recording.displayName
                            showingEditAlert = true
                        }
                    )
                }
            }
            .padding(Theme.largeSpacing)
        }
    }
    
    private func loadRecordings() {
        recordings = []
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: [])
            
            let videoFiles = files.filter { $0.pathExtension == "mov" || $0.pathExtension == "mp4" }
            
            var allRecordings = videoFiles.compactMap { url in
                let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                let date = resourceValues?.creationDate ?? Date()
                let size = Int64(resourceValues?.fileSize ?? 0)
                let id = url.lastPathComponent
                let customName = UserDefaults.standard.string(forKey: "recording_name_\(id)")
                
                return RecordingItem(
                    id: id,
                    url: url,
                    date: date,
                    size: size,
                    customName: customName
                )
            }
            .sorted { $0.date > $1.date }
            
            // Filter by project if one is selected
            if let project = filterProject {
                allRecordings = allRecordings.filter { recording in
                    // Check if recording has a session that belongs to this project
                    let videoFileName = recording.url.lastPathComponent
                    if let sessionIDString = UserDefaults.standard.string(forKey: "session_id_\(videoFileName)"),
                       let sessionID = UUID(uuidString: sessionIDString),
                       let session = userSession.sessions.first(where: { $0.id == sessionID }) {
                        return session.projectId == project.id
                    }
                    return false
                }
            }
            
            recordings = allRecordings
        } catch {
            print("Error loading recordings: \(error)")
        }
    }
    
    private func deleteRecording(_ item: RecordingItem) {
        do {
            try FileManager.default.removeItem(at: item.url)
            loadRecordings()
        } catch {
            print("Error deleting recording: \(error)")
        }
    }
    
    private func updateRecordingName(_ item: RecordingItem, newName: String) {
        // Store custom name in UserDefaults with recording ID as key
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            UserDefaults.standard.set(trimmedName, forKey: "recording_name_\(item.id)")
        } else {
            UserDefaults.standard.removeObject(forKey: "recording_name_\(item.id)")
        }
        loadRecordings() // Reload to update display
    }
}

struct RecordingItem: Identifiable {
    let id: String
    let url: URL
    let date: Date
    let size: Int64
    var customName: String?
    
    var displayName: String {
        customName ?? "Practice Session"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedSize: String {
        let mb = Double(size) / 1_000_000.0
        return String(format: "%.1f MB", mb)
    }
}

struct RecordingRow: View {
    let recording: RecordingItem
    let videoURL: URL
    let userSession: UserSession
    let onDelete: () -> Void
    let onEdit: () -> Void
    @State private var thumbnail: UIImage?
    
    private var matchingSession: PracticeSession? {
        // Find session linked to this video file
        let videoFileName = recording.url.lastPathComponent
        if let sessionIDString = UserDefaults.standard.string(forKey: "session_id_\(videoFileName)"),
           let sessionID = UUID(uuidString: sessionIDString) {
            return userSession.sessions.first { $0.id == sessionID }
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: Theme.spacing) {
            // Video preview thumbnail (tappable for video playback)
            NavigationLink(destination: VideoPlayerView(videoURL: videoURL)) {
                ZStack {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        // Loading skeleton
                        ZStack {
                            Color.bgLight

                            ProgressView()
                                .tint(Color.textMuted)
                        }
                    }

                    // Play button overlay
                    if thumbnail != nil {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.6))
                                .frame(width: 50, height: 50)

                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .offset(x: 2)
                        }
                    }
                }
                .frame(width: 80, height: 80)
                .cornerRadius(Theme.smallCornerRadius)
                .clipped()
            }
            .buttonStyle(PlainButtonStyle())

            // Info area (tappable for feedback if analyzed)
            if let session = matchingSession {
                // Analyzed recording - navigate to feedback
                NavigationLink(destination: FeedbackView(session: session, entryPoint: .recordingsList)) {
                    infoSection(showChevron: true)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Not analyzed yet - no navigation
                infoSection(showChevron: false)
            }
        }
        .padding(Theme.spacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onEdit()
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .onAppear {
            generateThumbnail()
        }
    }

    @ViewBuilder
    private func infoSection(showChevron: Bool) -> some View {
        HStack(spacing: Theme.spacing) {
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(recording.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(recording.formattedDate)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textMuted)

                Text(recording.formattedSize)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()

            // Chevron indicator when feedback is available
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
            }
        }
    }
    
    private func generateThumbnail() {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        
        Task {
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                await MainActor.run {
                    thumbnail = UIImage(cgImage: cgImage)
                }
            } catch {
                print("Error generating thumbnail: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecordingsListView()
    }
}

