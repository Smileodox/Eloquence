//
//  AzureOpenAIService.swift
//  Eloquence
//
//  Service for Azure OpenAI API communication via backend proxy
//

import Foundation

class AzureOpenAIService {

    private let config = ConfigurationManager.shared

    // MARK: - Backend Proxy Endpoints

    private var transcribeURL: URL {
        URL(string: "\(config.azureAuthBaseURL)/llm/transcribe")!
    }

    private var analyzeSpeechURL: URL {
        URL(string: "\(config.azureAuthBaseURL)/llm/analyze-speech")!
    }

    private var analyzeGestureURL: URL {
        URL(string: "\(config.azureAuthBaseURL)/llm/analyze-gesture")!
    }

    private var annotateFrameURL: URL {
        URL(string: "\(config.azureAuthBaseURL)/llm/annotate-frame")!
    }

    // MARK: - Authentication Helper

    /// Gets the current session token for API authentication
    private func getAuthToken() throws -> String {
        guard let session = SessionStorageService.shared.loadSession() else {
            throw AzureAPIError.authenticationFailed
        }
        return session.accessToken
    }

    // MARK: - Whisper API (Speech-to-Text)

    /// Transcribes audio using the backend proxy to Azure OpenAI Whisper API
    /// - Parameter audioURL: URL of the audio file (.m4a)
    /// - Returns: Transcription result with text and metadata
    func transcribeAudio(_ audioURL: URL) async throws -> WhisperTranscription {
        let token = try getAuthToken()

        // Read audio file
        let audioData = try Data(contentsOf: audioURL)
        print("🔊 Audio file size: \(audioData.count) bytes")

        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Create request
        var request = URLRequest(url: transcribeURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 60

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        print("🔊 Transcribe Response Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")

        try validateResponse(response, data: data)

        // Parse response
        let transcription = try JSONDecoder().decode(WhisperTranscription.self, from: data)

        // Validate transcription is not empty
        guard !transcription.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AzureAPIError.emptyTranscription
        }

        return transcription
    }

    // MARK: - Local Metrics Analysis

    /// Analyzes speech metrics from transcription
    /// - Parameters:
    ///   - transcription: The transcribed text
    ///   - audioDuration: Duration of the audio in seconds
    /// - Returns: Speech metrics including WPM, pauses, etc.
    func analyzeSpeechMetrics(transcription: String, audioDuration: Double) -> SpeechMetrics {
        let cleanedText = transcription.trimmingCharacters(in: .whitespacesAndNewlines)

        // Count words
        let words = cleanedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let wordCount = words.count

        // Calculate words per minute
        let minutes = audioDuration / 60.0
        let wordsPerMinute = minutes > 0 ? Int(Double(wordCount) / minutes) : 0

        // Count pauses (represented by punctuation)
        let pausePunctuation: Set<Character> = [".", "!", "?", ",", ";", ":", "-"]
        let pauseCount = cleanedText.filter { pausePunctuation.contains($0) }.count

        // Count sentences
        let sentenceEnders: Set<Character> = [".", "!", "?"]
        let sentenceCount = max(1, cleanedText.filter { sentenceEnders.contains($0) }.count)

        return SpeechMetrics(
            transcription: transcription,
            wordCount: wordCount,
            duration: audioDuration,
            wordsPerMinute: wordsPerMinute,
            pauseCount: pauseCount,
            sentenceCount: sentenceCount
        )
    }

    // MARK: - GPT API (Feedback Generation)

    /// Generates personalized feedback using the backend proxy
    /// - Parameters:
    ///   - transcription: The speech transcription
    ///   - metrics: Speech metrics (WPM, pauses, etc.)
    /// - Returns: Analysis with scores and feedback
    func generateFeedback(transcription: String, metrics: SpeechMetrics) async throws -> GPTAnalysisResponse {
        let token = try getAuthToken()

        // Build request body matching backend SpeechAnalysisRequest
        let requestBody: [String: Any] = [
            "transcription": transcription,
            "wordCount": metrics.wordCount,
            "duration": metrics.duration,
            "wordsPerMinute": metrics.wordsPerMinute,
            "pauseCount": metrics.pauseCount,
            "sentenceCount": metrics.sentenceCount,
            "averageSentenceLength": metrics.averageSentenceLength
        ]

        let requestData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: analyzeSpeechURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 60

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        print("💬 Speech Analysis Response Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")

        try validateResponse(response, data: data)

        // Parse response
        let analysis = try JSONDecoder().decode(GPTAnalysisResponse.self, from: data)
        return analysis
    }

    // MARK: - Helpers

    /// Validates HTTP response and checks for errors
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Success
            return
        case 401:
            print("❌ Authentication failed. Session may have expired.")
            throw AzureAPIError.authenticationFailed
        case 403:
            print("❌ Access forbidden. Email may not be whitelisted.")
            throw AzureAPIError.authenticationFailed
        case 429:
            print("❌ Rate limit exceeded")
            throw AzureAPIError.quotaExceeded
        case 400:
            if let errorStr = String(data: data, encoding: .utf8) {
                print("❌ Bad request: \(errorStr)")
            }
            throw AzureAPIError.invalidResponse
        case 500...599:
            print("❌ Server error: \(httpResponse.statusCode)")
            throw AzureAPIError.invalidResponse
        default:
            print("❌ Unexpected status code: \(httpResponse.statusCode)")
            if let errorStr = String(data: data, encoding: .utf8) {
                print("Response: \(errorStr)")
            }
            throw AzureAPIError.invalidResponse
        }
    }

    /// Calculates a pacing score based on words per minute
    /// - Parameter wpm: Words per minute
    /// - Returns: Score from 0-100 (deterministic - same WPM always returns same score)
    func calculatePacingScore(wpm: Int) -> Int {
        // Deterministic scoring with linear interpolation
        switch wpm {
        case 130...150:
            // Ideal pace: Map 130-150 WPM to 90-100 score linearly
            let normalized = Double(wpm - 130) / 20.0
            return 90 + Int(normalized * 10)

        case 120..<130:
            // Good pace (lower end): Map 120-129 WPM to 85-89 score
            let normalized = Double(wpm - 120) / 10.0
            return 85 + Int(normalized * 4)

        case 150...160:
            // Good pace (upper end): Map 150-160 WPM to 85-89 score
            let normalized = Double(160 - wpm) / 10.0
            return 85 + Int(normalized * 4)

        case 100..<120:
            // Acceptable pace (lower end): Map 100-119 WPM to 75-84 score
            let normalized = Double(wpm - 100) / 20.0
            return 75 + Int(normalized * 9)

        case 160...180:
            // Acceptable pace (upper end): Map 160-180 WPM to 75-84 score
            let normalized = Double(180 - wpm) / 20.0
            return 75 + Int(normalized * 9)

        case 80..<100:
            // Needs improvement (lower end): Map 80-99 WPM to 65-74 score
            let normalized = Double(wpm - 80) / 20.0
            return 65 + Int(normalized * 9)

        case 180...200:
            // Needs improvement (upper end): Map 180-200 WPM to 65-74 score
            let normalized = Double(200 - wpm) / 20.0
            return 65 + Int(normalized * 9)

        default:
            // Poor pace (too slow or too fast)
            if wpm < 80 {
                // Very slow: map 0-79 to 50-64
                let normalized = min(1.0, Double(wpm) / 80.0)
                return 50 + Int(normalized * 14)
            } else {
                // Very fast: >200 WPM gets 50-64 based on how extreme
                let excess = wpm - 200
                let penalty = min(14, excess / 5)  // -1 point per 5 WPM over 200
                return max(50, 64 - penalty)
            }
        }
    }

    // MARK: - Gesture Feedback Generation

    /// Generates personalized gesture feedback using the backend proxy
    /// - Parameters:
    ///   - gestureMetrics: Gesture analysis metrics from Vision Framework
    ///   - transcription: The speech transcription for context
    /// - Returns: Gesture-specific analysis with feedback
    func generateGestureFeedback(
        gestureMetrics: GestureMetrics,
        transcription: String
    ) async throws -> GestureAnalysisResponse {
        let token = try getAuthToken()

        // Build request body matching backend GestureAnalysisRequest
        let requestBody: [String: Any] = [
            "transcription": transcription,
            "smileFrequency": gestureMetrics.facialMetrics.smileFrequency,
            "expressionVariety": gestureMetrics.facialMetrics.expressionVariety,
            "engagementLevel": gestureMetrics.facialMetrics.averageEngagement,
            "confidenceScore": gestureMetrics.postureMetrics.averageConfidence,
            "movementConsistency": gestureMetrics.postureMetrics.movementConsistency,
            "stabilityScore": gestureMetrics.postureMetrics.stabilityScore,
            "cameraFocusPercentage": gestureMetrics.eyeContactMetrics?.cameraFocusPercentage ?? 0,
            "readingNotesPercentage": gestureMetrics.eyeContactMetrics?.readingNotesPercentage ?? 0,
            "gazeStabilityScore": gestureMetrics.eyeContactMetrics?.gazeStability ?? 0
        ]

        let requestData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: analyzeGestureURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 60

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("💬 Gesture Feedback Response Status: \(statusCode)")

        do {
            try validateResponse(response, data: data)

            let analysis = try JSONDecoder().decode(GestureAnalysisResponse.self, from: data)
            return analysis

        } catch {
            print("❌ Gesture feedback error: \(error)")
            print("⚠️ Gesture feedback generation failed, using template")
            // Fallback to template feedback
            return generateTemplateGestureFeedback(for: gestureMetrics)
        }
    }

    /// Generates template gesture feedback when API fails
    private func generateTemplateGestureFeedback(for metrics: GestureMetrics) -> GestureAnalysisResponse {
        let score = metrics.overallScore
        let facialScore = metrics.facialScore
        let postureScore = metrics.postureScore
        let eyeContactScore = metrics.eyeContactScore

        let hasFacialData = facialScore > 0
        let hasPostureData = postureScore > 0
        let hasEyeContactData = eyeContactScore != nil && eyeContactScore! > 0

        var feedback = ""
        var strength = ""
        var improvement = ""

        // Generate feedback based on what was detected and scores
        if hasFacialData && hasPostureData && hasEyeContactData {
            if score >= 85 {
                feedback = "Excellent body language! Your facial expressions, posture, and eye contact convey confidence and engagement. Keep maintaining this strong non-verbal communication."
            } else if score >= 70 {
                feedback = "Good body language overall. Your facial expressions, posture, and eye contact show engagement, but there's room for improvement to enhance your presence."
            } else {
                feedback = "Your body language needs attention. Focus on maintaining better posture, more expressive facial engagement, and consistent eye contact to connect with your audience."
            }
        } else if hasFacialData && hasEyeContactData {
            if score >= 85 {
                feedback = "Excellent facial expressions and eye contact! You show strong engagement and consistent gaze. Your face conveys confidence and connection with the audience."
            } else if score >= 70 {
                feedback = "Good facial expressions and eye contact. You show engagement, but there's room to enhance your expressiveness and gaze consistency."
            } else {
                feedback = "Your facial expressions and eye contact need work. Try to be more expressive and maintain better gaze stability with your audience."
            }
        } else if hasFacialData && hasPostureData {
            if score >= 85 {
                feedback = "Excellent body language! Your facial expressions and posture convey confidence and engagement. Keep maintaining this strong non-verbal communication."
            } else if score >= 70 {
                feedback = "Good body language overall. Your facial expressions and posture show engagement, but there's room for improvement to enhance your presence."
            } else {
                feedback = "Your body language needs attention. Focus on maintaining better posture and more expressive facial engagement to connect with your audience."
            }
        } else if hasFacialData {
            // Facial only
            if score >= 85 {
                feedback = "Excellent facial expressions! You show strong engagement and expressiveness. Your face conveys confidence and connection with the audience."
            } else if score >= 70 {
                feedback = "Good facial expressions overall. You show engagement, but there's room to be more expressive to enhance your presence."
            } else {
                feedback = "Your facial expressions need more variety. Try to be more expressive and maintain better engagement with your audience."
            }
        } else {
            // Posture only
            if score >= 85 {
                feedback = "Excellent posture! You maintain confident body positioning with natural movement. Your presence conveys professionalism."
            } else if score >= 70 {
                feedback = "Good posture overall. Your body positioning is solid, but there's room to enhance your physical presence."
            } else {
                feedback = "Your posture needs attention. Focus on standing upright with better body positioning to convey more confidence."
            }
        }

        // Determine strength based on what was detected (prioritize highest scoring metric)
        let scores = [
            (hasFacialData, facialScore, "facial"),
            (hasPostureData, postureScore, "posture"),
            (hasEyeContactData, eyeContactScore ?? 0, "eyeContact")
        ].filter { $0.0 }.sorted { $0.1 > $1.1 }

        if let topMetric = scores.first {
            switch topMetric.2 {
            case "facial":
                if metrics.facialMetrics.smileFrequency > 0.3 {
                    strength = "Your facial expressions show good engagement with frequent smiling"
                } else {
                    strength = "Your facial expressions demonstrate natural variety"
                }
            case "posture":
                if metrics.postureMetrics.averageConfidence > 0.7 {
                    strength = "Your upright posture conveys confidence and professionalism"
                } else {
                    strength = "Your body movement appears natural and consistent"
                }
            case "eyeContact":
                if let eyeContact = metrics.eyeContactMetrics, eyeContact.cameraFocusPercentage > 0.6 {
                    strength = "Your consistent eye contact shows strong engagement with the audience"
                } else {
                    strength = "Your gaze direction demonstrates attentiveness"
                }
            default:
                strength = "You maintained presence during the presentation"
            }
        } else {
            strength = "You maintained presence during the presentation"
        }

        // Determine improvement based on what was detected (prioritize lowest scoring metric)
        if let worstMetric = scores.last {
            switch worstMetric.2 {
            case "facial":
                if metrics.facialMetrics.smileFrequency < 0.2 {
                    improvement = "Try smiling more to appear more approachable and engaged"
                } else {
                    improvement = "Work on varying your facial expressions to emphasize key points"
                }
            case "posture":
                if metrics.postureMetrics.averageConfidence < 0.6 {
                    improvement = "Focus on standing up straight with shoulders back for better presence"
                } else {
                    improvement = "Try to find a balance between stillness and natural movement"
                }
            case "eyeContact":
                if let eyeContact = metrics.eyeContactMetrics, eyeContact.cameraFocusPercentage < 0.5 {
                    improvement = "Try to look at the camera more frequently to connect with your audience"
                } else {
                    improvement = "Work on maintaining more stable gaze direction to appear more focused"
                }
            default:
                improvement = "Ensure your face and body are visible in frame for complete feedback"
            }
        } else {
            improvement = "Ensure your face and body are visible in frame for complete feedback"
        }

        return GestureAnalysisResponse(
            gestureFeedback: feedback,
            gestureStrength: strength,
            gestureImprovement: improvement,
            isTemplateFallback: true  // Indicates this is template-based, not AI-generated
        )
    }

    // MARK: - Vision API (Key Frame Annotation Generation)

    /// Generates contextual key frame annotation using the backend proxy
    /// - Parameters:
    ///   - imageData: JPEG image data of the key frame
    ///   - type: Type of key frame (best/improve)
    ///   - transcriptionExcerpt: Portion of transcription around this timestamp (~500 chars)
    ///   - timestamp: Timestamp of the frame in seconds
    /// - Returns: AI-generated annotation text
    func generateKeyFrameAnnotation(
        imageData: Data,
        type: KeyFrameType,
        transcriptionExcerpt: String,
        timestamp: Double
    ) async throws -> String {
        print("📸 [VisionAPI] Generating annotation for \(type.rawValue) frame at \(String(format: "%.1f", timestamp))s")

        let token = try getAuthToken()

        // Convert image to base64
        let base64Image = imageData.base64EncodedString()

        // Build request body matching backend KeyFrameAnnotationRequest
        let requestBody: [String: Any] = [
            "imageBase64": base64Image,
            "frameType": type.rawValue,
            "transcriptionExcerpt": transcriptionExcerpt,
            "timestamp": timestamp
        ]

        let requestData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: annotateFrameURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 30

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("📸 [VisionAPI] Response status: \(statusCode)")

        try validateResponse(response, data: data)

        // Parse response
        struct AnnotationResponse: Codable {
            let annotation: String
        }

        let annotationResponse = try JSONDecoder().decode(AnnotationResponse.self, from: data)
        let annotation = annotationResponse.annotation

        print("📸 [VisionAPI] Generated annotation: \(annotation)")
        return annotation
    }
}
