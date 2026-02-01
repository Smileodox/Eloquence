//
//  OnboardingView.swift
//  Eloquence
//
//  Created by Claude on 30.01.26.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pageCount = 5

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePage().tag(0)
                    CreateProjectPage().tag(1)
                    RecordSessionPage().tag(2)
                    InstantFeedbackPage().tag(3)
                    TrackProgressPage().tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicators
                HStack(spacing: 10) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.primary : Color.border)
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        if currentPage < pageCount - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < pageCount - 1 ? "Continue" : "Get Started")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.bg)
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.buttonHeight)
                            .background(Color.primary)
                            .cornerRadius(Theme.cornerRadius)
                    }

                    if currentPage < pageCount - 1 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                    }
                }
                .padding(.horizontal, Theme.largeSpacing)
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App logo
            ZStack {
                Circle()
                    .fill(Color(hue: 247/360, saturation: 0.33, brightness: 0.06))
                    .frame(width: 120, height: 120)

                Image(systemName: "waveform")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(Color(hue: 49/360, saturation: 1.0, brightness: 0.55))
            }

            VStack(spacing: 16) {
                Text("Welcome to Eloquence")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Your AI presentation coach.\nRecord, get feedback, and improve.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Workflow overview diagram
            HStack(spacing: 0) {
                workflowStep(icon: "folder.fill", label: "Create")
                workflowArrow()
                workflowStep(icon: "video.fill", label: "Record")
                workflowArrow()
                workflowStep(icon: "sparkles", label: "Feedback")
                workflowArrow()
                workflowStep(icon: "chart.line.uptrend.xyaxis", label: "Improve")
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.largeSpacing)
    }

    private func workflowStep(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.primary)
            }

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textMuted)
        }
    }

    private func workflowArrow() -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.border)
            .padding(.horizontal, 4)
            .padding(.bottom, 18)
    }
}

// MARK: - Page 2: Create a Project

private struct CreateProjectPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("Organize with Projects")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Group your practice sessions by presentation.\nSet deadlines to stay on track.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Mini project creation diagram
            VStack(spacing: 0) {
                // Fake project card mockup
                VStack(spacing: 14) {
                    HStack {
                        Text("New Project")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primary)
                    }

                    // Name field mockup
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textMuted)
                        Text("Q1 Sales Pitch")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.bg)
                    .cornerRadius(Theme.smallCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                            .stroke(Color.primary, lineWidth: 1)
                    )

                    // Due date mockup
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.warning)
                        Text("Due: Feb 14, 2026")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                        Spacer()
                        Text("15 days left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.warning)
                    }
                    .padding(12)
                    .background(Color.warning.opacity(0.1))
                    .cornerRadius(Theme.smallCornerRadius)
                }
                .padding(Theme.spacing)
                .background(Color.bgLight)
                .cornerRadius(Theme.cornerRadius)

                // Arrow down
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .padding(.vertical, 10)

                // Recording type selection mockup
                HStack(spacing: 10) {
                    recordingTypePill(icon: "briefcase.fill", label: "Professional", selected: true)
                    recordingTypePill(icon: "book.fill", label: "Education", selected: false)
                    recordingTypePill(icon: "megaphone.fill", label: "Public", selected: false)
                }
                .padding(Theme.spacing)
                .background(Color.bgLight)
                .cornerRadius(Theme.cornerRadius)
            }
            .padding(.horizontal, 4)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.largeSpacing)
    }

    private func recordingTypePill(icon: String, label: String, selected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .foregroundStyle(selected ? Color.bg : Color.textMuted)
        .background(selected ? Color.primary : Color.bg)
        .cornerRadius(Theme.smallCornerRadius)
    }
}

// MARK: - Page 3: Record a Session

private struct RecordSessionPage: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("Record Yourself")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Use the front camera to record your presentation.\nThe AI analyzes your voice and body language.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Camera recording diagram
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    // REC indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulse ? 1.4 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(), value: pulse)

                        Text("REC")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)

                    Spacer()

                    // Timer
                    Text("01:24")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    // Waveform mockup
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.primary)
                                .frame(width: 3, height: CGFloat([8, 14, 6, 18, 10, 16, 7, 12][i]))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                // Person silhouette
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.textMuted.opacity(0.3))

                Spacer()

                // Record button
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 56, height: 56)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.danger)
                        .frame(width: 22, height: 22)
                }
                .padding(.bottom, 16)
            }
            .frame(height: 260)
            .background(Color.bgDark)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(Color.border, lineWidth: 1)
            )

            // Analysis labels
            HStack(spacing: 12) {
                analysisLabel(icon: "waveform", text: "Voice", color: .primary)
                analysisLabel(icon: "speedometer", text: "Pacing", color: .secondary)
                analysisLabel(icon: "figure.wave", text: "Gestures", color: .info)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.largeSpacing)
        .onAppear { pulse = true }
    }

    private func analysisLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Page 4: Instant Feedback

private struct InstantFeedbackPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("Get Instant Feedback")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("After each session, the AI scores your\ntone, pacing, and body language.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Feedback score diagram
            VStack(spacing: 14) {
                // Overall score ring
                ZStack {
                    Circle()
                        .stroke(Color.border, lineWidth: 10)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: 0.82)
                        .stroke(
                            LinearGradient(
                                colors: [.primary, .secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("82")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        Text("out of 100")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                    }
                }

                // Score cards
                VStack(spacing: 8) {
                    scoreRow(icon: "waveform", title: "Tone", score: 85, color: .primary)
                    scoreRow(icon: "speedometer", title: "Pacing", score: 78, color: .secondary)
                    scoreRow(icon: "figure.wave", title: "Gestures", score: 82, color: .info)
                }
                .padding(Theme.spacing)
                .background(Color.bgLight)
                .cornerRadius(Theme.cornerRadius)

                // AI insight mockup
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)

                    Text("Your tone was confident. Try slowing down during key points for emphasis.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .lineSpacing(2)
                }
                .padding(12)
                .background(Color.bgLight)
                .cornerRadius(Theme.cornerRadius)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.largeSpacing)
    }

    private func scoreRow(icon: String, title: String, score: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Spacer()

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
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Page 5: Track Progress

private struct TrackProgressPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("Watch Yourself Improve")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Practice multiple sessions and track your growth with charts and streaks.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 14) {
                // Streak banner mockup
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.danger)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("5-Day Streak")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Keep it going!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.danger.opacity(0.1))
                .cornerRadius(Theme.smallCornerRadius)

                // Chart mockup
                VStack(alignment: .leading, spacing: 10) {
                    Text("Performance Over Time")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    // Fake chart with rising line
                    ZStack(alignment: .bottomLeading) {
                        // Grid lines
                        VStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { _ in
                                Spacer()
                                Rectangle()
                                    .fill(Color.border.opacity(0.5))
                                    .frame(height: 1)
                            }
                        }
                        .frame(height: 100)

                        // Line chart path
                        GeometryReader { geo in
                            let points: [CGFloat] = [0.58, 0.63, 0.60, 0.70, 0.74, 0.82]
                            let w = geo.size.width
                            let h = geo.size.height

                            // Area fill
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: h))
                                for (i, p) in points.enumerated() {
                                    let x = w * CGFloat(i) / CGFloat(points.count - 1)
                                    let y = h * (1 - p)
                                    if i == 0 {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                                path.addLine(to: CGPoint(x: w, y: h))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [Color.primary.opacity(0.3), Color.primary.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            // Line
                            Path { path in
                                for (i, p) in points.enumerated() {
                                    let x = w * CGFloat(i) / CGFloat(points.count - 1)
                                    let y = h * (1 - p)
                                    if i == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [.primary, .secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )

                            // Dots
                            ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 7, height: 7)
                                    .position(
                                        x: w * CGFloat(i) / CGFloat(points.count - 1),
                                        y: h * (1 - p)
                                    )
                            }
                        }
                        .frame(height: 100)
                    }

                    // Session labels
                    HStack {
                        ForEach(1...6, id: \.self) { i in
                            Text("\(i)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.textMuted)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(Theme.spacing)
                .background(Color.bgLight)
                .cornerRadius(Theme.cornerRadius)

                // Improvement pill
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.success)
                        Text("+24% overall")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.success)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary)
                        Text("6 sessions")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.largeSpacing)
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
