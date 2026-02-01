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
    let keyFrames: [KeyFrame]  // Visual highlights from the presentation
    var insufficientData: Bool = false

    // MARK: - Detection Quality Metadata
    /// Overall detection rate across all metrics (facial + posture)
    var overallDetectionRate: Double {
        let facialRate = facialMetrics.detectionRate
        let postureRate = postureMetrics.detectionRate
        return (facialRate + postureRate) / 2.0
    }

    /// Indicates if detection quality is sufficient for reliable analysis
    var isReliableAnalysis: Bool {
        return overallDetectionRate >= 0.3
    }
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

enum GazeDirection: String, Codable {
    case center = "Camera"
    case down = "Down"      // Reading notes
    case up = "Up"          // Thinking
    case left = "Left"      // Audience scanning
    case right = "Right"    // Audience scanning
    case unknown = "Unknown"
}

struct FacialFrame {
    let smiling: Bool
    let expressiveness: Double
    let engagement: Double
    let gazeDirection: GazeDirection
    
    // Computed property for backward compatibility
    var lookingAtCamera: Bool {
        return gazeDirection == .center
    }
}

struct EyeContactMetrics {
    let cameraFocusPercentage: Double  // 0.0-1.0 (% of frames looking at camera)
    let readingNotesPercentage: Double // 0.0-1.0 (% of frames looking down)
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

// MARK: - Key Frame Models

/// Represents a significant moment in the presentation with visual feedback
struct KeyFrame: Codable, Identifiable {
    let id: UUID
    var image: Data              // In-memory JPEG data (Not persisted directly)
    var imagePath: String?       // Path to stored image file (Persisted)
    let timestamp: Double
    let type: KeyFrameType
    let primaryMetric: String
    let score: Int
    let annotation: String
    let isPositive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, imagePath, timestamp, type, primaryMetric, score, annotation, isPositive
    }

    init(id: UUID = UUID(), image: Data, timestamp: Double, type: KeyFrameType, primaryMetric: String, score: Int, annotation: String, isPositive: Bool, imagePath: String? = nil) {
        self.id = id
        self.image = image
        self.timestamp = timestamp
        self.type = type
        self.primaryMetric = primaryMetric
        self.score = score
        self.annotation = annotation
        self.isPositive = isPositive
        self.imagePath = imagePath
    }
    
    // Custom decoding to load image from disk
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Double.self, forKey: .timestamp)
        type = try container.decode(KeyFrameType.self, forKey: .type)
        primaryMetric = try container.decode(String.self, forKey: .primaryMetric)
        score = try container.decode(Int.self, forKey: .score)
        annotation = try container.decode(String.self, forKey: .annotation)
        isPositive = try container.decode(Bool.self, forKey: .isPositive)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        
        // Load image from disk if path exists
        if let path = imagePath, let data = FileStorageService.shared.loadImage(path: path) {
            image = data
        } else {
            image = Data() // Fallback if file missing
            print("⚠️ [KeyFrame] Failed to load image for keyframe \(id)")
        }
    }
    
    // Custom encoding to ensure we only save the path
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        try container.encode(primaryMetric, forKey: .primaryMetric)
        try container.encode(score, forKey: .score)
        try container.encode(annotation, forKey: .annotation)
        try container.encode(isPositive, forKey: .isPositive)
        try container.encode(imagePath, forKey: .imagePath)
        // Image data is NOT encoded here
    }
}

/// Types of key frames that can be extracted from analysis
enum KeyFrameType: String, Codable {
    case bestFacial = "best_facial"           // Best facial expression moment
    case bestOverall = "best_overall"         // Best combined gesture moment
    case improveFacial = "improve_facial"     // Facial expression needs work
    case improvePosture = "improve_posture"   // Posture needs improvement
    case improveEyeContact = "improve_eye_contact"  // Eye contact needs work
    case averageMoment = "average_moment"     // Representative average frame
}
