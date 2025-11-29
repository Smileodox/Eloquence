//
//  GestureScoringService.swift
//  Eloquence
//
//  Service for calculating gesture and body language scores
//

import Foundation

/// Scoring weights configuration
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

/// Service responsible for calculating scores from gesture metrics
class GestureScoringService {

    // MARK: - Properties

    private let weights = ScoringWeights()

    // MARK: - Public Scoring Methods

    /// Calculates facial expression score from metrics
    /// - Parameter metrics: Facial expression metrics
    /// - Returns: Score from 0-100
    func calculateFacialScore(_ metrics: FacialMetrics) -> Int {
        let w = weights.facial
        let score = (
            metrics.smileFrequency * w.smile +
            metrics.expressionVariety * w.variety +
            metrics.averageEngagement * w.engagement
        ) * 100.0

        return Int(score.rounded())
    }

    /// Calculates posture score from metrics
    /// - Parameter metrics: Posture metrics
    /// - Returns: Score from 0-100
    func calculatePostureScore(_ metrics: PostureMetrics) -> Int {
        let w = weights.posture
        let score = (
            metrics.averageConfidence * w.confidence +
            metrics.movementConsistency * w.consistency +
            metrics.stabilityScore * w.stability
        ) * 100.0

        return Int(score.rounded())
    }

    /// Calculates eye contact score from metrics
    /// - Parameter metrics: Eye contact metrics
    /// - Returns: Score from 0-100
    func calculateEyeContactScore(_ metrics: EyeContactMetrics) -> Int {
        let w = weights.eyeContact
        let score = (
            metrics.cameraFocusPercentage * w.focus +
            metrics.gazeStability * w.stability
        ) * 100.0

        return Int(score.rounded())
    }

    /// Calculates overall gesture score with graceful fallbacks for missing data
    /// - Parameters:
    ///   - facialScore: Optional facial expression score
    ///   - postureScore: Optional posture score
    ///   - eyeContactScore: Optional eye contact score
    /// - Returns: Overall score from 0-100
    func calculateOverallScore(
        facialScore: Int?,
        postureScore: Int?,
        eyeContactScore: Int?
    ) -> Int {
        let w = weights.overall

        // All three metrics available (face + posture + eye contact)
        if let facial = facialScore, let posture = postureScore, let eyeContact = eyeContactScore {
            let score = Double(facial) * w.facial + Double(posture) * w.posture + Double(eyeContact) * w.eyeContact
            print("📊 [Scoring] Overall score (all metrics): \(Int(score.rounded()))/100")
            return Int(score.rounded())
        }

        // Facial + eye contact (no posture)
        if let facial = facialScore, let eyeContact = eyeContactScore {
            print("ℹ️ [Scoring] Using facial + eye contact scoring (body not detected)")
            let score = Double(facial) * 0.65 + Double(eyeContact) * 0.35
            return Int(score.rounded())
        }

        // Facial + posture (no eye contact)
        if let facial = facialScore, let posture = postureScore {
            print("ℹ️ [Scoring] Using facial + posture scoring (eye contact not measured)")
            let score = Double(facial) * 0.55 + Double(posture) * 0.45
            return Int(score.rounded())
        }

        // Only facial available
        if let facial = facialScore {
            print("ℹ️ [Scoring] Using facial-only scoring (body not detected, eye contact not measured)")
            return facial
        }

        // Only posture available (eye contact not possible without face)
        if let posture = postureScore {
            print("ℹ️ [Scoring] Using posture-only scoring (face not detected)")
            return posture
        }

        // Fallback (should never reach here)
        print("⚠️ [Scoring] No metrics available, using default score")
        return 50
    }

    // MARK: - Helper Methods for Metrics Calculation

    /// Calculates movement consistency from variance
    /// - Parameter variance: Movement variance value
    /// - Returns: Consistency score from 0.0-1.0
    func calculateMovementConsistency(variance: Double) -> Double {
        // Ideal variance is around 0.005-0.015 (moderate movement)
        let idealVariance = 0.01
        let difference = abs(variance - idealVariance)
        return max(0, 1.0 - (difference * 50.0))
    }

    /// Calculates stability from movement variance
    /// - Parameter variance: Movement variance value
    /// - Returns: Stability score from 0.0-1.0
    func calculateStability(variance: Double) -> Double {
        // Penalize excessive movement (>0.03) and rigidity (<0.001)
        if variance < 0.001 {
            return 0.6 // Too rigid
        } else if variance > 0.03 {
            return max(0, 1.0 - (variance - 0.03) * 20.0)
        } else {
            return 1.0
        }
    }

    /// Calculates variance of a set of values
    /// - Parameter values: Array of double values
    /// - Returns: Variance value
    func calculateVariance(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count)

        return variance
    }
}
