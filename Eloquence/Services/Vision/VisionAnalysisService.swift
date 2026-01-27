//
//  VisionAnalysisService.swift
//  Eloquence
//

import Foundation
import Vision
import CoreVideo
import CoreGraphics

class VisionAnalysisService {

    // MARK: - Facial Analysis

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

    // MARK: - Facial Helpers

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

        return mouthCurvature < -0.15
    }

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
        return min(1.0, (varianceSum / Double(count)) * 10.0)
    }

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

    /// Uses pupils + head pose to determine where the person is looking
    private func detectGazeDirection(from landmarks: VNFaceLandmarks2D, faceObservation: VNFaceObservation) -> GazeDirection {
        let eyeOpenness = calculateEyeOpenness(from: landmarks)
        guard eyeOpenness > 0.3 else {
            return .unknown
        }

        // Head turned significantly? Use head pose directly (pupil detection unreliable in profile)
        if let yaw = faceObservation.yaw {
            let yawDegrees = yaw.doubleValue * 180.0 / .pi
            if yawDegrees < -25.0 { return .right }
            if yawDegrees > 25.0 { return .left }
        }

        // Pupil-based detection for frontal faces
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

                let leftPupilCenter = leftPupilPoints[0]
                let rightPupilCenter = rightPupilPoints[0]

                let leftEyeCenterX = leftEyePoints.map { $0.x }.reduce(0, +) / CGFloat(leftEyePoints.count)
                let rightEyeCenterX = rightEyePoints.map { $0.x }.reduce(0, +) / CGFloat(rightEyePoints.count)

                let leftOffset = abs(leftPupilCenter.x - leftEyeCenterX)
                let rightOffset = abs(rightPupilCenter.x - rightEyeCenterX)

                let threshold: CGFloat = 0.15
                if leftOffset < threshold && rightOffset < threshold {
                    return .center
                }
            }
        }

        return estimateGazeDirectionFromPose(faceObservation: faceObservation)
    }

    /// Fallback: estimate gaze from head yaw/pitch
    private func estimateGazeDirectionFromPose(faceObservation: VNFaceObservation) -> GazeDirection {
        guard let yaw = faceObservation.yaw, let pitch = faceObservation.pitch else {
            return .center
        }

        let yawDegrees = yaw.doubleValue * 180.0 / .pi
        let pitchDegrees = pitch.doubleValue * 180.0 / .pi

        if pitchDegrees < -15.0 { return .down }
        if pitchDegrees > 15.0 { return .up }
        if yawDegrees < -20.0 { return .right }
        if yawDegrees > 20.0 { return .left }

        return .center
    }

    // MARK: - Posture Helpers

    private func calculatePostureConfidence(leftShoulder: CGPoint, rightShoulder: CGPoint, neck: CGPoint) -> Double {
        let shoulderDiff = abs(leftShoulder.y - rightShoulder.y)
        let shoulderDistance = distance(leftShoulder, rightShoulder)
        let shoulderAlignment = max(0, 1.0 - (Double(shoulderDiff) / Double(shoulderDistance)) * 5.0)

        let shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2.0
        let neckOffset = abs(neck.x - shoulderMidX) / shoulderDistance
        let verticalPosture = max(0, 1.0 - Double(neckOffset) * 2.0)

        return (shoulderAlignment * 0.6 + verticalPosture * 0.4)
    }

    // MARK: - Utilities

    private func calculateVariance(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }

    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
}
