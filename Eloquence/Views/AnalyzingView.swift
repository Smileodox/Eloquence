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
    
    @State private var progress: CGFloat = 0
    @State private var currentStep = 0
    @State private var navigateToFeedback = false
    @State private var generatedSession: PracticeSession?
    
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
            startAnalysis()
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
            
            Text(steps[currentStep].1)
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
    
    private func startAnalysis() {
        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
            withAnimation(.linear(duration: 0.08)) {
                progress += 0.02
            }
            
            let newStep = min(Int(progress * Double(steps.count)), steps.count - 1)
            if newStep != currentStep {
                withAnimation(.spring()) {
                    currentStep = newStep
                }
            }
            
            if progress >= 1.0 {
                timer.invalidate()
                
                let session = PracticeSession(
                    date: Date(),
                    toneScore: Int.random(in: 75...95),
                    pacingScore: Int.random(in: 70...95),
                    gesturesScore: Int.random(in: 70...95),
                    feedback: generateFeedback(),
                    recordingType: recordingType?.rawValue,
                    projectId: project?.id
                )
                
                // Link session to video file
                if let videoURL = videoURL {
                    let videoFileName = videoURL.lastPathComponent
                    UserDefaults.standard.set(session.id.uuidString, forKey: "session_id_\(videoFileName)")
                }
                
                generatedSession = session
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    navigateToFeedback = true
                }
            }
        }
    }
    
    private func generateFeedback() -> String {
        let feedbackOptions = [
            "Great job! Your tone was engaging and your pacing was excellent. Try to add more pauses between key points to let your audience absorb the information.",
            "Excellent structure and enthusiasm! You maintained good eye contact and used natural gestures. Consider slowing down slightly when introducing complex topics.",
            "Strong presentation! Your voice projection was clear and confident. Work on varying your pace more to emphasize important points.",
            "Well done! Your body language was natural and your tone was professional. Try to incorporate more vocal variety to keep your audience engaged.",
            "Impressive delivery! You used strategic pauses effectively. To improve further, focus on maintaining consistent energy throughout your presentation."
        ]
        
        return feedbackOptions.randomElement() ?? feedbackOptions[0]
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
