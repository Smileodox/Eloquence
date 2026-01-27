//
//  GestureScoringService.swift
//  Eloquence
//

import Foundation

struct ScoringWeights {
    struct Facial {
        let smile: Double = 0.30
        let variety: Double = 0.35
        let engagement: Double = 0.35
    }

    struct Posture {
        let confidence: Double = 0.50
        let consistency: Double = 0.25
        let stability: Double = 0.25
    }

    struct EyeContact {
        let focus: Double = 0.70
        let stability: Double = 0.30
    }

    struct Overall {
        let facial: Double = 0.40
        let posture: Double = 0.35
        let eyeContact: Double = 0.25
    }

    let facial = Facial()
    let posture = Posture()
    let eyeContact = EyeContact()
    let overall = Overall()
}

class GestureScoringService {

    private let weights = ScoringWeights()

    // MARK: - Scoring

    func calculateFacialScore(_ metrics: FacialMetrics) -> Int {
        let w = weights.facial
        let score = (
            metrics.smileFrequency * w.smile +
            metrics.expressionVariety * w.variety +
            metrics.averageEngagement * w.engagement
        ) * 100.0

        return Int(score.rounded())
    }

    func calculatePostureScore(_ metrics: PostureMetrics) -> Int {
        let w = weights.posture
        let score = (
            metrics.averageConfidence * w.confidence +
            metrics.movementConsistency * w.consistency +
            metrics.stabilityScore * w.stability
        ) * 100.0

        return Int(score.rounded())
    }

    func calculateEyeContactScore(_ metrics: EyeContactMetrics) -> Int {
        let w = weights.eyeContact
        let score = (
            metrics.cameraFocusPercentage * w.focus +
            metrics.gazeStability * w.stability
        ) * 100.0

        return Int(score.rounded())
    }

    /// Handles missing metrics gracefully by adjusting weights
    func calculateOverallScore(
        facialScore: Int?,
        postureScore: Int?,
        eyeContactScore: Int?
    ) -> Int {
        let w = weights.overall

        if let facial = facialScore, let posture = postureScore, let eyeContact = eyeContactScore {
            let score = Double(facial) * w.facial + Double(posture) * w.posture + Double(eyeContact) * w.eyeContact
            return Int(score.rounded())
        }

        if let facial = facialScore, let eyeContact = eyeContactScore {
            let score = Double(facial) * 0.65 + Double(eyeContact) * 0.35
            return Int(score.rounded())
        }

        if let facial = facialScore, let posture = postureScore {
            let score = Double(facial) * 0.55 + Double(posture) * 0.45
            return Int(score.rounded())
        }

        if let facial = facialScore {
            return facial
        }

        if let posture = postureScore {
            return posture
        }

        return 50
    }

    // MARK: - Helpers

    func calculateMovementConsistency(variance: Double) -> Double {
        let idealVariance = 0.01
        let difference = abs(variance - idealVariance)
        return max(0, 1.0 - (difference * 50.0))
    }

    func calculateStability(variance: Double) -> Double {
        if variance < 0.001 {
            return 0.6
        } else if variance > 0.03 {
            return max(0, 1.0 - (variance - 0.03) * 20.0)
        } else {
            return 1.0
        }
    }

    func calculateVariance(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
}
