//
//  RecordingView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI
import AVFoundation
import Combine

struct RecordingView: View {
    let recordingType: RecordingType?
    let project: Project?
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var audioMonitor = AudioMonitor()
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var navigateToAnalyzing = false
    @State private var showPermissionAlert = false
    @State private var recordedVideoURL: URL?

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(recordingType: RecordingType? = nil, project: Project? = nil) {
        self.recordingType = recordingType
        self.project = project
    }
    
    var body: some View {
        ZStack {
            // Camera preview as background
            if cameraManager.isAuthorized {
                CameraPreview(session: cameraManager.captureSession)
                    .ignoresSafeArea()
                    .overlay(
                        // Dim overlay when not recording
                        Color.black.opacity(isRecording ? 0 : 0.3)
                    )
            } else {
                // Fallback background
                Color.bg
                    .ignoresSafeArea()
            }
            
            VStack(spacing: Theme.largeSpacing) {
                Spacer()
                
                // Timer display when recording
                if isRecording {
                    HStack(alignment: .center, spacing: 8) {
                        // Recording indicator on left - SMALLER
                        HStack(spacing: 4) {
                            RecordingIndicator()
                                .scaleEffect(0.7)
                            Text("REC")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .cornerRadius(12)
                        .fixedSize()

                        Spacer()

                        // Timer in center - SMALLER FONT
                        Text(formatTime(recordingTime))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 8)
                            .lineLimit(1)
                            .fixedSize()

                        Spacer()

                        // Waveform on right - SMALLER
                        AudioVisualizerView(levels: audioMonitor.audioLevels)
                            .frame(width: 60, height: 20)
                            .clipped()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                } else {
                    Text("Ready to practice?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.5))
                        .cornerRadius(12)
                        .padding(.bottom, 40)
                }
                
                // Recording button
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    // Inner button
                    if isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.danger)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(Color.danger)
                            .frame(width: 64, height: 64)
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 10)
                .onTapGesture {
                    toggleRecording()
                }
                
                // Cancel button
                if !isRecording {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.black.opacity(0.5))
                            .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
                
                Spacer()
                    .frame(height: 60)
            }
            
        }
        .navigationDestination(isPresented: $navigateToAnalyzing) {
            if let videoURL = recordedVideoURL {
                AnalyzingView(videoURL: videoURL, recordingType: recordingType, project: project)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Practice Session")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    cameraManager.flipCamera()
                }) {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
                .disabled(isRecording)
            }
        }
        .toolbarBackground(Color.black.opacity(0.5), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            cameraManager.requestPermissionAndSetup()
            // Prepare haptic feedback for low latency
            hapticFeedback.prepare()
            // Check session status after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                cameraManager.checkSessionStatus()
            }
        }
        .onDisappear {
            cameraManager.cleanup()
        }
        .alert("Camera Access Required", isPresented: $showPermissionAlert) {
            Button("Cancel", role: .cancel) { 
                dismiss()
            }
            Button("Settings", role: .none) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } message: {
            Text("Eloquence needs camera access to record your practice sessions. Please enable it in Settings.")
        }
    }
    
    private func toggleRecording() {
        // Haptic feedback
        hapticFeedback.impactOccurred()

        guard cameraManager.isAuthorized && cameraManager.isSessionRunning else {
            showPermissionAlert = true
            return
        }

        isRecording.toggle()
        
        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    private func startRecording() {
        recordingTime = 0
        cameraManager.startRecording()
        audioMonitor.startMonitoring()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }
    
    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        audioMonitor.stopMonitoring()

        cameraManager.stopRecording { url in
            // Video saved at url
            print("Video saved at: \(url?.path ?? "unknown")")

            // Store video URL and navigate to analyzing screen
            if let url = url {
                recordedVideoURL = url
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    navigateToAnalyzing = true
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Camera Manager
class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    @Published var currentCameraPosition: AVCaptureDevice.Position = .front
    let captureSession = AVCaptureSession()

    private let videoOutput = AVCaptureMovieFileOutput()
    private var recordingCompletion: ((URL?) -> Void)?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    override init() {
        super.init()
    }
    
    func requestPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }
    
    func setupCamera() {
        guard isAuthorized else { return }
        
        // Stop if already running
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // Remove existing inputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        
        // Add video input
        do {
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
                print("No camera available for position: \(currentCameraPosition)")
                captureSession.commitConfiguration()
                return
            }
            
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                self.videoInput = videoInput
            }
        } catch {
            print("Error setting up video input: \(error)")
            captureSession.commitConfiguration()
            return
        }
        
        // Add audio input
        do {
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                    self.audioInput = audioInput
                }
            }
        } catch {
            print("Error setting up audio input: \(error)")
        }
        
        // Add video output
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        captureSession.commitConfiguration()
        
        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func checkSessionStatus() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isSessionRunning = self.captureSession.isRunning
        }
    }
    
    func cleanup() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if self.videoOutput.isRecording {
                self.videoOutput.stopRecording()
            }

            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }

    func flipCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Determine new position
            let newPosition: AVCaptureDevice.Position = self.currentCameraPosition == .front ? .back : .front

            self.captureSession.beginConfiguration()

            // Remove existing video input
            if let currentInput = self.videoInput {
                self.captureSession.removeInput(currentInput)
            }

            // Add new camera
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera),
                  self.captureSession.canAddInput(newInput) else {
                print("Failed to flip camera to position: \(newPosition)")
                // Re-add the old input if flip failed
                if let currentInput = self.videoInput, self.captureSession.canAddInput(currentInput) {
                    self.captureSession.addInput(currentInput)
                }
                self.captureSession.commitConfiguration()
                return
            }

            self.captureSession.addInput(newInput)
            self.videoInput = newInput

            self.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                self.currentCameraPosition = newPosition
                print("✅ Camera flipped to: \(newPosition == .front ? "front" : "back")")
            }
        }
    }
    
    func startRecording() {
        guard !videoOutput.isRecording && captureSession.isRunning else {
            print("Cannot start recording - session not ready")
            return
        }
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsPath = paths.first else {
            print("Cannot find documents directory")
            return
        }
        
        let fileUrl = documentsPath.appendingPathComponent("practice_\(Date().timeIntervalSince1970).mov")
        
        videoOutput.startRecording(to: fileUrl, recordingDelegate: self)
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard videoOutput.isRecording else {
            completion(nil)
            return
        }
        
        recordingCompletion = completion
        videoOutput.stopRecording()
    }
    
    // AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                print("Recording error: \(error.localizedDescription)")
                self?.recordingCompletion?(nil)
            } else {
                print("Recording saved successfully at: \(outputFileURL.path)")
                self?.recordingCompletion?(outputFileURL)
            }
            self?.recordingCompletion = nil
        }
    }
}

// Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = context.coordinator.previewLayer {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// Recording Indicator with pulsing animation
struct RecordingIndicator: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.5
    
    var body: some View {
        ZStack {
            // Pulsing outer ring - red
            Circle()
                .fill(Color.red)
                .frame(width: 16, height: 16)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
            
            // Main red dot
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                pulseScale = 2.0
                pulseOpacity = 0.0
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecordingView()
    }
}
