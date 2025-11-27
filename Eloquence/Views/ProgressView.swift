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
                    // Project Filter
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
                                
                                Text("Due: \(formatDate(dueDate))")
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
                    .padding(.top, Theme.spacing)
                    
                    // Stats cards
                    HStack(spacing: Theme.spacing) {
                        StatCard(
                            title: "Total Sessions",
                            value: "\(filteredSessions.count)",
                            icon: "mic.circle.fill",
                            color: Color.primary
                        )
                        
                        StatCard(
                            title: "Improvement",
                            value: improvementPercentage > 0 ? "+\(improvementPercentage)%" : "\(improvementPercentage)%",
                            icon: "chart.line.uptrend.xyaxis",
                            color: improvementPercentage > 0 ? Color.success : Color.danger
                        )
                    }
                    .padding(.horizontal, Theme.largeSpacing)
                    
                    // Performance chart
                    if !filteredSessions.isEmpty {
                        chartSection
                    } else {
                        emptyChartView
                    }
                    
                    // Key metrics (only shown when project is selected)
                    if selectedProject != nil && !filteredSessions.isEmpty {
                        keyMetricsSection
                    }
                    
                    // Recordings button (only shown when project is selected)
                    if selectedProject != nil {
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
                    
                    // Project Actions (only if project is selected)
                    if let project = selectedProject {
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
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Performance Over Time")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            
            let sessions = filteredSessions
            
            Chart {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    LineMark(
                        x: .value("Session", index + 1),
                        y: .value("Tone", session.toneScore)
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .symbol {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                .interpolationMethod(.catmullRom)
                
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    LineMark(
                        x: .value("Session", index + 1),
                        y: .value("Pacing", session.pacingScore)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .symbol {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                .interpolationMethod(.catmullRom)
                
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    LineMark(
                        x: .value("Session", index + 1),
                        y: .value("Gestures", session.gesturesScore)
                    )
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .symbol {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    }
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
            
            // Legend
            HStack(spacing: Theme.largeSpacing) {
                LegendItem(color: Color.blue, label: "Tone")
                LegendItem(color: Color.green, label: "Pacing")
                LegendItem(color: Color.orange, label: "Gestures")
            }
            .padding(.top, Theme.spacing)
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }
    
    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Key Metrics")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            
            let lastSession = filteredSessions.last!
            
            VStack(spacing: 12) {
                MetricRow(
                    title: "Average Tone",
                    value: averageScore(for: \.toneScore),
                    color: Color.blue
                )
                
                MetricRow(
                    title: "Average Pacing",
                    value: averageScore(for: \.pacingScore),
                    color: Color.green
                )
                
                MetricRow(
                    title: "Average Gestures",
                    value: averageScore(for: \.gesturesScore),
                    color: Color.orange
                )
            }
        }
        .padding(Theme.largeSpacing)
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.largeSpacing)
    }
    
    private func averageScore(for keyPath: KeyPath<PracticeSession, Int>) -> Int {
        guard !filteredSessions.isEmpty else { return 0 }
        let total = filteredSessions.reduce(0) { $0 + $1[keyPath: keyPath] }
        return total / filteredSessions.count
    }
    
    private var improvementPercentage: Int {
        guard filteredSessions.count >= 2 else { return 0 }
        let first = filteredSessions.first!
        let last = filteredSessions.last!
        let firstAvg = (first.toneScore + first.pacingScore + first.gesturesScore) / 3
        let lastAvg = (last.toneScore + last.pacingScore + last.gesturesScore) / 3
        let improvement = ((lastAvg - firstAvg) * 100) / max(firstAvg, 1)
        return improvement
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

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

#Preview {
    NavigationStack {
        ProgressView()
            .environmentObject(UserSession())
    }
}
