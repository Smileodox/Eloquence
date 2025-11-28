//
//  GestureModels.swift
//  Eloquence
//
//  Data models for gesture/mimik analysis using Vision Framework
//

import Foundation

// MARK: - Gesture Analysis Results

struct GestureMetrics {
    let facialMetrics: FacialMetrics
    let postureMetrics: PostureMetrics
    let eyeContactMetrics: EyeContactMetrics?  // Only available if face detected
    let overallScore: Int
    let facialScore: Int
    let postureScore: Int
    let eyeContactScore: Int?  // Nil if face not detected
}

struct FacialMetrics {
    let smileFrequency: Double       // 0.0-1.0 (percentage of frames with smile)
    let expressionVariety: Double    // 0.0-1.0 (variance in facial expressions)
    let averageEngagement: Double    // 0.0-1.0 (face quality + eye openness)
    let framesAnalyzed: Int          // Total frames successfully analyzed
    let totalFrames: Int             // Total frames attempted

    var detectionRate: Double {
        guard totalFrames > 0 else { return 0.0 }
        return Double(framesAnalyzed) / Double(totalFrames)
    }
}

struct PostureMetrics {
    let averageConfidence: Double    // 0.0-1.0 (shoulder/spine alignment)
    let movementConsistency: Double  // 0.0-1.0 (natural movement)
    let stabilityScore: Double       // 0.0-1.0 (balanced movement)
    let framesAnalyzed: Int          // Total frames successfully analyzed
    let totalFrames: Int             // Total frames attempted

    var detectionRate: Double {
        guard totalFrames > 0 else { return 0.0 }
        return Double(framesAnalyzed) / Double(totalFrames)
    }
}

// MARK: - Intermediate Analysis Data

struct FacialFrame {
    let smiling: Bool
    let expressiveness: Double
    let engagement: Double
    let lookingAtCamera: Bool  // Eye contact detection
}

struct EyeContactMetrics {
    let cameraFocusPercentage: Double  // 0.0-1.0 (% of frames looking at camera)
    let gazeStability: Double          // 0.0-1.0 (consistency of gaze direction)
    let framesAnalyzed: Int            // Frames with eye contact data
    let totalFrames: Int               // Total facial frames

    var detectionRate: Double {
        guard totalFrames > 0 else { return 0.0 }
        return Double(framesAnalyzed) / Double(totalFrames)
    }
}

struct PostureFrame {
    let confidence: Double
    let centerX: Double           // Normalized body center X position
    let centerY: Double           // Normalized body center Y position
}

// MARK: - Error Models

enum GestureAnalysisError: Error {
    case videoReadError
    case frameExtractionError
    case visionRequestFailed(Error)
    case noFaceDetected
    case noBodyDetected
    case insufficientData
    case unsupportedVideoFormat

    var userMessage: String {
        switch self {
        case .videoReadError:
            return "Could not read video file. Please try recording again."
        case .frameExtractionError:
            return "Failed to extract video frames. Please ensure the video is properly recorded."
        case .visionRequestFailed:
            return "Vision analysis failed. Please try again."
        case .noFaceDetected:
            return "Face not clearly visible in video. Please ensure you're centered in the frame with good lighting."
        case .noBodyDetected:
            return "Body posture not detected. Please ensure you're visible in the frame."
        case .insufficientData:
            return "Could not analyze gestures. Please ensure good lighting and frame yourself clearly in the video."
        case .unsupportedVideoFormat:
            return "Video format not supported. Please record using the app's built-in recorder."
        }
    }
}
