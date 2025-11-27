//
//  AnalyzingView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI
import Combine

struct AnalyzingView: View {
    let videoURL: URL?
    let recordingType: RecordingType?
    let project: Project?

    // Add services
    @StateObject private var audioService = AudioExtractionService()
    @StateObject private var azureService = AzureOpenAIService()

    @State private var progress: CGFloat = 0
    @State private var currentStep = 0
    @State private var navigateToFeedback = false
    @State private var generatedSession: PracticeSession?

    // Add error handling
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var currentStepMessage = ""
    
    init(videoURL: URL? = nil, recordingType: RecordingType? = nil, project: Project? = nil) {
        self.videoURL = videoURL
        self.recordingType = recordingType
        self.project = project
    }
    
    let steps = [
        ("mic.fill", "Analyzing audio quality..."),
        ("waveform", "Detecting tone patterns..."),
        ("speedometer", "Measuring pacing..."),
        ("figure.wave", "Evaluating gestures..."),
        ("sparkles", "Generating feedback...")
    ]
    
    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            
            VStack(spacing: Theme.largeSpacing) {
                Spacer()
                brainAnimation
                progressSection
                currentStepCard
                processingSteps
                Spacer()
            }
            .padding(.top, Theme.largeSpacing)
        }
        .navigationDestination(isPresented: $navigateToFeedback) {
            FeedbackView(session: generatedSession ?? sampleSession)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startRealAnalysis()
        }
        .alert("Analysis Error", isPresented: $showErrorAlert) {
            Button("Try Again") {
                progress = 0
                currentStep = 0
                currentStepMessage = ""
                startRealAnalysis()
            }
            Button("Cancel", role: .cancel) {
                // User can navigate back manually
            }
        } message: {
            Text(errorMessage ?? "An error occurred during analysis.")
        }
    }
    
    private var brainAnimation: some View {
        ZStack {
            ForEach(0..<8) { index in
                Circle()
                    .fill(Color.primary.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(x: 80)
                    .rotationEffect(.degrees(Double(index) * 45 + progress * 360))
            }
            
            ZStack {
                Circle()
                    .fill(Color.bgLight)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(Color.primary, lineWidth: 3)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.primary)
                    .rotationEffect(.degrees(progress * 360))
            }
        }
        .frame(height: 200)
    }
    
    private var progressSection: some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.border)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.primary, Color.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, Theme.largeSpacing)
    }
    
    private var currentStepCard: some View {
        HStack(spacing: 16) {
            Image(systemName: steps[currentStep].0)
                .font(.system(size: 24))
                .foregroundStyle(Color.primary)
                .frame(width: 32)

            Text(currentStepMessage.isEmpty ? steps[currentStep].1 : currentStepMessage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Spacer()
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }
    
    private var processingSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚡ AI Processing")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Theme.largeSpacing)
            
            VStack(spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepRow(index: index, step: step)
                }
            }
        }
    }
    
    private func stepRow(index: Int, step: (String, String)) -> some View {
        let icon = index < currentStep ? "checkmark.circle.fill" : index == currentStep ? "circle.circle.fill" : "circle"
        let iconColor = index < currentStep ? Color.success : index == currentStep ? Color.primary : Color.border
        let textColor = index <= currentStep ? Color.textPrimary : Color.textMuted
        
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            
            Text(step.1)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(textColor)
            
            Spacer()
        }
        .padding(.horizontal, Theme.largeSpacing)
    }
    
    // MARK: - Real Analysis with Azure OpenAI

    private func startRealAnalysis() {
        guard let videoURL = videoURL else {
            showError("No video file found. Please record a video first.")
            return
        }

        Task {
            do {
                // Step 1: Extract audio from video
                await updateStep(0, message: "Extracting audio from video...", progress: 0.2)
                let audioURL = try await audioService.extractAudio(from: videoURL)

                // Step 2: Transcribe audio with Whisper
                await updateStep(1, message: "Transcribing speech with AI...", progress: 0.5)
                let transcription = try await azureService.transcribeAudio(audioURL)

                // Step 3: Analyze speech metrics locally
                await updateStep(2, message: "Analyzing pace and tone...", progress: 0.7)
                let audioDuration = try await audioService.getAudioDuration(audioURL)
                let metrics = azureService.analyzeSpeechMetrics(
                    transcription: transcription.text,
                    audioDuration: audioDuration
                )

                // Step 4: Generate feedback with GPT
                await updateStep(3, message: "Generating personalized feedback...", progress: 0.9)
                let analysis = try await azureService.generateFeedback(
                    transcription: transcription.text,
                    metrics: metrics
                )

                // Step 5: Complete and create session
                await updateStep(4, message: "Analysis complete!", progress: 1.0)

                // Create session from real analysis
                let session = createSessionFromAnalysis(analysis: analysis, metrics: metrics)

                // Clean up temporary audio file
                audioService.cleanupAudioFile(audioURL)

                // Link session to video file
                let videoFileName = videoURL.lastPathComponent
                UserDefaults.standard.set(session.id.uuidString, forKey: "session_id_\(videoFileName)")

                // Navigate to feedback
                await MainActor.run {
                    generatedSession = session
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        navigateToFeedback = true
                    }
                }

            } catch let error as AzureAPIError {
                await showError(error.userMessage)
            } catch let error as AudioExtractionError {
                await showError(error.userMessage)
            } catch {
                await showError("An unexpected error occurred: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func updateStep(_ step: Int, message: String, progress: CGFloat) {
        withAnimation(.spring()) {
            currentStep = step
            currentStepMessage = message
            self.progress = progress
        }
    }

    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    private func createSessionFromAnalysis(
        analysis: GPTAnalysisResponse,
        metrics: SpeechMetrics
    ) -> PracticeSession {
        // Average tone-related scores
        let toneScore = analysis.averageToneScore

        // Calculate pacing score based on WPM
        let pacingScore = azureService.calculatePacingScore(wpm: metrics.wordsPerMinute)

        // Gestures remain mock (as requested)
        let gesturesScore = Int.random(in: 75...95)

        return PracticeSession(
            date: Date(),
            toneScore: toneScore,
            pacingScore: pacingScore,
            gesturesScore: gesturesScore,
            feedback: analysis.feedback,
            recordingType: recordingType?.rawValue,
            projectId: project?.id
        )
    }
    
    private var sampleSession: PracticeSession {
        PracticeSession(date: Date(), toneScore: 85, pacingScore: 80, gesturesScore: 82)
    }
}

#Preview {
    NavigationStack {
        AnalyzingView()
    }
}
