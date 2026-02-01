//
//  RecordingSetupView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI

struct RecordingSetupView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var selectedType: RecordingType = .professional
    @State private var selectedProject: Project?
    @State private var showNewProjectAlert = false
    @State private var newProjectName = ""
    @State private var newProjectDueDate = Date()
    @State private var hasDueDate = false
    @State private var navigateToRecording = false
    @State private var navigateToAnalyzing = false
    @State private var selectedVideoURL: URL?
    @State private var showVideoPicker = false
    
    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            
            VStack(spacing: Theme.largeSpacing) {
                // Header
                VStack(spacing: 12) {
                    Text("Setup Recording")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("Configure your practice session")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                }
                .padding(.top, Theme.largeSpacing)
                
                ScrollView {
                    VStack(spacing: Theme.largeSpacing) {
                        // Recording Type Selection
                        VStack(alignment: .leading, spacing: Theme.spacing) {
                            Text("Recording Type")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            
                            HStack(spacing: Theme.spacing) {
                                ForEach(RecordingType.allCases, id: \.self) { type in
                                    Button(action: {
                                        selectedType = type
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 24))
                                                .foregroundStyle(selectedType == type ? Color.bg : Color.textMuted)
                                            
                                            Text(type.rawValue)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(selectedType == type ? Color.bg : Color.textMuted)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100)
                                        .background(selectedType == type ? Color.primary : Color.bgLight)
                                        .cornerRadius(Theme.cornerRadius)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                                .stroke(selectedType == type ? Color.primary : Color.border, lineWidth: selectedType == type ? 2 : 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(Theme.largeSpacing)
                        .background(Color.bgLight)
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal, Theme.largeSpacing)
                        
                        // Project Selection
                        VStack(alignment: .leading, spacing: Theme.spacing) {
                            HStack {
                                Text("Project")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showNewProjectAlert = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16))
                                        Text("New")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.primary)
                                }
                            }
                            
                            if userSession.projects.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 40))
                                        .foregroundStyle(Color.textMuted)
                                    
                                    Text("No projects yet")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.textMuted)
                                    
                                    Text("Create your first project to organize your recordings")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.textMuted)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Theme.largeSpacing)
                                .background(Color.bg)
                                .cornerRadius(Theme.cornerRadius)
                            } else {
                                VStack(spacing: Theme.spacing) {
                                    ForEach(userSession.projects) { project in
                                        Button(action: {
                                            selectedProject = project
                                        }) {
                                            HStack {
                                                Image(systemName: "folder.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(selectedProject?.id == project.id ? Color.primary : Color.textMuted)
                                                
                                                Text(project.name)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(Color.textPrimary)
                                                
                                                Spacer()
                                                
                                                if selectedProject?.id == project.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundStyle(Color.primary)
                                                }
                                            }
                                            .padding(Theme.spacing)
                                            .background(selectedProject?.id == project.id ? Color.primary.opacity(0.1) : Color.bg)
                                            .cornerRadius(Theme.cornerRadius)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                                    .stroke(selectedProject?.id == project.id ? Color.primary : Color.border, lineWidth: selectedProject?.id == project.id ? 2 : 1)
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(Theme.largeSpacing)
                        .background(Color.bgLight)
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal, Theme.largeSpacing)
                    }
                    .padding(.bottom, 100) // Space for button
                }
            }
            
            // Action Buttons
            VStack {
                Spacer()

                VStack(spacing: Theme.spacing) {
                    Button(action: {
                        guard !userSession.projects.isEmpty else {
                            showNewProjectAlert = true
                            return
                        }
                        if selectedProject == nil {
                            selectedProject = userSession.projects.first
                        }
                        navigateToRecording = true
                    }) {
                        HStack {
                            Image(systemName: "video.fill")
                                .font(.system(size: 20))
                            Text("Start Video")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.buttonHeight)
                        .foregroundStyle(userSession.projects.isEmpty ? Color.bg.opacity(0.5) : Color.bg)
                        .background(userSession.projects.isEmpty ? Color.primary.opacity(0.5) : Color.primary)
                        .cornerRadius(Theme.cornerRadius)
                    }
                    .disabled(userSession.projects.isEmpty)

                    Button(action: {
                        guard !userSession.projects.isEmpty else {
                            showNewProjectAlert = true
                            return
                        }
                        if selectedProject == nil {
                            selectedProject = userSession.projects.first
                        }
                        showVideoPicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                            Text("Choose from Library")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.buttonHeight)
                        .foregroundStyle(userSession.projects.isEmpty ? Color.textMuted.opacity(0.5) : Color.primary)
                        .background(userSession.projects.isEmpty ? Color.bgLight.opacity(0.5) : Color.bgLight)
                        .cornerRadius(Theme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .stroke(userSession.projects.isEmpty ? Color.border.opacity(0.5) : Color.primary, lineWidth: 1)
                        )
                    }
                    .disabled(userSession.projects.isEmpty)
                }
                .padding(.horizontal, Theme.largeSpacing)
                .padding(.bottom, Theme.largeSpacing)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showNewProjectAlert) {
            NewProjectSheet(
                projectName: $newProjectName,
                dueDate: $newProjectDueDate,
                hasDueDate: $hasDueDate,
                onSave: {
                    let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { return }
                    
                    let project = Project(
                        name: trimmedName,
                        dueDate: hasDueDate ? newProjectDueDate : nil
                    )
                    userSession.addProject(project)
                    selectedProject = project
                    newProjectName = ""
                    hasDueDate = false
                    newProjectDueDate = Date()
                },
                onCancel: {
                    newProjectName = ""
                    hasDueDate = false
                    newProjectDueDate = Date()
                }
            )
        }
        .navigationDestination(isPresented: $navigateToRecording) {
            RecordingView(recordingType: selectedType, project: selectedProject)
        }
        .navigationDestination(isPresented: $navigateToAnalyzing) {
            AnalyzingView(videoURL: selectedVideoURL, recordingType: selectedType, project: selectedProject)
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker { url in
                selectedVideoURL = url
                navigateToAnalyzing = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecordingSetupView()
            .environmentObject(UserSession())
    }
}

