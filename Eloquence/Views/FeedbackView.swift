//
//  FeedbackView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI
import Combine

struct FeedbackView: View {
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) var dismiss
    let session: PracticeSession
    @State private var showCelebration = false
    @State private var navigateToDashboard = false
    @State private var showNameRecordingAlert = false
    @State private var recordingName = ""
    
    var body: some View {
        ZStack {
            // Background
            Color.bg
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.largeSpacing) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.success.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(Color.success)
                        }
                        .scaleEffect(showCelebration ? 1.0 : 0.5)
                        .opacity(showCelebration ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showCelebration)
                        
                        Text("Your AI Feedback")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        
                        Text("Session completed at \(formattedDate)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                    }
                    .padding(.top, Theme.largeSpacing)
                    
                    // Overall score
                    VStack(spacing: Theme.spacing) {
                        Text("Overall Score")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textMuted)
                        
                        ZStack {
                            Circle()
                                .stroke(Color.border, lineWidth: 12)
                                .frame(width: 140, height: 140)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(session.averageScore) / 100)
                                .stroke(
                                    LinearGradient(
                                        colors: [.primary, .secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                )
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 4) {
                                Text("\(session.averageScore)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.textPrimary)
                                
                                Text("out of 100")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.textMuted)
                            }
                        }
                    }
                    .padding(Theme.largeSpacing)
                    .background(Color.bgLight)
                    .cornerRadius(Theme.cornerRadius)
                    .padding(.horizontal, Theme.largeSpacing)
                    
                    // Individual scores
                    VStack(spacing: Theme.spacing) {
                        Text("Detailed Analysis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ScoreCard(title: "Tone", score: session.toneScore, icon: "waveform", color: .primary)
                        ScoreCard(title: "Pacing", score: session.pacingScore, icon: "speedometer", color: .secondary)

                        // Gestures with detailed breakdown
                        VStack(alignment: .leading, spacing: Theme.spacing) {
                            ScoreCard(title: "Gestures", score: session.gesturesScore, icon: "figure.wave", color: .info)

                            // Gesture sub-scores breakdown
                            if session.facialScore != nil || session.postureScore != nil {
                                DisclosureGroup {
                                    VStack(spacing: 12) {
                                        if let facialScore = session.facialScore {
                                            SubScoreRow(
                                                icon: "face.smiling",
                                                label: "Facial Expression",
                                                score: facialScore,
                                                color: .info
                                            )
                                        }

                                        if let postureScore = session.postureScore {
                                            SubScoreRow(
                                                icon: "figure.stand",
                                                label: "Body Posture",
                                                score: postureScore,
                                                color: .info
                                            )
                                        }

                                        if let eyeContactScore = session.eyeContactScore {
                                            SubScoreRow(
                                                icon: "eye",
                                                label: "Eye Contact",
                                                score: eyeContactScore,
                                                color: .info
                                            )
                                        }

                                        // Placeholders for Phase 2
                                        SubScoreRow(
                                            icon: "hand.raised",
                                            label: "Hand Gestures",
                                            score: nil,
                                            color: .textMuted,
                                            placeholder: "Coming in Phase 2"
                                        )

                                        if session.eyeContactScore == nil {
                                            SubScoreRow(
                                                icon: "eye",
                                                label: "Eye Contact",
                                                score: nil,
                                                color: .textMuted,
                                                placeholder: "Not detected in this session"
                                            )
                                        }
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    HStack {
                                        Text("View Gesture Details")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color.primary)

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                    }
                                }
                                .tint(.primary)
                            }
                        }
                    }
                    .padding(Theme.largeSpacing)
                    .background(Color.bgLight)
                    .cornerRadius(Theme.cornerRadius)
                    .padding(.horizontal, Theme.largeSpacing)
                    
                    // AI Feedback
                    VStack(alignment: .leading, spacing: Theme.spacing) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.primary)
                            
                            Text("AI Insights")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                        }
                        
                        Text(session.feedback.isEmpty ? "Great job on completing this practice session!" : session.feedback)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                            .lineSpacing(4)
                    }
                    .padding(Theme.largeSpacing)
                    .background(Color.bgLight)
                    .cornerRadius(Theme.cornerRadius)
                    .padding(.horizontal, Theme.largeSpacing)

                    // Visual Highlights Section
                    if let keyFrames = session.keyFrames, !keyFrames.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.mediumSpacing) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.primary)

                                Text("Visual Highlights")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                            }

                            // Positive frames
                            let positiveFrames = keyFrames.filter { $0.isPositive }
                            if !positiveFrames.isEmpty {
                                Text("Your Strengths")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textMuted)
                                    .padding(.top, 4)

                                ForEach(positiveFrames) { keyFrame in
                                    KeyFrameCard(keyFrame: keyFrame)
                                }
                            }

                            // Improvement frames
                            let improvementFrames = keyFrames.filter { !$0.isPositive }
                            if !improvementFrames.isEmpty {
                                Text("Areas to Improve")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textMuted)
                                    .padding(.top, improvementFrames.isEmpty ? 4 : 12)

                                ForEach(improvementFrames) { keyFrame in
                                    KeyFrameCard(keyFrame: keyFrame)
                                }
                            }
                        }
                        .padding(Theme.largeSpacing)
                        .background(Color.bgLight)
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal, Theme.largeSpacing)
                    }

                    // Action buttons
                    VStack(spacing: Theme.spacing) {
                        NavigationLink(destination: RecordingView()) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20))
                                
                                Text("Try Again")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.buttonHeight)
                            .foregroundStyle(Color.bg)
                            .background(.primary)
                            .cornerRadius(Theme.cornerRadius)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink(destination: ProgressView()) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 20))
                                
                                Text("View Progress")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.buttonHeight)
                            .foregroundStyle(Color.textPrimary)
                            .background(Color.bgLight)
                            .cornerRadius(Theme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .stroke(Color.border, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            showNameRecordingAlert = true
                        }) {
                            Text("Back to Dashboard")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.textMuted)
                        }
                    }
                    .padding(.horizontal, Theme.largeSpacing)
                    .padding(.bottom, Theme.largeSpacing)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToDashboard) {
            DashboardView()
        }
        .onAppear {
            showCelebration = true
            // Only add session if it doesn't already exist (check by ID)
            if !userSession.sessions.contains(where: { $0.id == session.id }) {
                userSession.addSession(session)
            }
        }
        .alert("Name Your Recording", isPresented: $showNameRecordingAlert) {
            TextField("Recording Name", text: $recordingName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveRecordingName()
                navigateToDashboard = true
            }
        } message: {
            Text("Enter a name for this recording")
        }
    }
    
    private func saveRecordingName() {
        // Find the video file associated with this session
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil, options: [])
            let videoFiles = files.filter { $0.pathExtension == "mov" || $0.pathExtension == "mp4" }
            
            // Find the video file that matches this session
            for videoFile in videoFiles {
                let videoFileName = videoFile.lastPathComponent
                if let sessionIDString = UserDefaults.standard.string(forKey: "session_id_\(videoFileName)"),
                   let sessionID = UUID(uuidString: sessionIDString),
                   sessionID == session.id {
                    // Save the recording name
                    let trimmedName = recordingName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        UserDefaults.standard.set(trimmedName, forKey: "recording_name_\(videoFileName)")
                    }
                    break
                }
            }
        } catch {
            print("Error finding video file: \(error)")
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: session.date)
    }
}

struct ScoreCard: View {
    let title: String
    let score: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.spacing) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }

            // Title and progress
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.border)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                    }
                }
                .frame(height: 8)
            }

            // Score
            Text("\(score)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

struct SubScoreRow: View {
    let icon: String
    let label: String
    let score: Int?
    var color: Color = .info
    var placeholder: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            if let score = score {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.border)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(score) / 100, height: 6)
                    }
                }
                .frame(width: 80, height: 6)

                Text("\(score)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 35, alignment: .trailing)
            } else if let placeholder = placeholder {
                Text(placeholder)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textMuted)
                    .italic()
            }
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView(session: PracticeSession(
            date: Date(),
            toneScore: 85,
            pacingScore: 80,
            gesturesScore: 88,
            feedback: "Great job! Your tone was engaging and your pacing was excellent. Try to add more pauses between key points."
        ))
        .environmentObject(UserSession())
    }
}

