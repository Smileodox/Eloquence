//
//  DashboardView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var navigateToRecording = false
    @State private var navigateToProgress = false
    @State private var navigateToSettings = false
    
    private var activeProjects: [Project] {
        let now = Date()
        return userSession.projects.filter { project in
            guard let dueDate = project.dueDate else { return false }
            return dueDate >= now
        }
        .sorted { project1, project2 in
            guard let dueDate1 = project1.dueDate, let dueDate2 = project2.dueDate else { return false }
            return dueDate1 < dueDate2
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.bg
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.largeSpacing) {
                        // Welcome message
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome back,")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.textMuted)
                            
                            Text(userSession.userName)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.largeSpacing)
                        .padding(.top, 20)
                        
                        // Progress widget
                        VStack(spacing: Theme.spacing) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Session")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.textMuted)
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(userSession.lastImprovement > 0 ? "+\(userSession.lastImprovement)%" : "\(userSession.lastImprovement)%")
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundStyle(userSession.lastImprovement > 0 ? Color.success : Color.danger)
                                        
                                        Text("improvement")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color.textMuted)
                                    }
                                }
                                
                                Spacer()
                                
                                ZStack {
                                    Circle()
                                        .stroke(Color.border, lineWidth: 8)
                                        .frame(width: 70, height: 70)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(userSession.averageScore) / 100)
                                        .stroke(Color.success, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .frame(width: 70, height: 70)
                                        .rotationEffect(.degrees(-90))
                                    
                                    Text("\(userSession.averageScore)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Color.textPrimary)
                                }
                            }
                            
                            if !userSession.sessions.isEmpty {
                                Text("Keep up the great work! You're on a roll.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(Theme.largeSpacing)
                        .background(Color.bgLight)
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal, Theme.largeSpacing)
                        
                        // Main action buttons
                        VStack(spacing: Theme.spacing) {
                            // Start New Session
                            NavigationLink(destination: RecordingSetupView()) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "mic.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundStyle(Color.primary.opacity(0.7))
                                            
                                            Spacer()
                                        }
                                        
                                        Text("Start New Session")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(Color.textPrimary)
                                        
                                        Text("Practice your presentation skills")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color.textMuted)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color.primary.opacity(0.7))
                                }
                                .padding(Theme.largeSpacing)
                                .background(Color.bgLight)
                                .cornerRadius(Theme.cornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                        .stroke(.primary.opacity(0.3), lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            HStack(spacing: Theme.spacing) {
                                // View Project Progress
                                NavigationLink(destination: ProgressView()) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 28))
                                            .foregroundStyle(Color.info)
                                        
                                        Spacer()
                                        
                                        Text("View Project Progress")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.textPrimary)
                                        
                                        Text("\(userSession.sessions.count) sessions")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.textMuted)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 160)
                                    .padding(Theme.spacing)
                                    .background(Color.bgLight)
                                    .cornerRadius(Theme.cornerRadius)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Recordings
                                NavigationLink(destination: RecordingsListView(filterProject: nil)) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(Color.info)
                                        
                                        Spacer()
                                        
                                        Text("Recordings")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.textPrimary)
                                        
                                        Text("View videos")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.textMuted)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 160)
                                    .padding(Theme.spacing)
                                    .background(Color.bgLight)
                                    .cornerRadius(Theme.cornerRadius)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, Theme.largeSpacing)
                        
                        // Active Projects
                        if !activeProjects.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.spacing) {
                                Text("Active Projects")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                                
                                VStack(spacing: Theme.spacing) {
                                    ForEach(activeProjects) { project in
                                        ProjectCard(project: project)
                                    }
                                }
                            }
                            .padding(Theme.largeSpacing)
                            .background(Color.bgLight)
                            .cornerRadius(Theme.cornerRadius)
                            .padding(.horizontal, Theme.largeSpacing)
                            .padding(.bottom, Theme.largeSpacing)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct ProjectCard: View {
    let project: Project
    @EnvironmentObject var userSession: UserSession
    
    private var daysUntilDue: Int? {
        guard let dueDate = project.dueDate else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: dueDate)
        return components.day
    }
    
    var body: some View {
        NavigationLink(destination: ProgressView(initialProject: project)) {
            HStack(spacing: Theme.spacing) {
                // Project Icon
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.primary)
                }
                
                // Project Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    
                    if let days = daysUntilDue {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundStyle(days <= 7 ? Color.danger : Color.warning)
                            
                            Text("\(days) days left")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(days <= 7 ? Color.danger : Color.warning)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(Theme.spacing)
            .background(Color.bg)
            .cornerRadius(Theme.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DashboardView()
        .environmentObject(UserSession())
}

