//
//  GestureAnalysisService.swift
//  Eloquence
//

import Foundation
import AVFoundation
import Vision
import CoreImage
import Accelerate
import UIKit

struct AnalysisSettings {
    var enableEyeContact: Bool = true
    var enableFacial: Bool = true
    var enablePosture: Bool = true
}

class GestureAnalysisService {

    // MARK: - Properties

    private lazy var ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
            .cacheIntermediates: false
        ]
        return CIContext(options: options)
    }()

    private let frameExtractor = FrameExtractionService()
    private let visionAnalyzer = VisionAnalysisService()
    private let scorer = GestureScoringService()
    private let keyFrameSelector = KeyFrameSelector()

    // MARK: - Analysis

    func analyzeVideo(from videoURL: URL, settings: AnalysisSettings = AnalysisSettings()) async throws -> GestureMetrics {
        print("[Gesture] Starting analysis for: \(videoURL.lastPathComponent)")

        var facialFrames: [FacialFrame] = []
        var postureFrames: [PostureFrame] = []
        var videoFrames: [CVPixelBuffer] = []
        var totalProcessedFrames = 0

        // Stream frames and analyze on-the-fly
        try await frameExtractor.processFrames(from: videoURL) { pixelBuffer, timestamp in
            totalProcessedFrames += 1
            videoFrames.append(pixelBuffer)

            if settings.enableFacial {
                autoreleasepool {
                    if let facialFrame = try? self.visionAnalyzer.analyzeFacialFrame(pixelBuffer) {
                        facialFrames.append(facialFrame)
                    }
                }
            }

            if settings.enablePosture {
                autoreleasepool {
                    if let postureFrame = try? self.visionAnalyzer.analyzePostureFrame(pixelBuffer) {
                        postureFrames.append(postureFrame)
                    }
                }
            }
        }

        print("[Gesture] Processed \(totalProcessedFrames) frames - faces: \(facialFrames.count), bodies: \(postureFrames.count)")

        guard totalProcessedFrames > 0 else {
            throw GestureAnalysisError.frameExtractionError
        }

        if facialFrames.isEmpty && postureFrames.isEmpty {
            print("[Gesture] No gesture data detected - returning empty metrics")
            return GestureMetrics(
                facialMetrics: createEmptyFacialMetrics(totalFrames: totalProcessedFrames),
                postureMetrics: createEmptyPostureMetrics(totalFrames: totalProcessedFrames),
                eyeContactMetrics: nil,
                overallScore: 0,
                facialScore: 0,
                postureScore: 0,
                eyeContactScore: nil,
                keyFrames: [],
                insufficientData: true
            )
        }

        let facialMetrics = calculateFacialMetrics(frames: facialFrames, totalFrames: totalProcessedFrames)
        let postureMetrics = calculatePostureMetrics(frames: postureFrames, totalFrames: totalProcessedFrames)

        if facialMetrics.detectionRate < 0.3 {
            print("[Gesture] Low face detection rate: \(String(format: "%.1f%%", facialMetrics.detectionRate * 100))")
        }

        let eyeContactMetrics = (settings.enableEyeContact && !facialFrames.isEmpty)
            ? calculateEyeContactMetrics(from: facialFrames)
            : nil

        let facialScore = !facialFrames.isEmpty ? scorer.calculateFacialScore(facialMetrics) : nil
        let postureScore = !postureFrames.isEmpty ? scorer.calculatePostureScore(postureMetrics) : nil
        let eyeContactScore = eyeContactMetrics.map { scorer.calculateEyeContactScore($0) }

        let overallScore = scorer.calculateOverallScore(
            facialScore: facialScore,
            postureScore: postureScore,
            eyeContactScore: eyeContactScore
        )

        let keyFrames = keyFrameSelector.selectKeyFrames(
            from: facialFrames,
            postureFrames: postureFrames,
            videoFrames: videoFrames,
            facialScore: facialScore,
            postureScore: postureScore,
            eyeContactScore: eyeContactScore
        )

        var logParts: [String] = []
        if let f = facialScore { logParts.append("Facial: \(f)") }
        if let p = postureScore { logParts.append("Posture: \(p)") }
        if let e = eyeContactScore { logParts.append("Eye: \(e)") }
        logParts.append("Overall: \(overallScore)")
        print("[Gesture] Analysis complete - \(logParts.joined(separator: ", "))")

        return GestureMetrics(
            facialMetrics: facialMetrics,
            postureMetrics: postureMetrics,
            eyeContactMetrics: eyeContactMetrics,
            overallScore: overallScore,
            facialScore: facialScore ?? 0,
            postureScore: postureScore ?? 0,
            eyeContactScore: eyeContactScore,
            keyFrames: keyFrames
        )
    }

    // MARK: - Eye Contact

    private func calculateEyeContactMetrics(from facialFrames: [FacialFrame]) -> EyeContactMetrics? {
        guard !facialFrames.isEmpty else { return nil }

        let framesLookingAtCamera = facialFrames.filter { $0.lookingAtCamera }.count
        let cameraFocusPercentage = Double(framesLookingAtCamera) / Double(facialFrames.count)

        let framesReadingNotes = facialFrames.filter { $0.gazeDirection == .down }.count
        let readingNotesPercentage = Double(framesReadingNotes) / Double(facialFrames.count)

        var gazeChanges = 0
        for i in 1..<facialFrames.count {
            if facialFrames[i].gazeDirection != facialFrames[i-1].gazeDirection {
                gazeChanges += 1
            }
        }

        let maxExpectedChanges = facialFrames.count / 3
        let gazeStability = max(0, 1.0 - (Double(gazeChanges) / Double(maxExpectedChanges)))

        return EyeContactMetrics(
            cameraFocusPercentage: cameraFocusPercentage,
            readingNotesPercentage: readingNotesPercentage,
            gazeStability: gazeStability,
            framesAnalyzed: facialFrames.count,
            totalFrames: facialFrames.count
        )
    }

    // MARK: - Metric Helpers

    private func calculateFacialMetrics(frames: [FacialFrame], totalFrames: Int) -> FacialMetrics {
        guard !frames.isEmpty else {
            return createEmptyFacialMetrics(totalFrames: totalFrames)
        }
        
        let smileFrequency = Double(frames.filter { $0.smiling }.count) / Double(frames.count)

        let expressivenesses = frames.map { $0.expressiveness }
        let expressionVariety = scorer.calculateVariance(of: expressivenesses)

        let averageEngagement = frames.map { $0.engagement }.reduce(0, +) / Double(frames.count)

        return FacialMetrics(
            smileFrequency: smileFrequency,
            expressionVariety: min(1.0, expressionVariety),
            averageEngagement: averageEngagement,
            framesAnalyzed: frames.count,
            totalFrames: totalFrames
        )
    }
    
    private func calculatePostureMetrics(frames: [PostureFrame], totalFrames: Int) -> PostureMetrics {
        guard !frames.isEmpty else {
            return createEmptyPostureMetrics(totalFrames: totalFrames)
        }
        
        let confidences = frames.map { $0.confidence }
        let averageConfidence = confidences.reduce(0, +) / Double(confidences.count)

        let centersX = frames.map { $0.centerX }
        let centersY = frames.map { $0.centerY }
        let movementVariance = (scorer.calculateVariance(of: centersX) + scorer.calculateVariance(of: centersY)) / 2.0

        let movementConsistency = scorer.calculateMovementConsistency(variance: movementVariance)
        let stabilityScore = scorer.calculateStability(variance: movementVariance)

        return PostureMetrics(
            averageConfidence: averageConfidence,
            movementConsistency: movementConsistency,
            stabilityScore: stabilityScore,
            framesAnalyzed: frames.count,
            totalFrames: totalFrames
        )
    }

    private func createEmptyFacialMetrics(totalFrames: Int) -> FacialMetrics {
        return FacialMetrics(
            smileFrequency: 0,
            expressionVariety: 0,
            averageEngagement: 0,
            framesAnalyzed: 0,
            totalFrames: totalFrames
        )
    }

    private func createEmptyPostureMetrics(totalFrames: Int) -> PostureMetrics {
        return PostureMetrics(
            averageConfidence: 0,
            movementConsistency: 0,
            stabilityScore: 0,
            framesAnalyzed: 0,
            totalFrames: totalFrames
        )
    }
}
