//
//  MetricDetailView.swift
//  Eloquence
//
//  Detail view for drilling down into Tone or Pacing metrics
//

import SwiftUI
import Charts

struct MetricDetailView: View {
    @EnvironmentObject var userSession: UserSession
    let metricType: MetricType
    let sessions: [PracticeSession]

    private var sortedSessions: [PracticeSession] {
        sessions.sorted { $0.date < $1.date }
    }

    private var averageScore: Int {
        guard !sessions.isEmpty else { return 0 }
        switch metricType {
        case .tone:
            return userSession.averageToneScore(for: sessions)
        case .pacing:
            return userSession.averagePacingScore(for: sessions)
        case .bodyLanguage:
            return userSession.averageGesturesScore(for: sessions)
        }
    }

    private var scoreChange: Int {
        userSession.metricScoreChange(for: sessions, metric: metricType)
    }

    private func scoreForSession(_ session: PracticeSession) -> Int {
        switch metricType {
        case .tone: return session.toneScore
        case .pacing: return session.pacingScore
        case .bodyLanguage: return session.gesturesScore
        }
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.largeSpacing) {
                    // Hero Score Section
                    heroScoreSection

                    // Chart Section
                    if !sortedSessions.isEmpty {
                        chartSection
                    } else {
                        emptyChartView
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
                Text(metricType.rawValue)
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
                    .fill(metricType.color.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: metricType.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(metricType.color)
            }

            VStack(spacing: 8) {
                Text("\(averageScore)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Average Score")
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

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("\(metricType.rawValue) Over Time")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Chart {
                ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                    LineMark(
                        x: .value("Session", index + 1),
                        y: .value(metricType.rawValue, scoreForSession(session))
                    )
                    .foregroundStyle(metricType.color)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .symbol {
                        Circle()
                            .fill(metricType.color)
                            .frame(width: 10, height: 10)
                    }

                    AreaMark(
                        x: .value("Session", index + 1),
                        y: .value(metricType.rawValue, scoreForSession(session))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [metricType.color.opacity(0.3), metricType.color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
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

    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(Color.textMuted)

            Text("No data yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textMuted)

            Text("Start practicing to see your \(metricType.rawValue.lowercased()) progress")
                .font(.system(size: 14))
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }

    // MARK: - AI Insights Section

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(metricType.color)

                Text("AI Insights")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            // Strengths
            if let strength = latestStrength {
                insightCard(
                    icon: "checkmark.circle.fill",
                    title: "Strength",
                    message: strength,
                    color: .success
                )
            }

            // Areas to improve
            if let improvement = latestImprovement {
                insightCard(
                    icon: "lightbulb.fill",
                    title: "Focus Area",
                    message: improvement,
                    color: .warning
                )
            }

            // Tip based on metric type
            metricTipCard
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

    private var metricTipCard: some View {
        let (tip, icon) = metricTip
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(metricType.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Pro Tip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(metricType.color)

                Text(tip)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(metricType.color.opacity(0.1))
        .cornerRadius(Theme.smallCornerRadius)
    }

    private var metricTip: (String, String) {
        switch metricType {
        case .tone:
            return ("Vary your pitch and emphasis to keep your audience engaged. Practice pausing before important points.", "waveform.badge.magnifyingglass")
        case .pacing:
            return ("Aim for 120-150 words per minute for optimal comprehension. Use strategic pauses to let key points sink in.", "timer")
        case .bodyLanguage:
            return ("Make eye contact with different areas of your audience. Open gestures convey confidence.", "figure.stand")
        }
    }

    private var latestStrength: String? {
        guard let lastSession = sortedSessions.last else { return nil }

        switch metricType {
        case .tone:
            return lastSession.toneStrength
        case .pacing:
            return lastSession.pacingStrength
        case .bodyLanguage:
            return lastSession.gestureStrength
        }
    }

    private var latestImprovement: String? {
        guard let lastSession = sortedSessions.last else { return nil }

        switch metricType {
        case .tone:
            return lastSession.toneImprovement
        case .pacing:
            return lastSession.pacingImprovement
        case .bodyLanguage:
            return lastSession.gestureImprovement
        }
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

                Text(formatTime(session.date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()

            HStack(spacing: 12) {
                // Score bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.border)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(metricType.color)
                            .frame(width: geometry.size.width * CGFloat(scoreForSession(session)) / 100, height: 6)
                    }
                }
                .frame(width: 60, height: 6)

                Text("\(scoreForSession(session))")
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
        MetricDetailView(
            metricType: .tone,
            sessions: [
                PracticeSession(date: Date().addingTimeInterval(-86400 * 5), toneScore: 72, pacingScore: 68, gesturesScore: 70),
                PracticeSession(date: Date().addingTimeInterval(-86400 * 3), toneScore: 78, pacingScore: 74, gesturesScore: 75),
                PracticeSession(date: Date().addingTimeInterval(-86400), toneScore: 85, pacingScore: 80, gesturesScore: 82)
            ]
        )
        .environmentObject(UserSession())
    }
}
