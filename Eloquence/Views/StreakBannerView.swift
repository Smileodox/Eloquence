//
//  StreakBannerView.swift
//  Eloquence
//
//  Practice streak banner with flame icon and celebration animations
//

import SwiftUI

struct StreakBannerView: View {
    let streakCount: Int
    let longestStreak: Int
    @State private var isAnimating = false
    @State private var showMilestoneEffect = false

    private var isMilestone: Bool {
        [7, 14, 30, 60, 100, 365].contains(streakCount)
    }

    private var milestoneMessage: String? {
        switch streakCount {
        case 7: return "One week!"
        case 14: return "Two weeks!"
        case 30: return "One month!"
        case 60: return "Two months!"
        case 100: return "100 days!"
        case 365: return "One year!"
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Flame icon with animation
            ZStack {
                if showMilestoneEffect {
                    Circle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .opacity(isAnimating ? 0 : 0.8)
                }

                Image(systemName: streakCount > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        streakCount > 0
                            ? LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            : LinearGradient(
                                colors: [Color.textMuted, Color.textMuted],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                    )
                    .scaleEffect(isAnimating && isMilestone ? 1.1 : 1.0)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if streakCount > 0 {
                        Text("\(streakCount) day streak!")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)

                        if let message = milestoneMessage {
                            Text(message)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.orange)
                        }
                    } else {
                        Text("Start your streak!")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                    }
                }

                if streakCount > 0 {
                    Text("Best: \(longestStreak) days")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                } else {
                    Text("Practice today to begin")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                }
            }

            Spacer()

            if isMilestone {
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.yellow)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }
        }
        .padding(Theme.spacing)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(
                    isMilestone
                        ? LinearGradient(
                            colors: [Color.orange.opacity(0.15), Color.bgLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color.bgLight, Color.bgLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(
                    isMilestone ? Color.orange.opacity(0.3) : Color.border,
                    lineWidth: 1
                )
        )
        .onAppear {
            if isMilestone {
                showMilestoneEffect = true
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakBannerView(streakCount: 0, longestStreak: 0)
        StreakBannerView(streakCount: 3, longestStreak: 12)
        StreakBannerView(streakCount: 7, longestStreak: 12)
        StreakBannerView(streakCount: 30, longestStreak: 30)
    }
    .padding()
    .background(Color.bg)
}
