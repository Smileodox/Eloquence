//
//  FrameExtractionService.swift
//  Eloquence
//
//  Service for extracting frames from video files
//

import Foundation
import AVFoundation
import CoreVideo

/// Errors that can occur during frame extraction
enum FrameExtractionError: Error {
    case invalidVideoURL
    case videoReadError
    case noVideoTrack
    case imageGenerationFailed
    case frameSamplingFailed

    var localizedDescription: String {
        switch self {
        case .invalidVideoURL:
            return "Invalid video URL provided"
        case .videoReadError:
            return "Unable to read video file"
        case .noVideoTrack:
            return "No video track found in file"
        case .imageGenerationFailed:
            return "Failed to generate images from video"
        case .frameSamplingFailed:
            return "Failed to sample frames at requested rate"
        }
    }
}

/// Service responsible for extracting frames from video files
class FrameExtractionService {

    // MARK: - Public Methods

    /// Streams frames from video at specified sample rate for memory efficiency
    /// - Parameters:
    ///   - videoURL: URL of the video file
    ///   - sampleRate: Frames per second to extract. If nil, uses adaptive sampling.
    ///   - handler: Async closure called for each frame (Buffer, Timestamp)
    func processFrames(from videoURL: URL, sampleRate: Double? = nil, handler: (CVPixelBuffer, Double) async -> Void) async throws {
        let asset = AVURLAsset(url: videoURL)

        // Verify asset is readable
        guard try await asset.load(.isReadable) else {
            throw FrameExtractionError.videoReadError
        }

        // Get video duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        // Adaptive sampling
        let effectiveFPS = sampleRate ?? calculateAdaptiveFPS(for: durationSeconds)
        
        print("📹 [FrameExtraction] Streaming frames: \(String(format: "%.1f", durationSeconds))s @ \(String(format: "%.1f", effectiveFPS)) FPS")

        // Calculate frame times
        let frameInterval = 1.0 / effectiveFPS
        let times = stride(from: 0, to: durationSeconds, by: frameInterval)
            .map { CMTime(seconds: $0, preferredTimescale: 600) }

        // Create image generator
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.appliesPreferredTrackTransform = true

        // Iterate and yield
        for time in times {
            // Note: We cannot use autoreleasepool with async/await here.
            // The scope of the loop iteration should suffice for releasing local CVPixelBuffers.
            do {
                let (cgImage, _) = try await imageGenerator.image(at: time)
                if let pixelBuffer = cgImage.toPixelBuffer() {
                    // Yield frame and timestamp to handler
                    await handler(pixelBuffer, CMTimeGetSeconds(time))
                }
            } catch {
                print("⚠️ [FrameExtraction] Failed to extract frame at \(CMTimeGetSeconds(time))s: \(error)")
            }
        }
        
        print("📹 [FrameExtraction] Streaming complete")
    }

    /// Extracts frames from video at specified sample rate
    /// - Parameters:
    ///   - videoURL: URL of the video file
    ///   - sampleRate: Frames per second to extract (e.g., 2.0 = 2 FPS). If nil, uses adaptive sampling based on video duration.
    /// - Returns: Array of CVPixelBuffer frames
    func extractFrames(from videoURL: URL, sampleRate: Double? = nil) async throws -> [CVPixelBuffer] {
        // ... (Keep existing implementation for backward compatibility if needed, or simply delegate to processFrames?)
        // For now, we keep the original implementation but it shouldn't be used for long videos.

        let asset = AVURLAsset(url: videoURL)

        // Verify asset is readable
        guard try await asset.load(.isReadable) else {
            throw FrameExtractionError.videoReadError
        }

        // Get video duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        // Adaptive sampling based on duration (if sampleRate not specified)
        let effectiveFPS = sampleRate ?? calculateAdaptiveFPS(for: durationSeconds)

        let totalFrames = Int(durationSeconds * effectiveFPS)
        print("📹 [FrameExtraction] Video duration: \(String(format: "%.1f", durationSeconds))s → \(String(format: "%.1f", effectiveFPS)) FPS → \(totalFrames) frames")

        // Calculate frame times
        let frameInterval = 1.0 / effectiveFPS
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
            do {
                let (cgImage, _) = try await imageGenerator.image(at: time)
                if let pixelBuffer = cgImage.toPixelBuffer() {
                    frames.append(pixelBuffer)
                }
            } catch {
                print("⚠️ [FrameExtraction] Failed to extract frame at \(CMTimeGetSeconds(time))s: \(error)")
            }
        }

        print("📹 [FrameExtraction] Successfully extracted \(frames.count) frames")
        return frames
    }

    /// Estimates the number of frames that will be extracted
    /// - Parameters:
    ///   - videoURL: URL of the video file
    ///   - sampleRate: Optional frames per second (if nil, uses adaptive sampling)
    /// - Returns: Estimated frame count
    func estimateFrameCount(for videoURL: URL, sampleRate: Double? = nil) async throws -> Int {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await CMTimeGetSeconds(asset.load(.duration))
        let fps = sampleRate ?? calculateAdaptiveFPS(for: duration)
        return Int(duration * fps)
    }

    // MARK: - Private Methods

    /// Calculates adaptive FPS based on video duration
    /// - Parameter durationSeconds: Video duration in seconds
    /// - Returns: Recommended frames per second
    private func calculateAdaptiveFPS(for durationSeconds: Double) -> Double {
        switch durationSeconds {
        case 0..<20:
            return 3.0  // More detail for short presentations
        case 20..<60:
            return 2.0  // Default for typical presentations
        case 60..<120:
            return 1.5  // Balance for longer presentations
        default:
            return 1.0  // Efficiency for very long videos
        }
    }
}

// MARK: - CGImage Extension

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
