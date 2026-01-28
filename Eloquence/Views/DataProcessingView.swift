//
//  DataProcessingView.swift
//  Eloquence
//
//  Created by Claude on 27.01.26.
//

import SwiftUI
import MapKit

struct ServerLocation: Identifiable {
    let id = UUID()
    let name: String
    let region: String
    let country: String
    let coordinate: CLLocationCoordinate2D
    let description: String
    let icon: String
}

struct DataProcessingView: View {
    let servers = [
        ServerLocation(
            name: "On-Device",
            region: "Local",
            country: "Your iPhone",
            coordinate: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
            description: "Eye tracking & posture analysis",
            icon: "iphone"
        ),
        ServerLocation(
            name: "API Server",
            region: "West Europe",
            country: "Netherlands",
            coordinate: CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041),
            description: "Authentication & API routing",
            icon: "server.rack"
        ),
        ServerLocation(
            name: "AI Processing",
            region: "Sweden Central",
            country: "Sweden",
            coordinate: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
            description: "Whisper, GPT-4, Vision API",
            icon: "brain"
        )
    ]

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.0, longitude: 12.0),
        span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 20)
    )

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.largeSpacing) {
                    // Map with annotations
                    Map(coordinateRegion: $mapRegion, annotationItems: servers) { server in
                        MapAnnotation(coordinate: server.coordinate) {
                            ServerPin(server: server)
                        }
                    }
                    .frame(height: 300)
                    .cornerRadius(Theme.cornerRadius)

                    // Info cards for each server
                    ForEach(servers) { server in
                        ServerInfoCard(server: server)
                    }

                    // Privacy info
                    PrivacyInfoSection()
                }
                .padding(Theme.largeSpacing)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Data Processing")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct ServerPin: View {
    let server: ServerLocation

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 36, height: 36)
                Image(systemName: server.icon)
                    .foregroundStyle(.white)
                    .font(.system(size: 16))
            }
            Text(server.country)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.bgLight)
                .cornerRadius(4)
        }
    }
}

struct ServerInfoCard: View {
    let server: ServerLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: server.icon)
                    .foregroundStyle(Color.primary)
                Text(server.name)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(server.country)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textMuted)
            }

            Text(server.description)
                .font(.system(size: 14))
                .foregroundStyle(Color.textMuted)

            // Data types processed
            if server.name == "On-Device" {
                DataTypeRow(icon: "eye", text: "Gaze tracking (Vision Framework)")
                DataTypeRow(icon: "figure.stand", text: "Posture analysis (Vision Framework)")
            } else if server.name == "AI Processing" {
                DataTypeRow(icon: "waveform", text: "Audio → Text (Whisper)")
                DataTypeRow(icon: "text.bubble", text: "Text → Feedback (GPT-4)")
                DataTypeRow(icon: "camera", text: "Video frames → Gesture analysis (GPT-4 Vision)")
            } else {
                DataTypeRow(icon: "key", text: "Login & authentication")
                DataTypeRow(icon: "arrow.left.arrow.right", text: "API request routing")
            }
        }
        .padding()
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
    }
}

struct DataTypeRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.textMuted)
        }
    }
}

struct PrivacyInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(Color.success)
                Text("Privacy")
                    .font(.system(size: 16, weight: .semibold))
            }

            Text("Eye tracking and posture analysis run entirely on your device. Cloud servers are located in the EU and comply with GDPR. Your recordings are only processed for analysis and are not permanently stored on our servers.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textMuted)
        }
        .padding()
        .background(Color.bgLight)
        .cornerRadius(Theme.cornerRadius)
    }
}

#Preview {
    NavigationStack {
        DataProcessingView()
    }
}
