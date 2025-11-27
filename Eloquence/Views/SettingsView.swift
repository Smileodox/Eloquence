//
//  SettingsView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var showResetProgressAlert = false
    @State private var showDeleteRecordingsAlert = false
    @State private var showLogoutAlert = false
    
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

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(UserSession())
    }
}
