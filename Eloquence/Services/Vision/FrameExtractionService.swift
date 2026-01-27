//
//  FrameExtractionService.swift
//  Eloquence
//

import Foundation
import AVFoundation
import CoreVideo

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

class FrameExtractionService {

    // MARK: - Streaming

    func processFrames(from videoURL: URL, sampleRate: Double? = nil, handler: (CVPixelBuffer, Double) async -> Void) async throws {
        let asset = AVURLAsset(url: videoURL)

        guard try await asset.load(.isReadable) else {
            throw FrameExtractionError.videoReadError
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let effectiveFPS = sampleRate ?? calculateAdaptiveFPS(for: durationSeconds)

        print("[Frames] Streaming: \(String(format: "%.1f", durationSeconds))s @ \(String(format: "%.1f", effectiveFPS)) FPS")

        let frameInterval = 1.0 / effectiveFPS
        let times = stride(from: 0, to: durationSeconds, by: frameInterval)
            .map { CMTime(seconds: $0, preferredTimescale: 600) }

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.appliesPreferredTrackTransform = true

        for time in times {
            do {
                let (cgImage, _) = try await imageGenerator.image(at: time)
                if let pixelBuffer = cgImage.toPixelBuffer() {
                    await handler(pixelBuffer, CMTimeGetSeconds(time))
                }
            } catch {
                // Skip failed frames silently
            }
        }
    }

    // MARK: - Batch Extraction (legacy)

    func extractFrames(from videoURL: URL, sampleRate: Double? = nil) async throws -> [CVPixelBuffer] {
        let asset = AVURLAsset(url: videoURL)

        guard try await asset.load(.isReadable) else {
            throw FrameExtractionError.videoReadError
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let effectiveFPS = sampleRate ?? calculateAdaptiveFPS(for: durationSeconds)

        print("[Frames] Extracting: \(String(format: "%.1f", durationSeconds))s @ \(String(format: "%.1f", effectiveFPS)) FPS")

        let frameInterval = 1.0 / effectiveFPS
        let frameTimes = stride(from: 0, to: durationSeconds, by: frameInterval)
            .map { CMTime(seconds: $0, preferredTimescale: 600) }

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.appliesPreferredTrackTransform = true

        var frames: [CVPixelBuffer] = []

        for time in frameTimes {
            do {
                let (cgImage, _) = try await imageGenerator.image(at: time)
                if let pixelBuffer = cgImage.toPixelBuffer() {
                    frames.append(pixelBuffer)
                }
            } catch {
                // Skip failed frames
            }
        }

        print("[Frames] Extracted \(frames.count) frames")
        return frames
    }

    func estimateFrameCount(for videoURL: URL, sampleRate: Double? = nil) async throws -> Int {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await CMTimeGetSeconds(asset.load(.duration))
        let fps = sampleRate ?? calculateAdaptiveFPS(for: duration)
        return Int(duration * fps)
    }

    // MARK: - Private

    private func calculateAdaptiveFPS(for durationSeconds: Double) -> Double {
        switch durationSeconds {
        case 0..<20:  return 3.0
        case 20..<60: return 2.0
        case 60..<120: return 1.5
        default: return 1.0
        }
    }
}

// MARK: - CGImage Extension

extension CGImage {
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
