//
//  KeyFrameCard.swift
//  Eloquence
//
//  UI component for displaying key frame highlights with annotations
//

import SwiftUI

struct KeyFrameCard: View {
    let keyFrame: KeyFrame
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            if let uiImage = UIImage(data: keyFrame.image) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(keyFrame.isPositive ? Color.success.opacity(0.3) : Color.warning.opacity(0.3), lineWidth: 2)
                    )
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Header with timestamp and score
                HStack {
                    Text(formatTimestamp(keyFrame.timestamp))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textMuted)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(keyFrame.score)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(scoreColor(keyFrame.score))

                        Image(systemName: keyFrame.isPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(keyFrame.isPositive ? Color.success : Color.warning)
                    }
                }

                // Annotation
                Text(keyFrame.annotation)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(isExpanded ? nil : 3)

                // Footer row: Metric + Expansion Indicator
                HStack {
                    Text(keyFrame.primaryMetric)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color.bg)
        .cornerRadius(8)
        .contentShape(Rectangle()) // Ensure tap works on empty space
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
    }

    private func formatTimestamp(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 {
            return .success
        } else if score >= 50 {
            return .warning
        } else {
            return .danger
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        // Preview with positive frame
        KeyFrameCard(
            keyFrame: KeyFrame(
                image: Data(), // Empty data for preview
                timestamp: 15.5,
                type: .bestFacial,
                primaryMetric: "Facial Expression",
                score: 85,
                annotation: "💪 Strong! Smile + eye contact = perfect connection",
                isPositive: true
            )
        )

        // Preview with improvement frame
        KeyFrameCard(
            keyFrame: KeyFrame(
                image: Data(),
                timestamp: 42.0,
                type: .improvePosture,
                primaryMetric: "Posture",
                score: 45,
                annotation: "🏋️ Shoulders back, chest out - upright posture radiates confidence",
                isPositive: false
            )
        )
    }
    .padding()
    .background(Color.bgLight)
}
