//
//  KeyFrameSelector.swift
//  Eloquence
//
//  Service for selecting representative key frames from analyzed video
//

import Foundation
import UIKit
import CoreImage
import CoreVideo

/// Service responsible for selecting key frames from video analysis
class KeyFrameSelector {

    // MARK: - Properties

    /// Reusable CIContext for image conversion (performance optimization)
    private lazy var ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
            .cacheIntermediates: false  // Key frames are one-time use
        ]
        return CIContext(options: options)
    }()

    // MARK: - Public Methods

    /// Selects key frames for visual feedback
    /// - Parameters:
    ///   - facialFrames: Array of analyzed facial frames
    ///   - postureFrames: Array of analyzed posture frames
    ///   - videoFrames: Original video frame buffers
    ///   - facialScore: Optional facial expression score
    ///   - postureScore: Optional posture score
    ///   - eyeContactScore: Optional eye contact score
    /// - Returns: Array of key frames (2-6 frames)
    func selectKeyFrames(
        from facialFrames: [FacialFrame],
        postureFrames: [PostureFrame],
        videoFrames: [CVPixelBuffer],
        facialScore: Int?,
        postureScore: Int?,
        eyeContactScore: Int?
    ) -> [KeyFrame] {
        print("🖼️ [KeyFrameSelector] Selecting key frames for visual feedback...")

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

        print("🖼️ [KeyFrameSelector] Selected \(keyFrames.count) key frames")
        return keyFrames
    }

    // MARK: - Private Helper Methods

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
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
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
