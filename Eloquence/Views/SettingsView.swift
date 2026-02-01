//
//  SettingsView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI
import FoundationModels

struct SettingsView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var showResetProgressAlert = false
    @State private var showDeleteRecordingsAlert = false
    @State private var showLogoutAlert = false
    @State private var showModelUnavailableAlert = false
    @State private var modelUnavailableMessage = ""
    
    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.largeSpacing) {
                    // Settings header
                    VStack(spacing: Theme.spacing) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.primary)
                    }
                    .padding(.top, Theme.spacing)

                    // AI Settings Section
                    VStack(alignment: .leading, spacing: Theme.spacing) {
                        Text("AI Settings")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.bottom, 4)

                        // AI Voice Style Picker
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundStyle(Color.primary)
                                .frame(width: 28)
                            Text("AI Voice Style")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Picker("", selection: $userSession.aiVoiceStyle) {
                                ForEach(AIVoiceStyle.allCases, id: \.self) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.primary)
                        }
                        .padding()
                        .background(Color.bgLight)
                        .cornerRadius(Theme.cornerRadius)

                        // Offline Mode Toggle
                        VStack(spacing: 0) {
                            SettingsToggleRow(
                                icon: "network.slash",
                                title: "Offline Mode",
                                isOn: $userSession.enableOfflineMode
                            )
                        }
                        .background(Color.bgLight)
                        .cornerRadius(Theme.cornerRadius)
                        .onChange(of: userSession.enableOfflineMode) { _, enabled in
                            if enabled {
                                if let message = checkModelAvailability() {
                                    modelUnavailableMessage = message
                                    userSession.enableOfflineMode = false
                                    showModelUnavailableAlert = true
                                }
                            }
                        }

                        if userSession.enableOfflineMode {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.orange)
                                    Text("Offline Mode Limitations")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                }
                                Text("All analysis stays on-device using Apple Intelligence. No data leaves your iPhone. However, analysis quality will be lower compared to cloud-based processing, and key frame annotations are not available in offline mode.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textMuted)
                            }
                            .padding(12)
                            .background(Color.bgLight)
                            .cornerRadius(Theme.cornerRadius)
                        }

                        // Analysis Toggles
                        VStack(spacing: 0) {
                            SettingsToggleRow(
                                icon: "eye",
                                title: "Eye Contact Tracking",
                                isOn: $userSession.enableEyeContactAnalysis
                            )
                            Divider().padding(.leading, 44)
                            SettingsToggleRow(
                                icon: "face.smiling",
                                title: "Facial Expression Analysis",
                                isOn: $userSession.enableFacialAnalysis
                            )
                            Divider().padding(.leading, 44)
                            SettingsToggleRow(
                                icon: "figure.stand",
                                title: "Posture Analysis",
                                isOn: $userSession.enablePostureAnalysis
                            )
                        }
                        .background(Color.bgLight)
                        .cornerRadius(Theme.cornerRadius)

                        // Data Processing Info
                        NavigationLink(destination: DataProcessingView()) {
                            HStack {
                                Image(systemName: "globe.europe.africa")
                                    .foregroundStyle(Color.primary)
                                    .frame(width: 28)
                                Text("Data Processing")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textMuted)
                            }
                            .padding()
                            .background(Color.bgLight)
                            .cornerRadius(Theme.cornerRadius)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.largeSpacing)

                    // Reset Progress button
                    Button(action: {
                        showResetProgressAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                            
                            Text("Reset Progress")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.buttonHeight)
                        .foregroundStyle(Color.warning)
                        .background(Color.bgLight)
                        .cornerRadius(Theme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .stroke(Color.warning, lineWidth: 2)
                        )
                    }
                    .padding(.horizontal, Theme.largeSpacing)
                    
                    // Delete All Recordings button
                    Button(action: {
                        showDeleteRecordingsAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 20))
                            
                            Text("Delete All Recordings")
                                .font(.system(size: 18, weight: .semibold))
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
                    .padding(.horizontal, Theme.largeSpacing)
                    
                    // Logout button
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .font(.system(size: 20))
                            
                            Text("Logout")
                                .font(.system(size: 18, weight: .semibold))
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
                    .padding(.horizontal, Theme.largeSpacing)
                    .padding(.bottom, Theme.largeSpacing)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Reset Progress", isPresented: $showResetProgressAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                userSession.resetProgress()
            }
        } message: {
            Text("Are you sure you want to reset all progress? This will delete all session data and cannot be undone.")
        }
        .alert("Delete All Recordings", isPresented: $showDeleteRecordingsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllRecordings()
            }
        } message: {
            Text("Are you sure you want to delete all recordings? This action cannot be undone.")
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                userSession.logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Apple Intelligence Unavailable", isPresented: $showModelUnavailableAlert) {
            Button("Disable Offline Mode", role: .cancel) { }
        } message: {
            Text(modelUnavailableMessage)
        }
    }
    
    private func checkModelAvailability() -> String? {
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return "This device does not support Apple Intelligence. Offline mode requires an iPhone with A17 Pro chip or later."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence is not enabled. Go to Settings > Apple Intelligence & Siri and turn on Apple Intelligence to use offline mode."
            case .unavailable(.modelNotReady):
                return "The on-device AI model is still downloading. Please wait for the download to complete in Settings > Apple Intelligence & Siri, then try again."
            default:
                return "Apple Intelligence is not available. Please check Settings > Apple Intelligence & Siri."
            }
        } else {
            return "Offline mode requires iOS 26 or later."
        }
    }

    private func deleteAllRecordings() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil, options: [])
            let videoFiles = files.filter { $0.pathExtension == "mov" || $0.pathExtension == "mp4" }
            
            for videoFile in videoFiles {
                try FileManager.default.removeItem(at: videoFile)
            }
        } catch {
            print("Error deleting all recordings: \(error)")
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.primary)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(.primary)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(UserSession())
    }
}
