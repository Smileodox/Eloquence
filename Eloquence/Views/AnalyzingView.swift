//
//  AnalyzingView.swift
//  Eloquence
//

import SwiftUI
import Combine

struct AnalyzingView: View {
    @EnvironmentObject var userSession: UserSession

    let videoURL: URL?
    let recordingType: RecordingType?
    let project: Project?

    // Add services
    private let audioService = AudioExtractionService()
    private let azureService = AzureOpenAIService()
    private let gestureService = GestureAnalysisService()

    // Network retry helper for API calls
    private let retryHelper = NetworkRetryHelper()

    @State private var progress: CGFloat = 0
    @State private var currentStep = 0
    @State private var navigateToFeedback = false
    @State private var generatedSession: PracticeSession?

    // Add error handling
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var currentStepMessage = ""
    @State private var navigateToDashboard = false
    @State private var failedSteps: Set<Int> = []

    // Visual feedback animations
    @State private var isPulsing = false
    @State private var activityDots = ""
    @State private var dotTimer: Timer?

    init(videoURL: URL? = nil, recordingType: RecordingType? = nil, project: Project? = nil) {
        self.videoURL = videoURL
        self.recordingType = recordingType
        self.project = project
    }
    
    let steps = [
        ("mic.fill", "Analyzing audio quality..."),
        ("waveform", "Detecting tone patterns..."),
        ("speedometer", "Measuring pacing..."),
        ("face.smiling", "Analyzing facial expressions and posture..."),
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
            FeedbackView(session: generatedSession ?? sampleSession, entryPoint: .newRecording)
        }
        .navigationDestination(isPresented: $navigateToDashboard) {
            DashboardView()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            isPulsing = true
            startActivityDots()
            startRealAnalysis()
        }
        .alert("Analysis Error", isPresented: $showErrorAlert) {
            Button("Try Again") {
                progress = 0
                currentStep = 0
                currentStepMessage = ""
                errorMessage = nil
                isPulsing = true
                startActivityDots()
                startRealAnalysis()
            }
            Button("Return to Dashboard") {
                navigateToDashboard = true
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
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true),
                        value: isPulsing
                    )
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
        VStack(spacing: 12) {
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

            // Activity dots indicator
            Text(activityDots)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.primary)
                .frame(height: 30)
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
        let isFailed = failedSteps.contains(index)
        let icon = isFailed ? "xmark.circle.fill" : index < currentStep ? "checkmark.circle.fill" : index == currentStep ? "circle.circle.fill" : "circle"
        let iconColor = isFailed ? Color.red : index < currentStep ? Color.success : index == currentStep ? Color.primary : Color.border
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
    
    // MARK: - Visual Feedback Helpers

    private func startActivityDots() {
        dotTimer?.invalidate()
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            activityDots = activityDots.count >= 3 ? "" : activityDots + "."
        }
    }

    private func stopActivityDots() {
        dotTimer?.invalidate()
        activityDots = ""
    }

    // MARK: - Real Analysis with Azure OpenAI

    private func startRealAnalysis() {
        guard let videoURL = videoURL else {
            showError("No video file found. Please record a video first.")
            return
        }

        Task {
            do {
                let isOffline = userSession.enableOfflineMode

                if isOffline {
                    guard #available(iOS 26.0, *) else {
                        showError("Offline mode requires iOS 26 or later with Apple Intelligence.")
                        return
                    }
                    try await runOfflineAnalysis(videoURL: videoURL)
                    return
                }

                try await runOnlineAnalysis(videoURL: videoURL)

            } catch let error as AnalysisError {
                showError(error.errorDescription ?? error.localizedDescription)
            } catch let error as OnDeviceAIError {
                showError(error.userMessage)
            } catch let error as AzureAPIError {
                showError(error.userMessage)
            } catch let error as AudioExtractionError {
                showError(error.userMessage)
            } catch let error as GestureAnalysisError {
                showError(error.userMessage)
            } catch {
                showError("An unexpected error occurred: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Online Analysis (Azure OpenAI)

    private func runOnlineAnalysis(videoURL: URL) async throws {
        // Step 1: Extract audio from video
        updateStep(0, message: "Extracting audio from video...", progress: 0.2)
        let audioURL = try await audioService.extractAudio(from: videoURL)

        // Step 2: Transcribe audio with Whisper
        updateStep(1, message: "Transcribing speech with AI...", progress: 0.5)
        let transcription = try await retryHelper.withRetry {
            try await azureService.transcribeAudio(audioURL)
        }

        guard !transcription.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscription
        }

        // Step 3: Analyze speech metrics locally
        updateStep(2, message: "Analyzing pace and tone...", progress: 0.55)
        let audioDuration = try await audioService.getAudioDuration(audioURL)
        let metrics = azureService.analyzeSpeechMetrics(transcription: transcription.text, audioDuration: audioDuration)

        // Step 4: Analyze gestures
        updateStep(3, message: "Analyzing facial expressions and posture...", progress: 0.75)
        let analysisSettings = AnalysisSettings(
            enableEyeContact: userSession.enableEyeContactAnalysis,
            enableFacial: userSession.enableFacialAnalysis,
            enablePosture: userSession.enablePostureAnalysis
        )
        let gestureMetrics = try await gestureService.analyzeVideo(from: videoURL, settings: analysisSettings)

        // Step 5: Generate ALL feedback in parallel
        updateStep(4, message: "Generating personalized feedback...", progress: 0.90)

        async let analysisTask = retryHelper.withRetry {
            try await azureService.generateFeedback(transcription: transcription.text, metrics: metrics)
        }

        let gestureAnalysisResult: GestureAnalysisResponse
        let enhancedGestureMetrics: GestureMetrics

        if gestureMetrics.insufficientData {
            await MainActor.run { failedSteps.insert(3) }
            gestureAnalysisResult = GestureAnalysisResponse(
                gestureFeedback: "Gesture analysis was not available for this video. Ensure you are clearly visible in the frame with good lighting.",
                gestureStrength: "N/A",
                gestureImprovement: "Ensure your face and body are clearly visible in the video.",
                isTemplateFallback: true
            )
            enhancedGestureMetrics = gestureMetrics
        } else {
            async let gestureAnalysisTask: GestureAnalysisResponse = retryHelper.withRetry {
                try await azureService.generateGestureFeedback(gestureMetrics: gestureMetrics, transcription: transcription.text)
            }
            async let enhancedMetricsTask = enhanceKeyFramesWithAI(
                gestureMetrics: gestureMetrics,
                transcription: transcription.text
            )
            (gestureAnalysisResult, enhancedGestureMetrics) = try await (gestureAnalysisTask, enhancedMetricsTask)
        }

        let speechAnalysis = try await analysisTask

        // Complete
        updateStep(4, message: "Analysis complete!", progress: 1.0)

        let session = createSessionFromAnalysis(
            analysis: speechAnalysis,
            metrics: metrics,
            gestureMetrics: enhancedGestureMetrics,
            gestureAnalysis: gestureAnalysisResult
        )

        audioService.cleanupAudioFile(audioURL)
        let videoFileName = videoURL.lastPathComponent
        UserDefaults.standard.set(session.id.uuidString, forKey: "session_id_\(videoFileName)")

        await MainActor.run {
            stopActivityDots()
            generatedSession = session
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                navigateToFeedback = true
            }
        }
    }

    // MARK: - Offline Analysis (On-Device)

    @available(iOS 26.0, *)
    private func runOfflineAnalysis(videoURL: URL) async throws {
        let onDeviceService = OnDeviceAIService()

        // Step 1: Extract audio from video
        updateStep(0, message: "Extracting audio from video...", progress: 0.2)
        let audioURL = try await audioService.extractAudio(from: videoURL)

        // Step 2: Transcribe audio on-device
        updateStep(1, message: "Transcribing speech on-device...", progress: 0.5)
        let transcription = try await onDeviceService.transcribeAudio(audioURL)

        guard !transcription.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscription
        }

        // Step 3: Analyze speech metrics locally
        updateStep(2, message: "Analyzing pace and tone...", progress: 0.55)
        let audioDuration = try await audioService.getAudioDuration(audioURL)
        let metrics = onDeviceService.analyzeSpeechMetrics(transcription: transcription.text, audioDuration: audioDuration)

        // Step 4: Analyze gestures
        updateStep(3, message: "Analyzing facial expressions and posture...", progress: 0.75)
        let analysisSettings = AnalysisSettings(
            enableEyeContact: userSession.enableEyeContactAnalysis,
            enableFacial: userSession.enableFacialAnalysis,
            enablePosture: userSession.enablePostureAnalysis
        )
        let gestureMetrics = try await gestureService.analyzeVideo(from: videoURL, settings: analysisSettings)

        // Step 5: Generate feedback on-device (no key frame annotations)
        updateStep(4, message: "Generating feedback on-device...", progress: 0.90)

        let speechAnalysis = try await onDeviceService.generateFeedback(
            transcription: transcription.text,
            metrics: metrics
        )

        let gestureAnalysisResult: GestureAnalysisResponse
        if gestureMetrics.insufficientData {
            await MainActor.run { failedSteps.insert(3) }
            gestureAnalysisResult = GestureAnalysisResponse(
                gestureFeedback: "Gesture analysis was not available for this video. Ensure you are clearly visible in the frame with good lighting.",
                gestureStrength: "N/A",
                gestureImprovement: "Ensure your face and body are clearly visible in the video.",
                isTemplateFallback: true
            )
        } else {
            gestureAnalysisResult = try await onDeviceService.generateGestureFeedback(
                gestureMetrics: gestureMetrics,
                transcription: transcription.text
            )
        }

        // Strip key frames — annotation not supported offline
        let finalGestureMetrics = GestureMetrics(
            facialMetrics: gestureMetrics.facialMetrics,
            postureMetrics: gestureMetrics.postureMetrics,
            eyeContactMetrics: gestureMetrics.eyeContactMetrics,
            overallScore: gestureMetrics.overallScore,
            facialScore: gestureMetrics.facialScore,
            postureScore: gestureMetrics.postureScore,
            eyeContactScore: gestureMetrics.eyeContactScore,
            keyFrames: [],
            insufficientData: gestureMetrics.insufficientData
        )

        // Complete
        updateStep(4, message: "Analysis complete!", progress: 1.0)

        let session = createSessionFromAnalysis(
            analysis: speechAnalysis,
            metrics: metrics,
            gestureMetrics: finalGestureMetrics,
            gestureAnalysis: gestureAnalysisResult
        )

        audioService.cleanupAudioFile(audioURL)
        let videoFileName = videoURL.lastPathComponent
        UserDefaults.standard.set(session.id.uuidString, forKey: "session_id_\(videoFileName)")

        await MainActor.run {
            stopActivityDots()
            generatedSession = session
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                navigateToFeedback = true
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
        stopActivityDots()
        errorMessage = message
        showErrorAlert = true
    }

    /// Enhances key frames with AI-generated annotations using GPT-4o vision
    private func enhanceKeyFramesWithAI(
        gestureMetrics: GestureMetrics,
        transcription: String
    ) async throws -> GestureMetrics {
        print("🎨 [AI Enhancement] Generating AI annotations for \(gestureMetrics.keyFrames.count) key frames...")

        // Extract context excerpts from transcription for each frame
        let words = transcription.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let wordsPerSecond = Double(words.count) / (Double(words.count) / 150.0 * 60.0) / 60.0  // Rough estimate

        var enhancedFrames: [KeyFrame] = []
        
        // Use TaskGroup to process frames in parallel
        try await withThrowingTaskGroup(of: KeyFrame.self) { group in
            for keyFrame in gestureMetrics.keyFrames {
                group.addTask { [self] in
                    do {
                        // Extract ~500 chars of transcription context around timestamp
                        let contextExcerpt = extractTranscriptionContext(
                            from: transcription,
                            timestamp: keyFrame.timestamp,
                            wordsPerSecond: wordsPerSecond,
                            contextLength: 500
                        )

                        // Generate AI annotation
                        let aiAnnotation = try await azureService.generateKeyFrameAnnotation(
                            imageData: keyFrame.image,
                            type: keyFrame.type,
                            transcriptionExcerpt: contextExcerpt,
                            timestamp: keyFrame.timestamp
                        )

                        // Create enhanced frame with AI annotation
                        let enhancedFrame = KeyFrame(
                            id: keyFrame.id,
                            image: keyFrame.image,
                            timestamp: keyFrame.timestamp,
                            type: keyFrame.type,
                            primaryMetric: keyFrame.primaryMetric,
                            score: keyFrame.score,
                            annotation: aiAnnotation,  // AI-generated!
                            isPositive: keyFrame.isPositive
                        )
                        
                        print("✅ [AI Enhancement] Frame \(keyFrame.type.rawValue) at \(String(format: "%.1f", keyFrame.timestamp))s: \(aiAnnotation)")
                        return enhancedFrame
                        
                    } catch {
                        print("⚠️ [AI Enhancement] Failed for frame \(keyFrame.type.rawValue), keeping original: \(error)")
                        // Keep original frame if AI annotation fails
                        return keyFrame
                    }
                }
            }
            
            // Collect results with progress tracking
            var processedFrames = 0
            let totalFrames = gestureMetrics.keyFrames.count

            for try await frame in group {
                processedFrames += 1
                await updateStep(
                    4,
                    message: "Enhancing key frames (\(processedFrames)/\(totalFrames))...",
                    progress: 0.90 + (0.05 * Double(processedFrames) / Double(totalFrames))
                )
                enhancedFrames.append(frame)
            }
        }
        
        // Sort frames by timestamp to maintain original order
        enhancedFrames.sort { $0.timestamp < $1.timestamp }

        print("🎨 [AI Enhancement] Complete - enhanced \(enhancedFrames.count) frames")

        // Return updated GestureMetrics with AI-enhanced frames
        return GestureMetrics(
            facialMetrics: gestureMetrics.facialMetrics,
            postureMetrics: gestureMetrics.postureMetrics,
            eyeContactMetrics: gestureMetrics.eyeContactMetrics,
            overallScore: gestureMetrics.overallScore,
            facialScore: gestureMetrics.facialScore,
            postureScore: gestureMetrics.postureScore,
            eyeContactScore: gestureMetrics.eyeContactScore,
            keyFrames: enhancedFrames
        )
    }

    /// Extracts a portion of transcription around a specific timestamp
    private func extractTranscriptionContext(
        from transcription: String,
        timestamp: Double,
        wordsPerSecond: Double,
        contextLength: Int
    ) -> String {
        // Estimate which words are around this timestamp
        let words = transcription.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let wordIndex = Int(timestamp * wordsPerSecond)

        // Take ±30 words around the timestamp (or full text if short)
        let contextWindowSize = 30
        let startIndex = max(0, wordIndex - contextWindowSize)
        let endIndex = min(words.count, wordIndex + contextWindowSize)

        let contextWords = Array(words[startIndex..<endIndex])
        let context = contextWords.joined(separator: " ")

        // Trim to desired length if still too long
        if context.count > contextLength {
            let midpoint = context.count / 2
            let halfLength = contextLength / 2
            let start = max(0, midpoint - halfLength)
            let end = min(context.count, midpoint + halfLength)
            return String(context[context.index(context.startIndex, offsetBy: start)..<context.index(context.startIndex, offsetBy: end)])
        }

        return context
    }

    private func createSessionFromAnalysis(
        analysis: GPTAnalysisResponse,
        metrics: SpeechMetrics,
        gestureMetrics: GestureMetrics,
        gestureAnalysis: GestureAnalysisResponse
    ) -> PracticeSession {
        // Average tone-related scores
        let toneScore = analysis.averageToneScore

        // Calculate pacing score based on WPM
        let pacingScore = azureService.calculatePacingScore(wpm: metrics.wordsPerMinute)

        // Use real gesture score from Vision analysis
        let gesturesScore = gestureMetrics.overallScore

        // Combine feedback
        let combinedFeedback = analysis.feedback + "\n\n" + gestureAnalysis.gestureFeedback

        return PracticeSession(
            date: Date(),
            toneScore: toneScore,
            pacingScore: pacingScore,
            gesturesScore: gesturesScore,
            feedback: combinedFeedback,
            recordingType: recordingType?.rawValue,
            projectId: project?.id,
            gestureStrength: gestureAnalysis.gestureStrength,
            gestureImprovement: gestureAnalysis.gestureImprovement,
            facialScore: gestureMetrics.facialScore,
            postureScore: gestureMetrics.postureScore,
            eyeContactScore: gestureMetrics.eyeContactScore,
            keyFrames: gestureMetrics.keyFrames,
            gestureDataInsufficient: gestureMetrics.insufficientData,
            toneStrength: analysis.toneStrength,
            toneImprovement: analysis.toneImprovement,
            pacingStrength: analysis.pacingStrength,
            pacingImprovement: analysis.pacingImprovement
        )
    }
    
    private var sampleSession: PracticeSession {
        PracticeSession(date: Date(), toneScore: 85, pacingScore: 80, gesturesScore: 82)
    }
}

// MARK: - Analysis Errors

enum AnalysisError: LocalizedError {
    case emptyTranscription

    var errorDescription: String? {
        switch self {
        case .emptyTranscription:
            return "No speech detected in the recording. Please speak clearly and try again."
        }
    }
}

#Preview {
    NavigationStack {
        AnalyzingView()
    }
}
