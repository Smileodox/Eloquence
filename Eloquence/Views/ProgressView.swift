//
//  ProgressView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI
import Charts

struct ProgressView: View {
    @EnvironmentObject var userSession: UserSession
    let initialProject: Project?

    @State private var selectedProject: Project?
    @State private var showProjectPicker = false
    @State private var showDeleteProjectAlert = false
    @State private var showEditProjectSheet = false
    @State private var editingProject: Project?
    @State private var selectedSession: PracticeSession? = nil

    init(initialProject: Project? = nil) {
        self.initialProject = initialProject
    }

    private var filteredSessions: [PracticeSession] {
        if let project = selectedProject {
            return userSession.sessions.filter { $0.projectId == project.id }
        }
        return userSession.sessions
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.largeSpacing) {
                    // 1. Practice Streak Banner
                    StreakBannerView(
                        streakCount: userSession.currentStreak,
                        longestStreak: userSession.longestStreak
                    )
                    .padding(.horizontal, Theme.largeSpacing)
                    .padding(.top, Theme.spacing)

                    // 2. Overall Performance Hero
                    overallScoreHeroSection

                    // 3. Project Filter
                    projectFilterSection

                    // 4. Overall Performance Chart (Single Line)
                    if !filteredSessions.isEmpty {
                        overallChartSection
                    } else {
                        emptyChartView
                    }

                    // 5. Metric Deep-Dive Cards (NavigationLinks)
                    metricCardsSection

                    // Recordings button (only shown when project is selected)
                    if selectedProject != nil {
                        recordingsButton
                    }

                    // Project Actions (only if project is selected)
                    if let project = selectedProject {
                        projectActionsSection(project: project)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Progress & Insights")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if let initialProject = initialProject {
                selectedProject = initialProject
            }
        }
        .confirmationDialog("Select Project", isPresented: $showProjectPicker, titleVisibility: .visible) {
            Button("All Projects") {
                selectedProject = nil
            }

            ForEach(userSession.projects) { project in
                Button(project.name) {
                    selectedProject = project
                }
            }
        }
        .alert("Delete Project", isPresented: $showDeleteProjectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let project = selectedProject {
                    userSession.deleteProject(project)
                    selectedProject = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this project? This will also remove all associated sessions.")
        }
        .sheet(isPresented: $showEditProjectSheet) {
            if let project = editingProject {
                EditProjectSheet(
                    project: project,
                    onSave: { updatedProject in
                        userSession.updateProject(updatedProject)
                        if selectedProject?.id == updatedProject.id {
                            selectedProject = updatedProject
                        }
                        editingProject = nil
                    },
                    onCancel: {
                        editingProject = nil
                    }
                )
            }
        }
    }

    // MARK: - Overall Score Hero Section

    private var overallScoreHeroSection: some View {
        VStack(spacing: Theme.spacing) {
            Text("Overall Performance")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textMuted)

            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.border, lineWidth: 14)
                    .frame(width: 150, height: 150)

                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(overallScore) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.primary, .secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(overallScore)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text("out of 100")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                }
            }

            // Trend indicator
            if filteredSessions.count >= 2 {
                let change = userSession.scoreChange(for: filteredSessions)
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(change >= 0 ? "+" : "")\(change) vs last session")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(change >= 0 ? Color.success : Color.danger)
            }

            // Last practiced
            if let lastDate = lastPracticeDateFormatted {
                Text("Last practiced: \(lastDate)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textMuted)
            }
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }

    private var overallScore: Int {
        userSession.overallAverageScore(for: filteredSessions)
    }

    private var lastPracticeDateFormatted: String? {
        guard let lastDate = filteredSessions.map({ $0.date }).max() else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: Date())).day ?? 0

        if days == 0 { return "today" }
        else if days == 1 { return "yesterday" }
        else { return "\(days) days ago" }
    }

    // MARK: - Project Filter Section

    private var projectFilterSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Project")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Button(action: {
                showProjectPicker = true
            }) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.primary)

                    Text(selectedProject?.name ?? "All Projects")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textMuted)
                }
                .padding(Theme.spacing)
                .background(Color.bgLight)
                .cornerRadius(Theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Color.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Due Date Info
            if let project = selectedProject, let dueDate = project.dueDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.warning)

                    Text("Due: \(Self.formatDate(dueDate))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                }
                .padding(.horizontal, Theme.spacing)
                .padding(.vertical, 8)
                .background(Color.warning.opacity(0.1))
                .cornerRadius(Theme.smallCornerRadius)
            }
        }
        .padding(.horizontal, Theme.largeSpacing)
    }

    // MARK: - Overall Chart Section (Single Line)

    private var overallChartSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Performance Over Time")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            let sessions = filteredSessions.sorted { $0.date < $1.date }
            let improvement = improvementPercentage

            Chart {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    LineMark(
                        x: .value("Session", index + 1),
                        y: .value("Score", session.averageScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .symbol {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 10, height: 10)
                    }

                    AreaMark(
                        x: .value("Session", index + 1),
                        y: .value("Score", session.averageScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.3), Color.primary.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .interpolationMethod(.catmullRom)
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let location = value.location
                                if let (index, selected) = indexOfClosestSession(to: location, in: proxy, geo: geo, sessions: sessions) {
                                    selectedSession = selected
                                } else {
                                    selectedSession = nil
                                }
                            }
                            .onEnded { _ in }
                        )
                }
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
            .overlay(
                Group {
                    if let selected = selectedSession {
                        ChartSessionDetailOverlay(selectedSession: selected, filteredSessions: filteredSessions, userSession: userSession, onClose: { selectedSession = nil })
                    }
                }
            )

            // Stats row
            HStack(spacing: Theme.largeSpacing) {
                statPill(
                    value: "\(filteredSessions.count)",
                    label: "Sessions",
                    icon: "mic.circle.fill"
                )

                if filteredSessions.count >= 2 {
                    statPill(
                        value: improvement >= 0 ? "+\(improvement)%" : "\(improvement)%",
                        label: "Overall",
                        icon: "chart.line.uptrend.xyaxis",
                        isPositive: improvement >= 0
                    )
                } else {
                    EmptyView()
                }
            }
            .padding(.top, 8)
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }

    private func statPill(value: String, label: String, icon: String, isPositive: Bool? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(
                    isPositive == nil ? Color.primary :
                        (isPositive! ? Color.success : Color.danger)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textMuted)
            }
        }
    }

    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(Color.textMuted)

            Text(selectedProject == nil ? "No sessions yet" : "No sessions for this project")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textMuted)

            Text(selectedProject == nil ? "Start practicing to see your progress" : "Record videos for this project to see progress")
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

    // MARK: - Metric Cards Section

    private var metricCardsSection: some View {
        // Move all logic outside the ViewBuilder:
        let (toneScore, pacingScore, gesturesScore, toneChange, pacingChange, gesturesChange): (Int, Int, Int, Int, Int, Int)
        if let selected = selectedSession {
            (toneScore, pacingScore, gesturesScore, toneChange, pacingChange, gesturesChange) = (selected.toneScore, selected.pacingScore, selected.gesturesScore, 0, 0, 0)
        } else {
            (toneScore, pacingScore, gesturesScore, toneChange, pacingChange, gesturesChange) = (
                userSession.averageToneScore(for: filteredSessions),
                userSession.averagePacingScore(for: filteredSessions),
                userSession.averageGesturesScore(for: filteredSessions),
                userSession.metricScoreChange(for: filteredSessions, metric: .tone),
                userSession.metricScoreChange(for: filteredSessions, metric: .pacing),
                userSession.metricScoreChange(for: filteredSessions, metric: .bodyLanguage)
            )
        }

        return VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Detailed Metrics")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Theme.largeSpacing)

            VStack(spacing: 12) {
                // Tone Card
                NavigationLink(destination: MetricDetailView(metricType: .tone, sessions: filteredSessions)) {
                    metricCard(
                        type: .tone,
                        score: toneScore,
                        change: toneChange
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Pacing Card
                NavigationLink(destination: MetricDetailView(metricType: .pacing, sessions: filteredSessions)) {
                    metricCard(
                        type: .pacing,
                        score: pacingScore,
                        change: pacingChange
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Body Language Card
                NavigationLink(destination: BodyLanguageDetailView(sessions: filteredSessions)) {
                    metricCard(
                        type: .bodyLanguage,
                        score: gesturesScore,
                        change: gesturesChange
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, Theme.largeSpacing)
        }
    }

    private func metricCard(type: MetricType, score: Int, change: Int) -> some View {
        HStack(spacing: Theme.spacing) {
            // Icon
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(type.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(type.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.border)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(type.color)
                            .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                    }
                }
                .frame(height: 8)

                // Change indicator
                if filteredSessions.count >= 2 && change != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(change >= 0 ? "+" : "")\(change) vs last")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(change >= 0 ? Color.success : Color.danger)
                }
            }

            Spacer()

            // Score
            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textMuted)
        }
        .padding(Theme.spacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    // MARK: - Recordings Button

    private var recordingsButton: some View {
        NavigationLink(destination: RecordingsListView(filterProject: selectedProject)) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "video.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.primary)

                        Spacer()
                    }

                    Text("Recordings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("View and manage your practice videos")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(Theme.largeSpacing)
            .background(Color.bgLight)
            .cornerRadius(Theme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, Theme.largeSpacing)
        .padding(.bottom, Theme.largeSpacing)
    }

    // MARK: - Project Actions

    private func projectActionsSection(project: Project) -> some View {
        HStack(spacing: Theme.spacing) {
            // Edit Button
            Button(action: {
                editingProject = project
                showEditProjectSheet = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))

                    Text("Edit")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: Theme.buttonHeight)
                .foregroundStyle(Color.primary)
                .background(Color.bgLight)
                .cornerRadius(Theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Color.primary, lineWidth: 2)
                )
            }

            // Delete Button
            Button(action: {
                showDeleteProjectAlert = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18))

                    Text("Delete")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: Theme.buttonHeight)
                .foregroundStyle(Color.danger)
                .background(Color.bgLight)
                .cornerRadius(Theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Color.danger, lineWidth: 2)
                )
            }
        }
        .padding(.horizontal, Theme.largeSpacing)
        .padding(.bottom, Theme.largeSpacing)
    }

    // MARK: - Helper Methods

    private var improvementPercentage: Int {
        guard filteredSessions.count >= 2 else { return 0 }
        let sortedSessions = filteredSessions.sorted { $0.date < $1.date }
        let first = sortedSessions.first!
        let last = sortedSessions.last!
        let firstAvg = first.averageScore
        let lastAvg = last.averageScore
        let improvement = ((lastAvg - firstAvg) * 100) / max(firstAvg, 1)
        return improvement
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func indexOfClosestSession(to location: CGPoint, in proxy: ChartProxy, geo: GeometryProxy, sessions: [PracticeSession]) -> (Int, PracticeSession)? {
        let points = sessions.enumerated().compactMap { (index, session) -> (CGFloat, PracticeSession)? in
            let xValue = Double(index + 1)
            if let xPos = proxy.position(forX: xValue) {
                return (xPos, session)
            }
            return nil
        }
        let tapX = location.x
        let closest = points.min(by: { abs($0.0 - tapX) < abs($1.0 - tapX) })
        if let closest = closest, let idx = points.firstIndex(where: { $0.0 == closest.0 }) {
            return (idx, closest.1)
        }
        return nil
    }
}

// MARK: - Chart Session Detail Overlay

struct ChartSessionDetailOverlay: View {
    let selectedSession: PracticeSession
    let filteredSessions: [PracticeSession]
    let userSession: UserSession
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            let sortedSessions = filteredSessions.sorted(by: { $0.date < $1.date })
            if let index = sortedSessions.firstIndex(where: { $0.id == selectedSession.id }) {
                let xRatio = CGFloat(index) / CGFloat(max(sortedSessions.count - 1, 1))
                let xPos = geo.size.width * xRatio

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Spacer()

                        Button(action: onClose) {
                            ZStack {
                                Circle().fill(Color.bgLight)
                                Image(systemName: "xmark")
                                    .foregroundStyle(Color.textMuted)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .frame(width: 26, height: 26)
                        }
                    }

                    Text(ProgressView.formatDate(selectedSession.date))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)

                    if let type = selectedSession.recordingType, !type.isEmpty {
                        Text("Type: \(type)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if let projectId = selectedSession.projectId, let projectName = userSession.projects.first(where: { $0.id == projectId })?.name {
                        Text("Project: \(projectName)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color.bgLight)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10).stroke(Color.border, lineWidth: 1)
                )
                .frame(width: 150)
                .position(x: min(max(xPos, 75), geo.size.width - 75), y: 30)
            }
        }
        .frame(height: 60)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.spacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textMuted)
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textMuted)

            Spacer()

            HStack(spacing: 12) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.border)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(value) / 100, height: 6)
                    }
                }
                .frame(width: 80, height: 6)

                Text("\(value)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 35, alignment: .trailing)
            }
        }
    }
}

struct SessionDetailCard: View {
    let session: PracticeSession
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Details")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            Text("Date: \(Self.formatDate(session.date))")
                .font(.subheadline)
                .foregroundStyle(Color.textPrimary)
            if let recordingType = session.recordingType {
                Text("Recording Type: \(recordingType)")
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
            }
            if let projectId = session.projectId, let projectName = projectName(for: projectId) {
                Text("Project: \(projectName)")
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .padding(12)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Color.border, lineWidth: 1)
        )
        .padding(.top, 8)
    }

    private func projectName(for projectId: UUID) -> String? {
        userSession.projects.first(where: { $0.id == projectId })?.name
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ProgressView()
            .environmentObject(UserSession())
    }
}

