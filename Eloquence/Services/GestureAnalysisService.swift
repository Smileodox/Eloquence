//
//  GestureAnalysisService.swift
//  Eloquence
//
//  Orchestrates gesture analysis using Vision Framework and specialized services
//

import Foundation
import AVFoundation
import Vision
import CoreImage
import Accelerate
import UIKit

class GestureAnalysisService {

    // MARK: - Properties

    /// Reusable CIContext for key frame image generation (performance optimization)
    private lazy var ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
            .cacheIntermediates: false  // Key frames are one-time use
        ]
        return CIContext(options: options)
    }()

    // Service dependencies
    private let frameExtractor = FrameExtractionService()
    private let visionAnalyzer = VisionAnalysisService()
    private let scorer = GestureScoringService()
    private let keyFrameSelector = KeyFrameSelector()

    // MARK: - Main Analysis Entry Point

    /// Analyzes video for facial expressions and body posture
    /// - Parameter videoURL: URL of the video file
    /// - Returns: Gesture metrics with scores and detailed breakdowns
    func analyzeVideo(from videoURL: URL) async throws -> GestureMetrics {
        print("📹 [GestureAnalysis] Starting streaming analysis for: \(videoURL.lastPathComponent)")

        var facialFrames: [FacialFrame] = []
        var postureFrames: [PostureFrame] = []
        var videoFrames: [CVPixelBuffer] = []
        var totalProcessedFrames = 0

        // Step 1: Stream frames and analyze on-the-fly (Combined Pass)
        try await frameExtractor.processFrames(from: videoURL) { pixelBuffer, timestamp in
            totalProcessedFrames += 1
            
            // Store frame for key frame selection
            // Note: In a production app with very long videos, we would only store candidates here.
            // For now, streaming the extraction prevents the initial memory spike which is the main crasher.
            videoFrames.append(pixelBuffer)
            
            // Analyze Face
            autoreleasepool {
                do {
                    if let facialFrame = try self.visionAnalyzer.analyzeFacialFrame(pixelBuffer) {
                        facialFrames.append(facialFrame)
                    }
                } catch {
                    // print("⚠️ Facial analysis failed: \(error)")
                }
            }
            
            // Analyze Posture
            autoreleasepool {
                do {
                    if let postureFrame = try self.visionAnalyzer.analyzePostureFrame(pixelBuffer) {
                        postureFrames.append(postureFrame)
                    }
                } catch {
                    // print("⚠️ Posture analysis failed: \(error)")
                }
            }
        }

        print("📹 [GestureAnalysis] Processed \(totalProcessedFrames) frames")
        print("📊 [GestureAnalysis] Detected faces: \(facialFrames.count), bodies: \(postureFrames.count)")

        guard totalProcessedFrames > 0 else {
            throw GestureAnalysisError.frameExtractionError
        }
        
        // Check if we have ANY data
        guard !facialFrames.isEmpty || !postureFrames.isEmpty else {
            print("❌ [GestureAnalysis] No gesture data detected - neither face nor body visible")
            throw GestureAnalysisError.insufficientData
        }

        // Step 2: Calculate Metrics
        let facialMetrics = calculateFacialMetrics(frames: facialFrames, totalFrames: totalProcessedFrames)
        let postureMetrics = calculatePostureMetrics(frames: postureFrames, totalFrames: totalProcessedFrames)

        // Warn if low detection rate
        if facialMetrics.detectionRate < 0.3 {
            print("⚠️ [GestureAnalysis] Low face detection rate (\(String(format: "%.1f%%", facialMetrics.detectionRate * 100)))")
        }
        
        // Step 3: Calculate eye contact metrics (only if face was detected)
        let eyeContactMetrics = !facialFrames.isEmpty ? calculateEyeContactMetrics(from: facialFrames) : nil

        // Step 4: Calculate scores using GestureScoringService
        let facialScore = !facialFrames.isEmpty ? scorer.calculateFacialScore(facialMetrics) : nil
        let postureScore = !postureFrames.isEmpty ? scorer.calculatePostureScore(postureMetrics) : nil
        let eyeContactScore = eyeContactMetrics.map { scorer.calculateEyeContactScore($0) }
        
        let overallScore = scorer.calculateOverallScore(
            facialScore: facialScore,
            postureScore: postureScore,
            eyeContactScore: eyeContactScore
        )

        // Step 5: Select key frames for visual feedback
        let keyFrames = keyFrameSelector.selectKeyFrames(
            from: facialFrames,
            postureFrames: postureFrames,
            videoFrames: videoFrames,
            facialScore: facialScore,
            postureScore: postureScore,
            eyeContactScore: eyeContactScore
        )

        // Log what was detected
        var logComponents: [String] = []
        if let facial = facialScore { logComponents.append("Facial: \(facial)") }
        if let posture = postureScore { logComponents.append("Posture: \(posture)") }
        if let eyeContact = eyeContactScore { logComponents.append("Eye Contact: \(eyeContact)") }
        logComponents.append("Overall: \(overallScore)")
        print("📹 [GestureAnalysis] Complete - \(logComponents.joined(separator: ", "))")

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

    // MARK: - Facial Expression Analysis

    /// Calculates eye contact metrics from facial frames
    /// - Parameter facialFrames: Array of facial frames with eye contact data
    /// - Returns: Eye contact metrics or nil if insufficient data
    private func calculateEyeContactMetrics(from facialFrames: [FacialFrame]) -> EyeContactMetrics? {
        guard !facialFrames.isEmpty else { return nil }

        print("👁️ [GestureAnalysis] Analyzing eye contact from \(facialFrames.count) facial frames...")

        // Calculate percentage of frames where looking at camera
        let framesLookingAtCamera = facialFrames.filter { $0.lookingAtCamera }.count
        let cameraFocusPercentage = Double(framesLookingAtCamera) / Double(facialFrames.count)
        
        // Calculate percentage of frames looking down (reading notes)
        let framesReadingNotes = facialFrames.filter { $0.gazeDirection == .down }.count
        let readingNotesPercentage = Double(framesReadingNotes) / Double(facialFrames.count)

        // Calculate gaze stability (how consistent is the gaze direction)
        var gazeChanges = 0
        for i in 1..<facialFrames.count {
            if facialFrames[i].gazeDirection != facialFrames[i-1].gazeDirection {
                gazeChanges += 1
            }
        }

        // Normalize: fewer changes = more stable gaze
        let maxExpectedChanges = facialFrames.count / 3
        let gazeStability = max(0, 1.0 - (Double(gazeChanges) / Double(maxExpectedChanges)))

        print("👁️ [GestureAnalysis] Camera focus: \(String(format: "%.1f%%", cameraFocusPercentage * 100)), Reading Notes: \(String(format: "%.1f%%", readingNotesPercentage * 100)), Stability: \(String(format: "%.2f", gazeStability))")

        return EyeContactMetrics(
            cameraFocusPercentage: cameraFocusPercentage,
            readingNotesPercentage: readingNotesPercentage,
            gazeStability: gazeStability,
            framesAnalyzed: facialFrames.count,
            totalFrames: facialFrames.count
        )
    }

    // MARK: - Helper Methods

    // MARK: - Metric Calculation Helpers

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

    /// Creates empty facial metrics for when face isn't detected
    private func createEmptyFacialMetrics(totalFrames: Int) -> FacialMetrics {
        return FacialMetrics(
            smileFrequency: 0,
            expressionVariety: 0,
            averageEngagement: 0,
            framesAnalyzed: 0,
            totalFrames: totalFrames
        )
    }

    /// Creates empty posture metrics for when body isn't detected
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
