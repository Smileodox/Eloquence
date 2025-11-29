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

        let (facialResult, postureResult) = await (facialTask, postureTask)

        // Extract facial metrics and frames
        let facialMetrics = facialResult?.0
        let facialFrames = facialResult?.1 ?? []

        // Extract posture metrics and frames
        let postureMetrics = postureResult?.0
        let postureFrames = postureResult?.1 ?? []

        // Check if we have ANY data to work with
        guard facialMetrics != nil || postureMetrics != nil else {
            print("❌ No gesture data detected - neither face nor body visible")
            throw GestureAnalysisError.insufficientData
        }

        // Step 3: Calculate eye contact metrics (only if face was detected)
        let eyeContactMetrics = facialMetrics != nil ? calculateEyeContactMetrics(from: facialFrames) : nil

        // Step 4: Calculate scores (gracefully handle missing data)
        let facialScore = facialMetrics != nil ? calculateFacialScore(from: facialMetrics!) : nil
        let postureScore = postureMetrics != nil ? calculatePostureScore(from: postureMetrics!) : nil
        let eyeContactScore = eyeContactMetrics != nil ? calculateEyeContactScore(from: eyeContactMetrics!) : nil
        let overallScore = calculateOverallScore(
            facial: facialScore,
            posture: postureScore,
            eyeContact: eyeContactScore,
            facialMetrics: facialMetrics,
            postureMetrics: postureMetrics,
            eyeContactMetrics: eyeContactMetrics
        )

        // Step 5: Select key frames for visual feedback
        let keyFrames = selectKeyFrames(
            from: facialFrames,
            postureFrames: postureFrames,
            videoFrames: frames,
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
        print("📹 Analysis complete - \(logComponents.joined(separator: ", "))")

        return GestureMetrics(
            facialMetrics: facialMetrics ?? createEmptyFacialMetrics(totalFrames: frames.count),
            postureMetrics: postureMetrics ?? createEmptyPostureMetrics(totalFrames: frames.count),
            eyeContactMetrics: eyeContactMetrics,
            overallScore: overallScore,
            facialScore: facialScore ?? 0,
            postureScore: postureScore ?? 0,
            eyeContactScore: eyeContactScore,
            keyFrames: keyFrames
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
    /// - Returns: Tuple of (FacialMetrics, facialFrames array) or nil if insufficient data
    private func analyzeFacialExpressions(in frames: [CVPixelBuffer]) async -> (FacialMetrics, [FacialFrame])? {
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

        // Return nil if too few faces detected (instead of throwing error)
        guard Double(framesWithFace) / Double(frames.count) >= 0.1 else {
            print("⚠️ Insufficient facial data - face detected in <10% of frames")
            return nil
        }

        // Calculate aggregated metrics
        let smileFrequency = Double(facialFrames.filter { $0.smiling }.count) / Double(facialFrames.count)

        let expressivenesses = facialFrames.map { $0.expressiveness }
        let expressionVariety = calculateVariance(of: expressivenesses)

        let averageEngagement = facialFrames.map { $0.engagement }.reduce(0, +) / Double(facialFrames.count)

        let metrics = FacialMetrics(
            smileFrequency: smileFrequency,
            expressionVariety: min(1.0, expressionVariety), // Normalize to 0-1
            averageEngagement: averageEngagement,
            framesAnalyzed: framesWithFace,
            totalFrames: frames.count
        )

        return (metrics, facialFrames)
    }

    /// Calculates eye contact metrics from facial frames
    /// - Parameter facialFrames: Array of facial frames with eye contact data
    /// - Returns: Eye contact metrics or nil if insufficient data
    private func calculateEyeContactMetrics(from facialFrames: [FacialFrame]) -> EyeContactMetrics? {
        guard !facialFrames.isEmpty else { return nil }

        print("👁️ Analyzing eye contact from \(facialFrames.count) facial frames...")

        // Calculate percentage of frames where looking at camera
        let framesLookingAtCamera = facialFrames.filter { $0.lookingAtCamera }.count
        let cameraFocusPercentage = Double(framesLookingAtCamera) / Double(facialFrames.count)

        // Calculate gaze stability (how consistent is the gaze direction)
        // Use moving window to detect how often gaze changes
        var gazeChanges = 0
        for i in 1..<facialFrames.count {
            if facialFrames[i].lookingAtCamera != facialFrames[i-1].lookingAtCamera {
                gazeChanges += 1
            }
        }

        // Normalize: fewer changes = more stable gaze
        // Perfect stability (no changes) = 1.0, many changes = lower score
        let maxExpectedChanges = facialFrames.count / 3  // Change every 3 frames would be very unstable
        let gazeStability = max(0, 1.0 - (Double(gazeChanges) / Double(maxExpectedChanges)))

        print("👁️ Camera focus: \(String(format: "%.1f%%", cameraFocusPercentage * 100)), Stability: \(String(format: "%.2f", gazeStability))")

        return EyeContactMetrics(
            cameraFocusPercentage: cameraFocusPercentage,
            gazeStability: gazeStability,
            framesAnalyzed: facialFrames.count,
            totalFrames: facialFrames.count
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

        // Detect eye contact (looking at camera)
        let lookingAtCamera = detectEyeContact(from: landmarks, faceObservation: faceObservation)

        return FacialFrame(
            smiling: smiling,
            expressiveness: expressiveness,
            engagement: engagement,
            lookingAtCamera: lookingAtCamera
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

    /// Detects eye contact by analyzing gaze direction
    private func detectEyeContact(from landmarks: VNFaceLandmarks2D, faceObservation: VNFaceObservation) -> Bool {
        // Get pupil landmarks if available
        guard let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else {
            // Fall back to using eye regions to estimate gaze
            return estimateGazeFromEyes(landmarks: landmarks, faceObservation: faceObservation)
        }

        let leftPupilPoints = leftPupil.normalizedPoints
        let rightPupilPoints = rightPupil.normalizedPoints

        guard !leftPupilPoints.isEmpty && !rightPupilPoints.isEmpty else {
            return estimateGazeFromEyes(landmarks: landmarks, faceObservation: faceObservation)
        }

        // Get average pupil position
        let leftPupilCenter = leftPupilPoints[0]
        let rightPupilCenter = rightPupilPoints[0]

        // Get eye landmarks for comparison
        guard let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return false
        }

        let leftEyePoints = leftEye.normalizedPoints
        let rightEyePoints = rightEye.normalizedPoints

        guard leftEyePoints.count >= 4 && rightEyePoints.count >= 4 else {
            return false
        }

        // Calculate pupil position relative to eye bounds
        // If pupil is centered in the eye, likely looking at camera
        let leftEyeCenterX = leftEyePoints.map { $0.x }.reduce(0, +) / CGFloat(leftEyePoints.count)
        let rightEyeCenterX = rightEyePoints.map { $0.x }.reduce(0, +) / CGFloat(rightEyePoints.count)

        let leftOffset = abs(leftPupilCenter.x - leftEyeCenterX)
        let rightOffset = abs(rightPupilCenter.x - rightEyeCenterX)

        // Threshold for "looking at camera" - pupils should be relatively centered
        let threshold: CGFloat = 0.15
        return leftOffset < threshold && rightOffset < threshold
    }

    /// Estimates gaze direction from eye shape when pupils aren't available
    private func estimateGazeFromEyes(landmarks: VNFaceLandmarks2D, faceObservation: VNFaceObservation) -> Bool {
        // Use face yaw (rotation) as a proxy
        // If face is relatively straight-on, assume looking at camera
        guard let yaw = faceObservation.yaw else {
            // If yaw unavailable, assume neutral (looking at camera)
            return true
        }

        // Yaw of ±20 degrees is acceptable for "eye contact"
        let yawDegrees = abs(yaw.doubleValue * 180.0 / .pi)
        return yawDegrees < 20.0
    }

    // MARK: - Body Posture Analysis

    /// Analyzes body posture across all frames
    /// - Parameter frames: Array of video frames
    /// - Returns: Posture metrics aggregated across all frames, or nil if insufficient data
    private func analyzeBodyPosture(in frames: [CVPixelBuffer]) async -> (PostureMetrics, [PostureFrame])? {
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

        // Return nil if too few bodies detected (instead of throwing error)
        guard Double(framesWithBody) / Double(frames.count) >= 0.1 else {
            print("⚠️ Insufficient posture data - body detected in <10% of frames")
            return nil
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

        let metrics = PostureMetrics(
            averageConfidence: averageConfidence,
            movementConsistency: movementConsistency,
            stabilityScore: stabilityScore,
            framesAnalyzed: framesWithBody,
            totalFrames: frames.count
        )

        return (metrics, postureFrames)
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

    /// Calculates eye contact score from metrics
    private func calculateEyeContactScore(from metrics: EyeContactMetrics) -> Int {
        let score = (
            metrics.cameraFocusPercentage * 0.70 +
            metrics.gazeStability * 0.30
        ) * 100.0

        return Int(score.rounded())
    }

    /// Calculates overall gesture score with graceful fallbacks for missing data
    private func calculateOverallScore(
        facial: Int?,
        posture: Int?,
        eyeContact: Int?,
        facialMetrics: FacialMetrics?,
        postureMetrics: PostureMetrics?,
        eyeContactMetrics: EyeContactMetrics?
    ) -> Int {
        // All three metrics available (face + posture + eye contact)
        if let facial = facial, let posture = posture, let eyeContact = eyeContact {
            let score = Double(facial) * 0.40 + Double(posture) * 0.35 + Double(eyeContact) * 0.25
            return Int(score.rounded())
        }

        // Facial + eye contact (no posture)
        if let facial = facial, let eyeContact = eyeContact {
            print("ℹ️ Using facial + eye contact scoring (body not detected)")
            let score = Double(facial) * 0.65 + Double(eyeContact) * 0.35
            return Int(score.rounded())
        }

        // Facial + posture (no eye contact)
        if let facial = facial, let posture = posture {
            print("ℹ️ Using facial + posture scoring (eye contact not measured)")
            let score = Double(facial) * 0.55 + Double(posture) * 0.45
            return Int(score.rounded())
        }

        // Only facial available
        if let facial = facial {
            print("ℹ️ Using facial-only scoring (body not detected, eye contact not measured)")
            return facial
        }

        // Only posture available (eye contact not possible without face)
        if let posture = posture {
            print("ℹ️ Using posture-only scoring (face not detected)")
            return posture
        }

        // Should never reach here due to guard in analyzeVideo
        return 50
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

    // MARK: - Key Frame Selection

    /// Selects 2-6 key frames from the analysis to provide visual feedback
    private func selectKeyFrames(
        from facialFrames: [FacialFrame],
        postureFrames: [PostureFrame],
        videoFrames: [CVPixelBuffer],
        facialScore: Int?,
        postureScore: Int?,
        eyeContactScore: Int?
    ) -> [KeyFrame] {
        print("🖼️ Selecting key frames for visual feedback...")

        var keyFrames: [KeyFrame] = []
        let frameInterval = 0.5 // 2 FPS = 0.5s per frame

        // Track which frame indices we've already used to avoid duplicates
        var usedIndices = Set<Int>()

        // 1. Try to find best facial expression frame
        if let idx = findBestFacialFrameIndex(facialFrames), idx < videoFrames.count {
            if let frame = createKeyFrame(
                from: videoFrames[idx],
                facialFrame: facialFrames[idx],
                postureFrame: idx < postureFrames.count ? postureFrames[idx] : nil,
                index: idx,
                type: .bestFacial,
                timestamp: Double(idx) * frameInterval,
                facialScore: facialScore,
                postureScore: postureScore,
                eyeContactScore: eyeContactScore
            ) {
                keyFrames.append(frame)
                usedIndices.insert(idx)
            }
        }

        // 2. Try to find best overall moment (requires both face and body)
        if !facialFrames.isEmpty && !postureFrames.isEmpty {
            if let idx = findBestOverallFrameIndex(facialFrames, postureFrames, usedIndices), idx < videoFrames.count {
                if let frame = createKeyFrame(
                    from: videoFrames[idx],
                    facialFrame: idx < facialFrames.count ? facialFrames[idx] : nil,
                    postureFrame: idx < postureFrames.count ? postureFrames[idx] : nil,
                    index: idx,
                    type: .bestOverall,
                    timestamp: Double(idx) * frameInterval,
                    facialScore: facialScore,
                    postureScore: postureScore,
                    eyeContactScore: eyeContactScore
                ) {
                    keyFrames.append(frame)
                    usedIndices.insert(idx)
                }
            }
        }

        // 3. Find improvement area: facial expression
        if !facialFrames.isEmpty, let facialScore = facialScore, facialScore < 85 {
            if let idx = findWorstFacialFrameIndex(facialFrames, usedIndices), idx < videoFrames.count {
                if let frame = createKeyFrame(
                    from: videoFrames[idx],
                    facialFrame: facialFrames[idx],
                    postureFrame: idx < postureFrames.count ? postureFrames[idx] : nil,
                    index: idx,
                    type: .improveFacial,
                    timestamp: Double(idx) * frameInterval,
                    facialScore: facialScore,
                    postureScore: postureScore,
                    eyeContactScore: eyeContactScore
                ) {
                    keyFrames.append(frame)
                    usedIndices.insert(idx)
                }
            }
        }

        // 4. Find improvement area: posture
        if !postureFrames.isEmpty, let postureScore = postureScore, postureScore < 85 {
            if let idx = findWorstPostureFrameIndex(postureFrames, usedIndices), idx < videoFrames.count {
                if let frame = createKeyFrame(
                    from: videoFrames[idx],
                    facialFrame: idx < facialFrames.count ? facialFrames[idx] : nil,
                    postureFrame: postureFrames[idx],
                    index: idx,
                    type: .improvePosture,
                    timestamp: Double(idx) * frameInterval,
                    facialScore: facialScore,
                    postureScore: postureScore,
                    eyeContactScore: eyeContactScore
                ) {
                    keyFrames.append(frame)
                    usedIndices.insert(idx)
                }
            }
        }

        // 5. If we have < 4 frames and eye contact issues, add eye contact improvement
        if keyFrames.count < 4, !facialFrames.isEmpty, let eyeContactScore = eyeContactScore, eyeContactScore < 70 {
            if let idx = findWorstEyeContactFrameIndex(facialFrames, usedIndices), idx < videoFrames.count {
                if let frame = createKeyFrame(
                    from: videoFrames[idx],
                    facialFrame: facialFrames[idx],
                    postureFrame: idx < postureFrames.count ? postureFrames[idx] : nil,
                    index: idx,
                    type: .improveEyeContact,
                    timestamp: Double(idx) * frameInterval,
                    facialScore: facialScore,
                    postureScore: postureScore,
                    eyeContactScore: eyeContactScore
                ) {
                    keyFrames.append(frame)
                    usedIndices.insert(idx)
                }
            }
        }

        // 6. If still < 2 frames, add an average representative frame
        if keyFrames.count < 2 && !videoFrames.isEmpty {
            let midIdx = videoFrames.count / 2
            if !usedIndices.contains(midIdx) {
                if let frame = createKeyFrame(
                    from: videoFrames[midIdx],
                    facialFrame: midIdx < facialFrames.count ? facialFrames[midIdx] : nil,
                    postureFrame: midIdx < postureFrames.count ? postureFrames[midIdx] : nil,
                    index: midIdx,
                    type: .averageMoment,
                    timestamp: Double(midIdx) * frameInterval,
                    facialScore: facialScore,
                    postureScore: postureScore,
                    eyeContactScore: eyeContactScore
                ) {
                    keyFrames.append(frame)
                }
            }
        }

        print("🖼️ Selected \(keyFrames.count) key frames")
        return keyFrames
    }

    /// Finds the index of the best facial expression frame
    private func findBestFacialFrameIndex(_ frames: [FacialFrame]) -> Int? {
        guard !frames.isEmpty else { return nil }

        let scores = frames.enumerated().map { (index, frame) -> (Int, Double) in
            let score = (frame.smiling ? 0.4 : 0.0) +
                       (frame.expressiveness * 0.3) +
                       (frame.engagement * 0.3)
            return (index, score)
        }

        return scores.max(by: { $0.1 < $1.1 })?.0
    }

    /// Finds the index of the best overall gesture frame (face + posture)
    private func findBestOverallFrameIndex(_ facialFrames: [FacialFrame], _ postureFrames: [PostureFrame], _ usedIndices: Set<Int>) -> Int? {
        let maxCount = min(facialFrames.count, postureFrames.count)
        guard maxCount > 0 else { return nil }

        let scores = (0..<maxCount).map { index -> (Int, Double) in
            guard !usedIndices.contains(index) else { return (index, -1.0) }

            let facialScore = (facialFrames[index].smiling ? 0.3 : 0.0) +
                            (facialFrames[index].expressiveness * 0.2) +
                            (facialFrames[index].engagement * 0.2) +
                            (facialFrames[index].lookingAtCamera ? 0.1 : 0.0)
            let postureScore = postureFrames[index].confidence * 0.2

            return (index, facialScore + postureScore)
        }

        let best = scores.max(by: { $0.1 < $1.1 })
        return (best?.1 ?? 0) > 0 ? best?.0 : nil
    }

    /// Finds the index of the worst facial expression frame (for improvement feedback)
    private func findWorstFacialFrameIndex(_ frames: [FacialFrame], _ usedIndices: Set<Int>) -> Int? {
        guard !frames.isEmpty else { return nil }

        let scores = frames.enumerated().compactMap { (index, frame) -> (Int, Double)? in
            guard !usedIndices.contains(index) else { return nil }

            let score = (frame.smiling ? 0.4 : 0.0) +
                       (frame.expressiveness * 0.3) +
                       (frame.engagement * 0.3)
            return (index, score)
        }

        return scores.min(by: { $0.1 < $1.1 })?.0
    }

    /// Finds the index of the worst posture frame
    private func findWorstPostureFrameIndex(_ frames: [PostureFrame], _ usedIndices: Set<Int>) -> Int? {
        guard !frames.isEmpty else { return nil }

        let scores = frames.enumerated().compactMap { (index, frame) -> (Int, Double)? in
            guard !usedIndices.contains(index) else { return nil }
            return (index, frame.confidence)
        }

        return scores.min(by: { $0.1 < $1.1 })?.0
    }

    /// Finds the index of the worst eye contact frame
    private func findWorstEyeContactFrameIndex(_ frames: [FacialFrame], _ usedIndices: Set<Int>) -> Int? {
        guard !frames.isEmpty else { return nil }

        // Find frames where NOT looking at camera
        let scores = frames.enumerated().compactMap { (index, frame) -> (Int, Double)? in
            guard !usedIndices.contains(index) else { return nil }
            return (index, frame.lookingAtCamera ? 1.0 : 0.0)
        }

        return scores.min(by: { $0.1 < $1.1 })?.0
    }

    /// Creates a KeyFrame from a pixel buffer with annotation
    private func createKeyFrame(
        from pixelBuffer: CVPixelBuffer,
        facialFrame: FacialFrame?,
        postureFrame: PostureFrame?,
        index: Int,
        type: KeyFrameType,
        timestamp: Double,
        facialScore: Int?,
        postureScore: Int?,
        eyeContactScore: Int?
    ) -> KeyFrame? {
        // Convert CVPixelBuffer to UIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)

        // Compress to JPEG (quality 0.6 for ~30-50KB)
        guard let imageData = uiImage.jpegData(compressionQuality: 0.6) else {
            return nil
        }

        // Generate annotation and score
        let (annotation, primaryMetric, isPositive) = generateAnnotation(
            type: type,
            facialFrame: facialFrame,
            postureFrame: postureFrame
        )

        let frameScore = calculateFrameScore(
            type: type,
            facialFrame: facialFrame,
            postureFrame: postureFrame,
            facialScore: facialScore,
            postureScore: postureScore,
            eyeContactScore: eyeContactScore
        )

        return KeyFrame(
            image: imageData,
            timestamp: timestamp,
            type: type,
            primaryMetric: primaryMetric,
            score: frameScore,
            annotation: annotation,
            isPositive: isPositive
        )
    }

    /// Generates annotation text based on frame type and metrics
    private func generateAnnotation(
        type: KeyFrameType,
        facialFrame: FacialFrame?,
        postureFrame: PostureFrame?
    ) -> (annotation: String, primaryMetric: String, isPositive: Bool) {
        switch type {
        case .bestFacial:
            if let facial = facialFrame {
                if facial.smiling && facial.lookingAtCamera {
                    return ("💪 Strong! Smile + eye contact = perfect connection", "Facial Expression", true)
                }
                if facial.smiling {
                    return ("✨ Great smile here! You appear open and inviting", "Facial Expression", true)
                }
                if facial.expressiveness > 0.7 {
                    return ("🎯 Very expressive! Your face emphasizes your message perfectly", "Facial Expression", true)
                }
            }
            return ("👍 Good facial expression in this moment", "Facial Expression", true)

        case .bestOverall:
            return ("🌟 Perfect moment! Expression, posture, and gaze align ideally", "Overall", true)

        case .improveFacial:
            if let facial = facialFrame {
                if !facial.smiling && facial.engagement < 0.5 {
                    return ("💡 Tip: Smile more and appear livelier - even with serious topics", "Facial Expression", false)
                }
                if !facial.lookingAtCamera {
                    return ("👁️ Look more at the camera instead of to the side - direct eye contact works", "Eye Contact", false)
                }
                if facial.expressiveness < 0.4 {
                    return ("🎭 Your expression could be more varied - show more emotion", "Facial Expression", false)
                }
            }
            return ("📝 Facial expression could be stronger here", "Facial Expression", false)

        case .improvePosture:
            if let posture = postureFrame {
                if posture.confidence < 0.5 {
                    return ("🏋️ Shoulders back, chest out - upright posture radiates confidence", "Posture", false)
                }
            }
            return ("📐 Body posture could appear more confident here", "Posture", false)

        case .improveEyeContact:
            return ("👀 Try looking at the camera more consistently to connect with your audience", "Eye Contact", false)

        case .averageMoment:
            return ("📊 Representative moment from your presentation", "Overall", true)
        }
    }

    /// Calculates a score for a specific frame
    private func calculateFrameScore(
        type: KeyFrameType,
        facialFrame: FacialFrame?,
        postureFrame: PostureFrame?,
        facialScore: Int?,
        postureScore: Int?,
        eyeContactScore: Int?
    ) -> Int {
        switch type {
        case .bestFacial:
            if let facial = facialFrame {
                let score = (facial.smiling ? 30.0 : 0.0) +
                          (facial.expressiveness * 35.0) +
                          (facial.engagement * 35.0)
                return Int(score.rounded())
            }
            return facialScore ?? 50

        case .bestOverall:
            var total = 0.0
            var count = 0.0
            if let fs = facialScore { total += Double(fs); count += 1 }
            if let ps = postureScore { total += Double(ps); count += 1 }
            if let es = eyeContactScore { total += Double(es); count += 1 }
            return count > 0 ? Int((total / count).rounded()) : 50

        case .improveFacial:
            if let facial = facialFrame {
                let score = (facial.smiling ? 30.0 : 0.0) +
                          (facial.expressiveness * 35.0) +
                          (facial.engagement * 35.0)
                return Int(score.rounded())
            }
            return facialScore ?? 50

        case .improvePosture:
            if let posture = postureFrame {
                return Int((posture.confidence * 100).rounded())
            }
            return postureScore ?? 50

        case .improveEyeContact:
            return eyeContactScore ?? 50

        case .averageMoment:
            var total = 0.0
            var count = 0.0
            if let fs = facialScore { total += Double(fs); count += 1 }
            if let ps = postureScore { total += Double(ps); count += 1 }
            return count > 0 ? Int((total / count).rounded()) : 50
        }
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
