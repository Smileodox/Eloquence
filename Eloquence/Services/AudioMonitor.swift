//
//  AudioMonitor.swift
//  Eloquence
//
//  Real-time audio level monitoring for recording feedback
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

class AudioMonitor: NSObject, ObservableObject {
    @Published var audioLevels: [CGFloat] = Array(repeating: 0.0, count: 20)

    private var audioRecorder: AVAudioRecorder?
    private var updateTimer: Timer?
    private let numberOfBars = 20

    override init() {
        super.init()
    }

    func startMonitoring() {
        // Request audio permission
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted else {
                print("⚠️ [AudioMonitor] Microphone permission denied")
                return
            }

            DispatchQueue.main.async {
                self?.setupAudioRecorder()
            }
        }
    }

    private func setupAudioRecorder() {
        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
        } catch {
            print("⚠️ [AudioMonitor] Failed to configure audio session: \(error)")
            return
        }

        // Create temporary file for silent recording
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("audio_monitor_temp.m4a")

        // Audio recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]

        do {
            // Create audio recorder with metering enabled
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            // Start update timer (20 FPS = 0.05s)
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.updateLevels()
            }

            print("✅ [AudioMonitor] Started monitoring audio levels")
        } catch {
            print("⚠️ [AudioMonitor] Failed to create audio recorder: \(error)")
        }
    }

    private func updateLevels() {
        guard let recorder = audioRecorder else { return }

        // Update metering
        recorder.updateMeters()

        // Get average power in dB (-160 to 0)
        let averagePower = recorder.averagePower(forChannel: 0)

        // Convert dB to normalized level (0.0 to 1.0)
        // -160 dB (silence) -> 0.0
        // 0 dB (max) -> 1.0
        let minDb: Float = -60.0  // Anything below -60dB is considered silence
        let normalizedLevel = max(0.0, min(1.0, (averagePower - minDb) / (-minDb)))

        // Add some randomness to adjacent bars for visual effect
        let baseLevel = CGFloat(normalizedLevel)
        var newLevels = audioLevels

        // Shift existing levels (create wave effect)
        for i in 0..<(numberOfBars - 1) {
            newLevels[i] = audioLevels[i + 1]
        }

        // Add new level with slight variation
        let variation = CGFloat.random(in: -0.1...0.1)
        newLevels[numberOfBars - 1] = max(0.0, min(1.0, baseLevel + variation))

        // Smooth animation
        withAnimation(.easeInOut(duration: 0.05)) {
            audioLevels = newLevels
        }
    }

    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("⚠️ [AudioMonitor] Failed to deactivate audio session: \(error)")
        }

        // Reset levels
        audioLevels = Array(repeating: 0.0, count: numberOfBars)

        // Clean up temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("audio_monitor_temp.m4a")
        try? FileManager.default.removeItem(at: audioURL)

        print("✅ [AudioMonitor] Stopped monitoring audio levels")
    }

    deinit {
        stopMonitoring()
    }
}
