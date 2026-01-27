//
//  AudioVisualizerView.swift
//  Eloquence
//
//  Real-time audio waveform visualizer
//

import SwiftUI

struct AudioVisualizerView: View {
    let levels: [CGFloat]

    private let barSpacing: CGFloat = 3
    private let minBarHeight: CGFloat = 6
    private let maxBarHeight: CGFloat = 40
    private let barCornerRadius: CGFloat = 2

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(levels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: barCornerRadius)
                    .fill(Color.primary.opacity(0.8))
                    .frame(
                        width: calculateBarWidth(),
                        height: calculateBarHeight(for: levels[index])
                    )
                    .animation(.easeInOut(duration: 0.05), value: levels[index])
            }
        }
        .frame(height: maxBarHeight)
    }

    private func calculateBarWidth() -> CGFloat {
        // Use fixed calculation based on expected width
        let expectedWidth: CGFloat = 60 // Match RecordingView frame width
        let totalSpacing = barSpacing * CGFloat(levels.count - 1)
        let availableWidth = expectedWidth - totalSpacing
        return max(2, availableWidth / CGFloat(levels.count)) // Min 2pt bars
    }

    private func calculateBarHeight(for level: CGFloat) -> CGFloat {
        // Map level (0.0 to 1.0) to height range (min to max)
        let range = maxBarHeight - minBarHeight
        return minBarHeight + (range * level)
    }
}

#Preview {
    VStack {
        // Simulate different audio levels
        AudioVisualizerView(levels: [0.3, 0.5, 0.8, 0.6, 0.4, 0.7, 0.9, 0.5, 0.3, 0.6, 0.8, 0.4, 0.5, 0.7, 0.6, 0.3, 0.5, 0.8, 0.6, 0.4])
            .padding()
            .background(Color.black.opacity(0.5))
    }
}
