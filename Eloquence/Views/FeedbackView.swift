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
    let entryPoint: FeedbackEntryPoint
    @State private var showCelebration = false
    @State private var navigateToDashboard = false
    @State private var showNameRecordingAlert = false
    @State private var recordingName = ""
    @State private var gestureDetailsExpanded = false
    
    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.largeSpacing) {
                    headerSection
                    overallScoreSection
                    detailedAnalysisSection
                    aiFeedbackSection
                    visualHighlightsSection
                    actionButtonsSection
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    handleBackNavigation()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text(entryPoint.backButtonLabel)
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToDashboard) {
            DashboardView()
        }
        .onAppear {
            showCelebration = true
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

    // MARK: - View Components

    private var headerSection: some View {
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
    }

    private var overallScoreSection: some View {
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
    }

    private var detailedAnalysisSection: some View {
        VStack(spacing: Theme.spacing) {
            Text("Detailed Analysis")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScoreCard(
                title: "Tone",
                score: session.toneScore,
                icon: "waveform",
                color: .primary,
                explanation: "Analyzes voice quality, emphasis, and emotional expression. Evaluates confidence, enthusiasm, and clarity in your delivery."
            )
            ScoreCard(
                title: "Pacing",
                score: session.pacingScore,
                icon: "speedometer",
                color: .secondary,
                explanation: "Measures speaking speed (words per minute). Ideal range: 130-150 WPM for clear understanding. Evaluates pauses and rhythm."
            )
            gestureScoreSection
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }

    private var gestureScoreSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            ScoreCard(
                title: "Gestures",
                score: session.gesturesScore,
                icon: "figure.wave",
                color: .info,
                explanation: "Analyzes facial expressions, posture, and eye contact. Evaluates engagement and non-verbal communication."
            )

            if session.gestureDataInsufficient == true {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                    Text("Gesture data was insufficient. Ensure you are clearly visible in the frame with good lighting.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                }
                .padding(Theme.spacing)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(Theme.cornerRadius)
            } else if session.facialScore != nil || session.postureScore != nil {
                gestureDetailsDisclosure
            }
        }
    }

    private var gestureDetailsDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    gestureDetailsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("View Gesture Details")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary)

                    Spacer()

                    Image(systemName: gestureDetailsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
                .contentShape(Rectangle())
            }
            
            if gestureDetailsExpanded {
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
                .transition(.opacity)
            }
        }
        .tint(.primary)
    }

    private var aiFeedbackSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.primary)

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
    }

    @ViewBuilder
    private var visualHighlightsSection: some View {
        if let keyFrames = session.keyFrames, !keyFrames.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.primary)

                    Text("Visual Highlights")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }

                keyFramesContent(keyFrames)
            }
            .padding(Theme.largeSpacing)
            .background(Color.bgLight)
            .cornerRadius(Theme.cornerRadius)
            .padding(.horizontal, Theme.largeSpacing)
        }
    }

    private func keyFramesContent(_ keyFrames: [KeyFrame]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let positiveFrames = keyFrames.filter { $0.isPositive }
            let improvementFrames = keyFrames.filter { !$0.isPositive }

            if !positiveFrames.isEmpty {
                Text("Your Strengths")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
                    .padding(.top, 4)

                ForEach(positiveFrames) { keyFrame in
                    KeyFrameCard(keyFrame: keyFrame)
                }
            }

            if !improvementFrames.isEmpty {
                Text("Areas to Improve")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
                    .padding(.top, !positiveFrames.isEmpty ? 12 : 4)

                ForEach(improvementFrames) { keyFrame in
                    KeyFrameCard(keyFrame: keyFrame)
                }
            }
        }
    }

    private var actionButtonsSection: some View {
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

    private func handleBackNavigation() {
        switch entryPoint {
        case .recordingsList:
            // Dismiss to return to RecordingsListView
            dismiss()
        case .newRecording:
            // Navigate to Dashboard
            navigateToDashboard = true
        case .progressView:
            // Dismiss to return to ProgressView
            dismiss()
        }
    }
}

struct ScoreCard: View {
    let title: String
    let score: Int
    let icon: String
    let color: Color
    var explanation: String? = nil

    @State private var showExplanation = false

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
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    if explanation != nil {
                        Button {
                            showExplanation = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textMuted)
                        }
                    }
                }

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
        .sheet(isPresented: $showExplanation) {
            MetricExplanationSheet(
                title: title,
                icon: icon,
                color: color,
                explanation: explanation ?? ""
            )
            .presentationDetents([.medium])
        }
    }
}

struct MetricExplanationSheet: View {
    let title: String
    let icon: String
    let color: Color
    let explanation: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header with icon
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.top, 24)

            // Explanation text
            Text(explanation)
                .font(.system(size: 16))
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            // Dismiss button
            Button {
                dismiss()
            } label: {
                Text("Got it")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(color)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.bgLight)
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
        FeedbackView(
            session: PracticeSession(
                date: Date(),
                toneScore: 85,
                pacingScore: 80,
                gesturesScore: 88,
                feedback: "Great job! Your tone was engaging and your pacing was excellent. Try to add more pauses between key points."
            ),
            entryPoint: .newRecording
        )
        .environmentObject(UserSession())
    }
}

