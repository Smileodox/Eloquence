//
//  GestureAnalysisService.swift
//  Eloquence
//
//  Service for analyzing gestures and body language using Apple Vision Framework
//

import Foundation
import AVFoundation
import Vision
import CoreImage
import Accelerate

class GestureAnalysisService: ObservableObject {

    // MARK: - Main Analysis Entry Point

    /// Analyzes video for facial expressions and body posture
    /// - Parameter videoURL: URL of the video file to analyze
    /// - Returns: Gesture metrics with scores and detailed breakdowns
    func analyzeVideo(from videoURL: URL) async throws -> GestureMetrics {
        print("📹 Starting gesture analysis for video: \(videoURL.lastPathComponent)")

        // Step 1: Extract frames from video (2 FPS)
        let frames = try await extractFrames(from: videoURL, sampleRate: 2.0)
        print("📹 Extracted \(frames.count) frames for analysis")

        guard !frames.isEmpty else {
            throw GestureAnalysisError.frameExtractionError
        }

        // Step 2: Analyze facial expressions and body posture in parallel
        async let facialTask = analyzeFacialExpressions(in: frames)
        async let postureTask = analyzeBodyPosture(in: frames)

        let (facialMetrics, postureMetrics) = try await (facialTask, postureTask)

        // Step 3: Calculate scores
        let facialScore = calculateFacialScore(from: facialMetrics)
        let postureScore = calculatePostureScore(from: postureMetrics)
        let overallScore = calculateOverallScore(facial: facialScore, posture: postureScore, facialMetrics: facialMetrics, postureMetrics: postureMetrics)

        print("📹 Analysis complete - Facial: \(facialScore), Posture: \(postureScore), Overall: \(overallScore)")

        return GestureMetrics(
            facialMetrics: facialMetrics,
            postureMetrics: postureMetrics,
            overallScore: overallScore,
            facialScore: facialScore,
            postureScore: postureScore
        )
    }

    // MARK: - Frame Extraction

    /// Extracts frames from video at specified sample rate
    /// - Parameters:
    ///   - videoURL: URL of the video file
    ///   - sampleRate: Frames per second to extract (e.g., 2.0 = 2 FPS)
    /// - Returns: Array of CVPixelBuffer frames
    private func extractFrames(from videoURL: URL, sampleRate: Double) async throws -> [CVPixelBuffer] {
        let asset = AVAsset(url: videoURL)

        // Verify asset is readable
        guard try await asset.load(.isReadable) else {
            throw GestureAnalysisError.videoReadError
        }

        // Get video duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        print("📹 Video duration: \(String(format: "%.1f", durationSeconds))s, Sample rate: \(sampleRate) FPS")

        // Calculate frame times
        let frameInterval = 1.0 / sampleRate
        let frameTimes = stride(from: 0, to: durationSeconds, by: frameInterval)
            .map { CMTime(seconds: $0, preferredTimescale: 600) }

        // Create image generator
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.appliesPreferredTrackTransform = true

        var frames: [CVPixelBuffer] = []

        // Extract frames
        for time in frameTimes {
            autoreleasepool {
                do {
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                    if let pixelBuffer = cgImage.toPixelBuffer() {
                        frames.append(pixelBuffer)
                    }
                } catch {
                    print("⚠️ Failed to extract frame at \(CMTimeGetSeconds(time))s: \(error)")
                }
            }
        }

        return frames
    }

    // MARK: - Facial Expression Analysis

    /// Analyzes facial expressions across all frames
    /// - Parameter frames: Array of video frames
    /// - Returns: Facial metrics aggregated across all frames
    private func analyzeFacialExpressions(in frames: [CVPixelBuffer]) async throws -> FacialMetrics {
        print("😊 Analyzing facial expressions...")

        var facialFrames: [FacialFrame] = []
        var framesWithFace = 0

        for (index, frame) in frames.enumerated() {
            autoreleasepool {
                do {
                    if let facialFrame = try analyzeSingleFacialFrame(frame) {
                        facialFrames.append(facialFrame)
                        framesWithFace += 1
                    }
                } catch {
                    print("⚠️ Facial analysis failed for frame \(index): \(error)")
                }
            }
        }

        print("😊 Detected face in \(framesWithFace)/\(frames.count) frames")

        // Require at least 30% of frames to have face detected
        guard Double(framesWithFace) / Double(frames.count) >= 0.3 else {
            throw GestureAnalysisError.noFaceDetected
        }

        // Calculate aggregated metrics
        let smileFrequency = Double(facialFrames.filter { $0.smiling }.count) / Double(facialFrames.count)

        let expressivenesses = facialFrames.map { $0.expressiveness }
        let expressionVariety = calculateVariance(of: expressivenesses)

        let averageEngagement = facialFrames.map { $0.engagement }.reduce(0, +) / Double(facialFrames.count)

        return FacialMetrics(
            smileFrequency: smileFrequency,
            expressionVariety: min(1.0, expressionVariety), // Normalize to 0-1
            averageEngagement: averageEngagement,
            framesAnalyzed: framesWithFace,
            totalFrames: frames.count
        )
    }

    /// Analyzes a single frame for facial expressions
    /// - Parameter pixelBuffer: Video frame to analyze
    /// - Returns: Facial frame data or nil if no face detected
    private func analyzeSingleFacialFrame(_ pixelBuffer: CVPixelBuffer) throws -> FacialFrame? {
        let faceRequest = VNDetectFaceLandmarksRequest()
        let qualityRequest = VNDetectFaceCaptureQualityRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([faceRequest, qualityRequest])

        guard let faceObservation = faceRequest.results?.first,
              let landmarks = faceObservation.landmarks else {
            return nil
        }

        // Detect smile from mouth landmarks
        let smiling = detectSmile(from: landmarks)

        // Calculate expressiveness from landmark variety
        let expressiveness = calculateExpressiveness(from: landmarks)

        // Get engagement from face quality and eye openness
        let quality = Double(qualityRequest.results?.first?.faceCaptureQuality ?? 0.5)
        let eyeOpenness = calculateEyeOpenness(from: landmarks)
        let engagement = (quality + eyeOpenness) / 2.0

        return FacialFrame(
            smiling: smiling,
            expressiveness: expressiveness,
            engagement: engagement
        )
    }

    /// Detects smile from mouth landmarks
    private func detectSmile(from landmarks: VNFaceLandmarks2D) -> Bool {
        guard let outerLips = landmarks.outerLips else { return false }

        let points = outerLips.normalizedPoints
        guard points.count >= 8 else { return false }

        // Calculate mouth curvature (simplified check)
        // Compare top middle with bottom middle
        let leftCorner = points[0]
        let rightCorner = points[points.count / 2]
        let topMiddle = points[points.count / 4]
        let bottomMiddle = points[3 * points.count / 4]

        let mouthWidth = distance(leftCorner, rightCorner)
        let mouthCurvature = (bottomMiddle.y - topMiddle.y) / mouthWidth

        // Smiling if bottom is higher than top (negative curvature)
        return mouthCurvature < -0.15
    }

    /// Calculates expressiveness from landmark variance
    private func calculateExpressiveness(from landmarks: VNFaceLandmarks2D) -> Double {
        var varianceSum = 0.0
        var count = 0

        // Check eyebrow positions
        if let leftEyebrow = landmarks.leftEyebrow, let rightEyebrow = landmarks.rightEyebrow {
            let leftPoints = leftEyebrow.normalizedPoints
            let rightPoints = rightEyebrow.normalizedPoints

            if !leftPoints.isEmpty && !rightPoints.isEmpty {
                let leftY = leftPoints.map { Double($0.y) }
                let rightY = rightPoints.map { Double($0.y) }
                varianceSum += calculateVariance(of: leftY) + calculateVariance(of: rightY)
                count += 2
            }
        }

        // Check mouth shape
        if let outerLips = landmarks.outerLips {
            let points = outerLips.normalizedPoints
            if !points.isEmpty {
                let yValues = points.map { Double($0.y) }
                varianceSum += calculateVariance(of: yValues)
                count += 1
            }
        }

        guard count > 0 else { return 0.5 }
        return min(1.0, (varianceSum / Double(count)) * 10.0) // Scale and normalize
    }

    /// Calculates eye openness from eye landmarks
    private func calculateEyeOpenness(from landmarks: VNFaceLandmarks2D) -> Double {
        var openness = 0.0
        var count = 0

        if let leftEye = landmarks.leftEye {
            let points = leftEye.normalizedPoints
            if points.count >= 4 {
                let topY = points[1].y
                let bottomY = points[points.count - 2].y
                let height = abs(topY - bottomY)
                openness += min(1.0, height * 20.0) // Scale to 0-1
                count += 1
            }
        }

        if let rightEye = landmarks.rightEye {
            let points = rightEye.normalizedPoints
            if points.count >= 4 {
                let topY = points[1].y
                let bottomY = points[points.count - 2].y
                let height = abs(topY - bottomY)
                openness += min(1.0, height * 20.0)
                count += 1
            }
        }

        guard count > 0 else { return 0.5 }
        return openness / Double(count)
    }

    // MARK: - Body Posture Analysis

    /// Analyzes body posture across all frames
    /// - Parameter frames: Array of video frames
    /// - Returns: Posture metrics aggregated across all frames
    private func analyzeBodyPosture(in frames: [CVPixelBuffer]) async throws -> PostureMetrics {
        print("🧍 Analyzing body posture...")

        var postureFrames: [PostureFrame] = []
        var framesWithBody = 0

        for (index, frame) in frames.enumerated() {
            autoreleasepool {
                do {
                    if let postureFrame = try analyzeSinglePostureFrame(frame) {
                        postureFrames.append(postureFrame)
                        framesWithBody += 1
                    }
                } catch {
                    print("⚠️ Posture analysis failed for frame \(index): \(error)")
                }
            }
        }

        print("🧍 Detected body in \(framesWithBody)/\(frames.count) frames")

        // Require at least 30% of frames to have body detected
        guard Double(framesWithBody) / Double(frames.count) >= 0.3 else {
            throw GestureAnalysisError.noBodyDetected
        }

        // Calculate aggregated metrics
        let confidences = postureFrames.map { $0.confidence }
        let averageConfidence = confidences.reduce(0, +) / Double(confidences.count)

        let centersX = postureFrames.map { $0.centerX }
        let centersY = postureFrames.map { $0.centerY }
        let movementVariance = (calculateVariance(of: centersX) + calculateVariance(of: centersY)) / 2.0

        // Good movement is moderate (not too still, not too much)
        let movementConsistency = calculateMovementConsistency(variance: movementVariance)

        // Stability is balance of movement
        let stabilityScore = calculateStability(variance: movementVariance)

        return PostureMetrics(
            averageConfidence: averageConfidence,
            movementConsistency: movementConsistency,
            stabilityScore: stabilityScore,
            framesAnalyzed: framesWithBody,
            totalFrames: frames.count
        )
    }

    /// Analyzes a single frame for body posture
    /// - Parameter pixelBuffer: Video frame to analyze
    /// - Returns: Posture frame data or nil if no body detected
    private func analyzeSinglePostureFrame(_ pixelBuffer: CVPixelBuffer) throws -> PostureFrame? {
        let poseRequest = VNDetectHumanBodyPoseRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([poseRequest])

        guard let observation = poseRequest.results?.first else {
            return nil
        }

        // Get key points
        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              let neck = try? observation.recognizedPoint(.neck),
              leftShoulder.confidence > 0.3,
              rightShoulder.confidence > 0.3,
              neck.confidence > 0.3 else {
            return nil
        }

        // Calculate confidence from shoulder alignment and posture
        let confidence = calculatePostureConfidence(
            leftShoulder: leftShoulder.location,
            rightShoulder: rightShoulder.location,
            neck: neck.location
        )

        // Calculate body center
        let centerX = neck.location.x
        let centerY = neck.location.y

        return PostureFrame(
            confidence: confidence,
            centerX: Double(centerX),
            centerY: Double(centerY)
        )
    }

    /// Calculates posture confidence from body landmarks
    private func calculatePostureConfidence(leftShoulder: CGPoint, rightShoulder: CGPoint, neck: CGPoint) -> Double {
        // Check shoulder alignment (should be roughly horizontal)
        let shoulderDiff = abs(leftShoulder.y - rightShoulder.y)
        let shoulderDistance = distance(leftShoulder, rightShoulder)
        let shoulderAlignment = max(0, 1.0 - (Double(shoulderDiff) / Double(shoulderDistance)) * 5.0)

        // Check vertical posture (neck should be between shoulders horizontally)
        let shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2.0
        let neckOffset = abs(neck.x - shoulderMidX) / shoulderDistance
        let verticalPosture = max(0, 1.0 - Double(neckOffset) * 2.0)

        // Combine metrics
        return (shoulderAlignment * 0.6 + verticalPosture * 0.4)
    }

    /// Calculates movement consistency from variance
    private func calculateMovementConsistency(variance: Double) -> Double {
        // Ideal variance is around 0.005-0.015 (moderate movement)
        let idealVariance = 0.01
        let difference = abs(variance - idealVariance)
        return max(0, 1.0 - (difference * 50.0))
    }

    /// Calculates stability from movement variance
    private func calculateStability(variance: Double) -> Double {
        // Penalize excessive movement (>0.03) and rigidity (<0.001)
        if variance < 0.001 {
            return 0.6 // Too rigid
        } else if variance > 0.03 {
            return max(0, 1.0 - (variance - 0.03) * 20.0)
        } else {
            return 1.0
        }
    }

    // MARK: - Scoring

    /// Calculates facial score from metrics
    private func calculateFacialScore(from metrics: FacialMetrics) -> Int {
        let score = (
            metrics.smileFrequency * 0.30 +
            metrics.expressionVariety * 0.35 +
            metrics.averageEngagement * 0.35
        ) * 100.0

        return Int(score.rounded())
    }

    /// Calculates posture score from metrics
    private func calculatePostureScore(from metrics: PostureMetrics) -> Int {
        let score = (
            metrics.averageConfidence * 0.50 +
            metrics.movementConsistency * 0.25 +
            metrics.stabilityScore * 0.25
        ) * 100.0

        return Int(score.rounded())
    }

    /// Calculates overall gesture score with fallbacks
    private func calculateOverallScore(facial: Int, posture: Int, facialMetrics: FacialMetrics, postureMetrics: PostureMetrics) -> Int {
        let faceDetectionRate = facialMetrics.detectionRate
        let bodyDetectionRate = postureMetrics.detectionRate

        // Adjust weights based on detection rates
        if faceDetectionRate < 0.5 && bodyDetectionRate >= 0.5 {
            // Use posture only
            return posture
        } else if bodyDetectionRate < 0.5 && faceDetectionRate >= 0.5 {
            // Use face only
            return facial
        } else {
            // Use weighted average (55% facial, 45% posture)
            let score = Double(facial) * 0.55 + Double(posture) * 0.45
            return Int(score.rounded())
        }
    }

    // MARK: - Helper Functions

    /// Calculates variance of an array of values
    private func calculateVariance(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count)

        return variance
    }

    /// Calculates distance between two CGPoints
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
}

// MARK: - CGImage to CVPixelBuffer Extension

extension CGImage {
    /// Converts CGImage to CVPixelBuffer
    func toPixelBuffer() -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}
