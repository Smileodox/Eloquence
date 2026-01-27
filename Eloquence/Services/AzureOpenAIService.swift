//
//  AzureOpenAIService.swift
//  Eloquence
//

import Foundation

class AzureOpenAIService {

    private let config = ConfigurationManager.shared

    // MARK: - Endpoints

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

    // MARK: - Auth

    private func getAuthToken() throws -> String {
        guard let session = SessionStorageService.shared.loadSession() else {
            throw AzureAPIError.authenticationFailed
        }
        return session.accessToken
    }

    // MARK: - Transcription (Whisper)

    func transcribeAudio(_ audioURL: URL) async throws -> WhisperTranscription {
        let token = try getAuthToken()
        let audioData = try Data(contentsOf: audioURL)
        print("[Transcribe] Audio size: \(audioData.count) bytes")

        let boundary = UUID().uuidString
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: transcribeURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        print("[Transcribe] Response: \((response as? HTTPURLResponse)?.statusCode ?? -1)")

        try validateResponse(response, data: data)

        let transcription = try JSONDecoder().decode(WhisperTranscription.self, from: data)
        guard !transcription.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AzureAPIError.emptyTranscription
        }

        return transcription
    }

    // MARK: - Speech Metrics

    func analyzeSpeechMetrics(transcription: String, audioDuration: Double) -> SpeechMetrics {
        let cleanedText = transcription.trimmingCharacters(in: .whitespacesAndNewlines)

        let words = cleanedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let wordCount = words.count

        let minutes = audioDuration / 60.0
        let wordsPerMinute = minutes > 0 ? Int(Double(wordCount) / minutes) : 0

        let pausePunctuation: Set<Character> = [".", "!", "?", ",", ";", ":", "-"]
        let pauseCount = cleanedText.filter { pausePunctuation.contains($0) }.count

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

    // MARK: - Speech Feedback (GPT)

    func generateFeedback(transcription: String, metrics: SpeechMetrics) async throws -> GPTAnalysisResponse {
        let token = try getAuthToken()

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

        var request = URLRequest(url: analyzeSpeechURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        print("[Speech] Analysis response: \((response as? HTTPURLResponse)?.statusCode ?? -1)")

        try validateResponse(response, data: data)

        return try JSONDecoder().decode(GPTAnalysisResponse.self, from: data)
    }

    // MARK: - Response Validation

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            print("[API] Auth failed - session may have expired")
            throw AzureAPIError.authenticationFailed
        case 403:
            print("[API] Access forbidden - email may not be whitelisted")
            throw AzureAPIError.authenticationFailed
        case 429:
            print("[API] Rate limit exceeded")
            throw AzureAPIError.quotaExceeded
        case 400:
            if let errorStr = String(data: data, encoding: .utf8) {
                print("[API] Bad request: \(errorStr)")
            }
            throw AzureAPIError.invalidResponse
        case 500...599:
            print("[API] Server error: \(httpResponse.statusCode)")
            throw AzureAPIError.invalidResponse
        default:
            print("[API] Unexpected status: \(httpResponse.statusCode)")
            if let errorStr = String(data: data, encoding: .utf8) {
                print("[API] Response: \(errorStr)")
            }
            throw AzureAPIError.invalidResponse
        }
    }

    // MARK: - Pacing Score

    // Maps WPM to a 0-100 score with linear interpolation.
    // Ideal pace is 130-150 WPM (90-100 score).
    func calculatePacingScore(wpm: Int) -> Int {
        switch wpm {
        case 130...150:
            let normalized = Double(wpm - 130) / 20.0
            return 90 + Int(normalized * 10)

        case 120..<130:
            let normalized = Double(wpm - 120) / 10.0
            return 85 + Int(normalized * 4)

        case 150...160:
            let normalized = Double(160 - wpm) / 10.0
            return 85 + Int(normalized * 4)

        case 100..<120:
            let normalized = Double(wpm - 100) / 20.0
            return 75 + Int(normalized * 9)

        case 160...180:
            let normalized = Double(180 - wpm) / 20.0
            return 75 + Int(normalized * 9)

        case 80..<100:
            let normalized = Double(wpm - 80) / 20.0
            return 65 + Int(normalized * 9)

        case 180...200:
            let normalized = Double(200 - wpm) / 20.0
            return 65 + Int(normalized * 9)

        default:
            if wpm < 80 {
                let normalized = min(1.0, Double(wpm) / 80.0)
                return 50 + Int(normalized * 14)
            } else {
                let excess = wpm - 200
                let penalty = min(14, excess / 5)
                return max(50, 64 - penalty)
            }
        }
    }

    // MARK: - Gesture Feedback (GPT)

    func generateGestureFeedback(
        gestureMetrics: GestureMetrics,
        transcription: String
    ) async throws -> GestureAnalysisResponse {
        let token = try getAuthToken()

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

        var request = URLRequest(url: analyzeGestureURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[Gesture] Feedback response: \(statusCode)")

        do {
            try validateResponse(response, data: data)
            return try JSONDecoder().decode(GestureAnalysisResponse.self, from: data)
        } catch {
            print("[Gesture] Feedback failed: \(error), using template")
            return generateTemplateGestureFeedback(for: gestureMetrics)
        }
    }

    // Template fallback when API fails
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

        // Build feedback based on available data
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
            if score >= 85 {
                feedback = "Excellent facial expressions! You show strong engagement and expressiveness. Your face conveys confidence and connection with the audience."
            } else if score >= 70 {
                feedback = "Good facial expressions overall. You show engagement, but there's room to be more expressive to enhance your presence."
            } else {
                feedback = "Your facial expressions need more variety. Try to be more expressive and maintain better engagement with your audience."
            }
        } else {
            if score >= 85 {
                feedback = "Excellent posture! You maintain confident body positioning with natural movement. Your presence conveys professionalism."
            } else if score >= 70 {
                feedback = "Good posture overall. Your body positioning is solid, but there's room to enhance your physical presence."
            } else {
                feedback = "Your posture needs attention. Focus on standing upright with better body positioning to convey more confidence."
            }
        }

        // Find strength (highest scoring metric)
        let scores = [
            (hasFacialData, facialScore, "facial"),
            (hasPostureData, postureScore, "posture"),
            (hasEyeContactData, eyeContactScore ?? 0, "eyeContact")
        ].filter { $0.0 }.sorted { $0.1 > $1.1 }

        if let topMetric = scores.first {
            switch topMetric.2 {
            case "facial":
                strength = metrics.facialMetrics.smileFrequency > 0.3
                    ? "Your facial expressions show good engagement with frequent smiling"
                    : "Your facial expressions demonstrate natural variety"
            case "posture":
                strength = metrics.postureMetrics.averageConfidence > 0.7
                    ? "Your upright posture conveys confidence and professionalism"
                    : "Your body movement appears natural and consistent"
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

        // Find area to improve (lowest scoring metric)
        if let worstMetric = scores.last {
            switch worstMetric.2 {
            case "facial":
                improvement = metrics.facialMetrics.smileFrequency < 0.2
                    ? "Try smiling more to appear more approachable and engaged"
                    : "Work on varying your facial expressions to emphasize key points"
            case "posture":
                improvement = metrics.postureMetrics.averageConfidence < 0.6
                    ? "Focus on standing up straight with shoulders back for better presence"
                    : "Try to find a balance between stillness and natural movement"
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
            isTemplateFallback: true
        )
    }

    // MARK: - Key Frame Annotation (Vision API)

    func generateKeyFrameAnnotation(
        imageData: Data,
        type: KeyFrameType,
        transcriptionExcerpt: String,
        timestamp: Double
    ) async throws -> String {
        print("[Annotation] Generating for \(type.rawValue) at \(String(format: "%.1f", timestamp))s")

        let token = try getAuthToken()
        let base64Image = imageData.base64EncodedString()

        let requestBody: [String: Any] = [
            "imageBase64": base64Image,
            "frameType": type.rawValue,
            "transcriptionExcerpt": transcriptionExcerpt,
            "timestamp": timestamp
        ]

        let requestData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: annotateFrameURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[Annotation] Response: \(statusCode)")

        try validateResponse(response, data: data)

        struct AnnotationResponse: Codable {
            let annotation: String
        }

        let annotationResponse = try JSONDecoder().decode(AnnotationResponse.self, from: data)
        print("[Annotation] Generated: \(annotationResponse.annotation)")
        return annotationResponse.annotation
    }
}
