//
//  AudioExtractionService.swift
//  Eloquence
//
//  Service for extracting audio from video files
//

import Foundation
import AVFoundation

class AudioExtractionService: ObservableObject {

    /// Extracts audio from a video file and returns the audio file URL
    /// - Parameter videoURL: URL of the source video file (.mov)
    /// - Returns: URL of the extracted audio file (.m4a)
    func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        // Verify asset is valid and readable
        guard try await asset.load(.isReadable) else {
            throw AudioExtractionError.invalidFormat
        }

        // Check if asset has audio tracks
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioExtractionError.noAudioTrack
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExtractionError.cannotCreateExportSession
        }

        // Set up output
        let outputURL = try createTempAudioURL()

        // Export audio using new throwing API
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
            return outputURL
        } catch {
            throw AudioExtractionError.exportFailed(error)
        }
    }

    /// Gets the duration of an audio file in seconds
    /// - Parameter audioURL: URL of the audio file
    /// - Returns: Duration in seconds
    func getAudioDuration(_ audioURL: URL) async throws -> Double {
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    /// Creates a temporary URL for the extracted audio file
    /// - Returns: URL in the temporary directory
    private func createTempAudioURL() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "audio_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(filename)
    }

    /// Cleans up temporary audio file
    /// - Parameter audioURL: URL of the audio file to delete
    func cleanupAudioFile(_ audioURL: URL) {
        try? FileManager.default.removeItem(at: audioURL)
    }

    /// Validates that a video file exists and has audio
    /// - Parameter videoURL: URL of the video file to validate
    /// - Returns: True if video exists and has audio tracks
    func validateVideoFile(_ videoURL: URL) async -> Bool {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            return false
        }

        let asset = AVURLAsset(url: videoURL)

        do {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            return !audioTracks.isEmpty
        } catch {
            return false
        }
    }
}
