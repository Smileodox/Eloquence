//
//  VisionAnalysisService.swift
//  Eloquence
//
//  Service for analyzing frames using Apple Vision Framework
//

import Foundation
import Vision
import CoreVideo
import CoreGraphics

/// Service responsible for Vision Framework operations (facial and body pose analysis)
class VisionAnalysisService {

    // MARK: - Facial Analysis

    /// Analyzes a single frame for facial expressions
    /// - Parameter pixelBuffer: Video frame to analyze
    /// - Returns: Facial frame data or nil if no face detected
    /// - Throws: Vision Framework errors
    func analyzeFacialFrame(_ pixelBuffer: CVPixelBuffer) throws -> FacialFrame? {
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

        // Detect gaze direction (Camera, Down, Up, etc.)
        let gazeDirection = detectGazeDirection(from: landmarks, faceObservation: faceObservation)

        return FacialFrame(
            smiling: smiling,
            expressiveness: expressiveness,
            engagement: engagement,
            gazeDirection: gazeDirection
        )
    }

    // MARK: - Posture Analysis

    /// Analyzes a single frame for body posture
    /// - Parameter pixelBuffer: Video frame to analyze
    /// - Returns: Posture frame data or nil if no body detected
    /// - Throws: Vision Framework errors
    func analyzePostureFrame(_ pixelBuffer: CVPixelBuffer) throws -> PostureFrame? {
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

    // MARK: - Private Facial Analysis Helpers

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

    /// Detects gaze direction by analyzing pupils and head pose
    private func detectGazeDirection(from landmarks: VNFaceLandmarks2D, faceObservation: VNFaceObservation) -> GazeDirection {
        // CRITICAL: First check if eyes are actually open
        let eyeOpenness = calculateEyeOpenness(from: landmarks)
        guard eyeOpenness > 0.3 else {
            print("👁️ [Primary Detection] Eyes not sufficiently open (openness: \(String(format: "%.2f", eyeOpenness))) - cannot determine gaze")
            return .unknown
        }
        
        // Check Head Pose FIRST
        // If head is turned significantly, pupil detection is unreliable and likely false positive due to 2D projection
        if let yaw = faceObservation.yaw {
            let yawDegrees = yaw.doubleValue * 180.0 / .pi
            if yawDegrees < -25.0 {
                print("👁️ [Primary Detection] Head turned Right (\(String(format: "%.1f", yawDegrees))°) - skipping pupil check")
                return .right
            }
            if yawDegrees > 25.0 {
                print("👁️ [Primary Detection] Head turned Left (\(String(format: "%.1f", yawDegrees))°) - skipping pupil check")
                return .left
            }
        }

        // Try pupil-based detection (most accurate for frontal faces)
        if let leftPupil = landmarks.leftPupil,
           let rightPupil = landmarks.rightPupil,
           let leftEye = landmarks.leftEye,
           let rightEye = landmarks.rightEye {
            
            let leftPupilPoints = leftPupil.normalizedPoints
            let rightPupilPoints = rightPupil.normalizedPoints
            let leftEyePoints = leftEye.normalizedPoints
            let rightEyePoints = rightEye.normalizedPoints
            
            if !leftPupilPoints.isEmpty && !rightPupilPoints.isEmpty &&
                leftEyePoints.count >= 4 && rightEyePoints.count >= 4 {
                
                // Get average pupil position
                let leftPupilCenter = leftPupilPoints[0]
                let rightPupilCenter = rightPupilPoints[0]
                
                // Calculate pupil position relative to eye bounds
                let leftEyeCenterX = leftEyePoints.map { $0.x }.reduce(0, +) / CGFloat(leftEyePoints.count)
                let rightEyeCenterX = rightEyePoints.map { $0.x }.reduce(0, +) / CGFloat(rightEyePoints.count)
                
                let leftOffset = abs(leftPupilCenter.x - leftEyeCenterX)
                let rightOffset = abs(rightPupilCenter.x - rightEyeCenterX)
                
                // Threshold for "looking at camera" - pupils should be relatively centered
                let threshold: CGFloat = 0.15
                let hasCenteredPupils = leftOffset < threshold && rightOffset < threshold
                
                if hasCenteredPupils {
                    print("👁️ [Primary Detection] Eye contact detected - eyes open (\(String(format: "%.2f", eyeOpenness))) and pupils centered")
                    return .center
                }
            }
        }
        
        // Fallback: If pupils not centered or not detected, use head pose (Yaw/Pitch)
        return estimateGazeDirectionFromPose(faceObservation: faceObservation)
    }

    /// Estimates gaze direction from head pose (Yaw/Pitch) when pupils aren't centered
    private func estimateGazeDirectionFromPose(faceObservation: VNFaceObservation) -> GazeDirection {
        // Use face yaw (rotation) and pitch (tilt) as proxies
        guard let yaw = faceObservation.yaw, let pitch = faceObservation.pitch else {
            return .center // Default to center if no pose data
        }

        let yawDegrees = yaw.doubleValue * 180.0 / .pi
        let pitchDegrees = pitch.doubleValue * 180.0 / .pi
        
        // 1. Check Pitch (Up/Down) - Highest priority for "Reading Notes"
        // Pitch is typically: negative = down, positive = up (verify in logs)
        if pitchDegrees < -15.0 {
            return .down // Reading notes
        }
        if pitchDegrees > 15.0 {
            return .up // Thinking / Looking at ceiling
        }
        
        // 2. Check Yaw (Left/Right)
        // Yaw is typically: negative = right (subject's right), positive = left
        if yawDegrees < -20.0 {
            return .right
        }
        if yawDegrees > 20.0 {
            return .left
        }
        
        // If within all thresholds, assume Center
        return .center
    }

    // MARK: - Private Posture Analysis Helpers

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

    // MARK: - Utility Methods

    /// Calculates variance of a set of values
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
