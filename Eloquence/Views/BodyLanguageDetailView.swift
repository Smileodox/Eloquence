//
//  BodyLanguageDetailView.swift
//  Eloquence
//
//  Detail view for Body Language metric with sub-metrics and visual highlights
//

import SwiftUI
import Charts

struct BodyLanguageDetailView: View {
    @EnvironmentObject var userSession: UserSession
    let sessions: [PracticeSession]

    private var sortedSessions: [PracticeSession] {
        sessions.sorted { $0.date < $1.date }
    }

    private var averageScore: Int {
        userSession.averageGesturesScore(for: sessions)
    }

    private var scoreChange: Int {
        userSession.metricScoreChange(for: sessions, metric: .bodyLanguage)
    }

    private var allKeyFrames: [KeyFrame] {
        sessions.compactMap { $0.keyFrames }.flatMap { $0 }
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.largeSpacing) {
                    // Hero Score Section
                    heroScoreSection

                    // Sub-metrics Section
                    subMetricsSection

                    // Chart Section
                    if !sortedSessions.isEmpty {
                        chartSection
                    }

                    // Visual Highlights Gallery
                    if !allKeyFrames.isEmpty {
                        visualHighlightsSection
                    }

                    // AI Insights Section
                    aiInsightsSection

                    // Session History
                    if !sortedSessions.isEmpty {
                        sessionHistorySection
                    }
                }
                .padding(.bottom, Theme.largeSpacing)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Body Language")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Hero Score Section

    private var heroScoreSection: some View {
        VStack(spacing: Theme.spacing) {
            ZStack {
                Circle()
                    .fill(Color.info.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "figure.wave")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.info)
            }

            VStack(spacing: 8) {
                Text("\(averageScore)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Average Body Language Score")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textMuted)

                if sessions.count >= 2 {
                    HStack(spacing: 4) {
                        Image(systemName: scoreChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .bold))

                        Text("\(scoreChange >= 0 ? "+" : "")\(scoreChange) vs last session")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(scoreChange >= 0 ? Color.success : Color.danger)
                }
            }
        }
        .padding(.vertical, Theme.largeSpacing)
        .frame(maxWidth: .infinity)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
        .padding(.top, Theme.spacing)
    }

    // MARK: - Sub-metrics Section

    private var subMetricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Breakdown")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 12) {
                // Facial Expression
                subMetricCard(
                    icon: "face.smiling",
                    title: "Facial Expression",
                    score: userSession.averageFacialScore(for: sessions),
                    description: "Expressiveness and emotional engagement"
                )

                // Posture
                subMetricCard(
                    icon: "figure.stand",
                    title: "Posture",
                    score: userSession.averagePostureScore(for: sessions),
                    description: "Body alignment and confident stance"
                )

                // Eye Contact
                subMetricCard(
                    icon: "eye",
                    title: "Eye Contact",
                    score: userSession.averageEyeContactScore(for: sessions),
                    description: "Connection with audience through gaze"
                )
            }
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }

    private func subMetricCard(icon: String, title: String, score: Int?, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.info.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Color.info)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                }

                Spacer()

                if let score = score {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(score)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)

                        Text("/100")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                    }
                } else {
                    Text("No data")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .italic()
                }
            }

            if let score = score {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.border)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(scoreColor(score))
                            .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(12)
        .background(Color.bg)
        .cornerRadius(Theme.smallCornerRadius)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .success }
        else if score >= 50 { return .warning }
        else { return .danger }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Body Language Over Time")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Chart {
                ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                    LineMark(
                        x: .value("Session", index + 1),
                        y: .value("Score", session.gesturesScore)
                    )
                    .foregroundStyle(Color.info)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .symbol {
                        Circle()
                            .fill(Color.info)
                            .frame(width: 10, height: 10)
                    }

                    AreaMark(
                        x: .value("Session", index + 1),
                        y: .value("Score", session.gesturesScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.info.opacity(0.3), Color.info.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 180)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.border)
                    AxisValueLabel()
                        .foregroundStyle(Color.textMuted)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(Color.border)
                    AxisValueLabel()
                        .foregroundStyle(Color.textMuted)
                }
            }
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }

    // MARK: - Visual Highlights Gallery

    private var visualHighlightsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.info)

                Text("Visual Highlights")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            // Strengths
            let positiveFrames = allKeyFrames.filter { $0.isPositive }
            if !positiveFrames.isEmpty {
                Text("Your Strengths")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
                    .padding(.top, 4)

                keyFrameGallery(frames: Array(positiveFrames.prefix(4)))
            }

            // Areas to improve
            let improvementFrames = allKeyFrames.filter { !$0.isPositive }
            if !improvementFrames.isEmpty {
                Text("Areas to Improve")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
                    .padding(.top, positiveFrames.isEmpty ? 4 : 12)

                keyFrameGallery(frames: Array(improvementFrames.prefix(4)))
            }
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }

    private func keyFrameGallery(frames: [KeyFrame]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(frames) { keyFrame in
                keyFrameThumbnail(keyFrame)
            }
        }
    }

    private func keyFrameThumbnail(_ keyFrame: KeyFrame) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                if let uiImage = UIImage(data: keyFrame.image) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.border)
                        .frame(height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.textMuted)
                        )
                }

                // Score badge
                Text("\(keyFrame.score)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(keyFrame.isPositive ? Color.success : Color.warning)
                    .clipShape(Capsule())
                    .padding(6)
            }

            Text(keyFrame.primaryMetric)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textMuted)
                .lineLimit(1)
        }
    }

    // MARK: - AI Insights Section

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.info)

                Text("AI Recommendations")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            // Strength
            if let strength = latestStrength {
                insightCard(
                    icon: "checkmark.circle.fill",
                    title: "Strength",
                    message: strength,
                    color: .success
                )
            }

            // Improvement
            if let improvement = latestImprovement {
                insightCard(
                    icon: "lightbulb.fill",
                    title: "Focus Area",
                    message: improvement,
                    color: .warning
                )
            }

            // Pro tip
            insightCard(
                icon: "figure.stand",
                title: "Pro Tip",
                message: "Open posture and purposeful gestures convey confidence. Try recording yourself to see what your audience sees.",
                color: .info
            )
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }

    private func insightCard(icon: String, title: String, message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)

                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(Theme.smallCornerRadius)
    }

    private var latestStrength: String? {
        if let lastSession = sortedSessions.last, let strength = lastSession.gestureStrength {
            return strength
        }
        return nil
    }

    private var latestImprovement: String? {
        if let lastSession = sortedSessions.last, let improvement = lastSession.gestureImprovement {
            return improvement
        }
        return nil
    }

    // MARK: - Session History Section

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Session History")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            ForEach(sortedSessions.reversed()) { session in
                NavigationLink(destination: FeedbackView(session: session, entryPoint: .progressView)) {
                    sessionRow(session)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }

    private func sessionRow(_ session: PracticeSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(session.date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: 8) {
                    if session.facialScore != nil || session.postureScore != nil || session.eyeContactScore != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.success)
                        Text("Sub-metrics available")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                    } else {
                        Text(formatTime(session.date))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                    }
                }
            }

            Spacer()

            HStack(spacing: 12) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.border)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.info)
                            .frame(width: geometry.size.width * CGFloat(session.gesturesScore) / 100, height: 6)
                    }
                }
                .frame(width: 60, height: 6)

                Text("\(session.gesturesScore)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 35, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
            }
        }
        .padding(12)
        .background(Color.bg)
        .cornerRadius(Theme.smallCornerRadius)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        BodyLanguageDetailView(
            sessions: [
                PracticeSession(
                    date: Date().addingTimeInterval(-86400 * 3),
                    toneScore: 72,
                    pacingScore: 68,
                    gesturesScore: 70,
                    facialScore: 75,
                    postureScore: 68,
                    eyeContactScore: 72
                ),
                PracticeSession(
                    date: Date().addingTimeInterval(-86400),
                    toneScore: 85,
                    pacingScore: 80,
                    gesturesScore: 82,
                    gestureStrength: "Great use of open hand gestures!",
                    gestureImprovement: "Try maintaining eye contact with different areas of the room.",
                    facialScore: 88,
                    postureScore: 80,
                    eyeContactScore: 78
                )
            ]
        )
        .environmentObject(UserSession())
    }
}

