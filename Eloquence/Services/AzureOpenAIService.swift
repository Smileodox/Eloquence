//
//  AzureOpenAIService.swift
//  Eloquence
//
//  Service for Azure OpenAI API communication (Whisper + GPT)
//

import Foundation

class AzureOpenAIService: ObservableObject {

    private let config = ConfigurationManager.shared

    // MARK: - Whisper API (Speech-to-Text)

    /// Transcribes audio using Azure OpenAI Whisper API
    /// - Parameter audioURL: URL of the audio file (.m4a)
    /// - Returns: Transcription result with text and metadata
    func transcribeAudio(_ audioURL: URL) async throws -> WhisperTranscription {
        // Build API endpoint using ConfigurationManager
        let urlString = config.whisperURL()
        print("🔊 Whisper API URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            throw AzureAPIError.configurationError
        }

        // Read audio file
        let audioData = try Data(contentsOf: audioURL)
        print("🔊 Audio file size: \(audioData.count) bytes")

        // Create multipart form data
        let boundary = UUID().uuidString
        let body = createMultipartBody(audioData: audioData, boundary: boundary)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.azureAPIKey, forHTTPHeaderField: "api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 60 // 60 seconds timeout for large files

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        print("🔊 Whisper Response Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        print("🔊 Whisper Response: \(String(data: data, encoding: .utf8) ?? "Unable to parse")")

        try validateResponse(response, data: data)

        // Parse response
        let transcription = try JSONDecoder().decode(WhisperTranscription.self, from: data)

        // Validate transcription is not empty
        guard !transcription.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AzureAPIError.emptyTranscription
        }

        return transcription
    }

    /// Creates multipart/form-data body for Whisper API
    private func createMultipartBody(audioData: Data, boundary: String) -> Data {
        var body = Data()

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model field (required by Azure)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
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

    /// Generates personalized feedback using Azure OpenAI GPT-5-mini
    /// - Parameters:
    ///   - transcription: The speech transcription
    ///   - metrics: Speech metrics (WPM, pauses, etc.)
    /// - Returns: Analysis with scores and feedback
    func generateFeedback(transcription: String, metrics: SpeechMetrics) async throws -> GPTAnalysisResponse {
        // Build API endpoint using ConfigurationManager
        let urlString = config.gptURL()
        print("💬 GPT API URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            throw AzureAPIError.configurationError
        }

        // Build enhanced system prompt with examples (QUALITY IMPROVEMENT)
        let systemPrompt = """
        You are an expert presentation coach analyzing a practice presentation. Provide detailed, personalized coaching feedback that references specific moments from the transcription.

        Scoring Guidelines:
        - Tone Score (0-100): Overall vocal quality, appropriateness for context
        - Confidence Score (0-100): Assertiveness, clarity, conviction in speech
        - Enthusiasm Score (0-100): Energy, passion, engagement with topic
        - Clarity Score (0-100): Articulation, organization, ease of understanding

        Pacing Guidelines:
        - Ideal: 130-150 words per minute (clear, comfortable pace)
        - Acceptable: 100-130 or 150-180 WPM (slightly slow or fast)
        - Poor: Below 100 or above 180 WPM (too slow or rushed)

        Feedback Quality Guidelines:
        - Reference specific moments and quotes from the transcription
        - Balance strengths and growth areas with concrete examples
        - Provide actionable advice, not generic observations
        - Match your tone to the presentation's formality and topic
        - Use as much detail as needed to be genuinely helpful (2-8 sentences is fine)

        Example of excellent feedback:
        "Your opening about climate change showed strong conviction, especially when you emphasized the 2050 deadline at the start. Your pace was ideal (145 WPM) - fast enough to show energy but not rushed. The transition where you said 'but here's what we can do' was perfectly timed and confident. Consider varying your vocal tone more when transitioning between hard statistics and human impact stories to create more emotional contrast and keep your audience engaged. Your conclusion would also benefit from a slight pause before the final call-to-action to let the weight settle."

        Respond ONLY with valid JSON matching this exact structure (no additional text):
        {
          "toneScore": <number 0-100>,
          "confidenceScore": <number 0-100>,
          "enthusiasmScore": <number 0-100>,
          "clarityScore": <number 0-100>,
          "feedback": "<detailed, personalized coaching feedback>",
          "keyStrengths": ["<specific strength with example>", "<specific strength with example>"],
          "areasToImprove": ["<specific area with actionable advice>", "<specific area with actionable advice>"]
        }
        """

        // Build user prompt with transcription and metrics
        let userPrompt = """
        Please analyze this presentation:

        TRANSCRIPTION:
        "\(transcription)"

        METRICS:
        - Speaking pace: \(metrics.wordsPerMinute) words per minute
        - Total words: \(metrics.wordCount)
        - Duration: \(String(format: "%.1f", metrics.duration)) seconds
        - Pauses used: \(metrics.pauseCount)
        - Sentences: \(metrics.sentenceCount)
        - Average sentence length: \(String(format: "%.1f", metrics.averageSentenceLength)) words

        Provide your analysis in JSON format as specified.
        """

        // Create chat request
        let chatRequest = GPTChatRequest(
            messages: [
                GPTMessage(role: "system", content: systemPrompt),
                GPTMessage(role: "user", content: userPrompt)
            ],
            maxTokens: 2000,  // Increased from 800 for detailed, quality feedback
            temperature: 1.0,  // gpt-5-mini only supports default temperature
            responseFormat: GPTChatRequest.ResponseFormat(type: "json_object")
        )

        // Encode request
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(chatRequest)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.azureAPIKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 60

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        print("💬 GPT Response Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        print("💬 GPT Response: \(String(data: data, encoding: .utf8) ?? "Unable to parse")")

        try validateResponse(response, data: data)

        // Parse GPT response
        let chatResponse = try JSONDecoder().decode(GPTChatResponse.self, from: data)
        guard let messageContent = chatResponse.choices.first?.message.content else {
            throw AzureAPIError.parseError
        }

        // Parse analysis JSON from message content
        guard let analysisData = messageContent.data(using: .utf8) else {
            throw AzureAPIError.parseError
        }

        let decoder = JSONDecoder()
        let analysis = try decoder.decode(GPTAnalysisResponse.self, from: analysisData)

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
            print("❌ Authentication failed. Check your API key in Config.plist")
            throw AzureAPIError.authenticationFailed
        case 429:
            print("❌ Rate limit exceeded")
            throw AzureAPIError.quotaExceeded
        case 400:
            // Parse error details if available
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

    /// Generates personalized gesture feedback using Azure OpenAI GPT-5-mini
    /// - Parameters:
    ///   - gestureMetrics: Gesture analysis metrics from Vision Framework
    ///   - transcription: The speech transcription for context
    /// - Returns: Gesture-specific analysis with feedback
    func generateGestureFeedback(
        gestureMetrics: GestureMetrics,
        transcription: String
    ) async throws -> GestureAnalysisResponse {
        // Build API endpoint
        let urlString = config.gptURL()
        guard let url = URL(string: urlString) else {
            throw AzureAPIError.configurationError
        }

        // Determine what was detected
        let hasFacialData = gestureMetrics.facialScore > 0
        let hasPostureData = gestureMetrics.postureScore > 0
        let hasEyeContactData = gestureMetrics.eyeContactScore != nil && gestureMetrics.eyeContactScore! > 0

        // Build dynamic system prompt based on what was detected
        var focusAreas: [String] = []
        if hasFacialData { focusAreas.append("facial expressions (smiling, engagement, expressiveness)") }
        if hasPostureData { focusAreas.append("body posture (confidence, natural movement, stability)") }
        if hasEyeContactData { focusAreas.append("eye contact (camera focus, gaze stability)") }

        let systemPrompt = """
        You are an expert presentation coach analyzing body language and non-verbal communication. Based on the gesture metrics and presentation content provided, evaluate the speaker's \(focusAreas.joined(separator: ", ")) and provide detailed, contextual coaching feedback.

        IMPORTANT: Only provide feedback about the metrics that were detected. Do not mention facial expressions if no facial data is available, do not mention posture if no posture data is available, and do not mention eye contact if no eye contact data is available.

        Feedback Quality Guidelines:
        - Connect body language observations to specific moments in the presentation
        - Reference the presentation content to make feedback contextual
        - Provide actionable advice with concrete examples
        - Match your tone to the presentation's formality and topic
        - Be specific and helpful, not generic (use as much detail as needed)

        Respond ONLY with valid JSON matching this exact structure (no additional text):
        {
          "gestureFeedback": "<detailed, contextual coaching feedback about detected body language>",
          "gestureStrength": "<specific strength with example from the presentation>",
          "gestureImprovement": "<specific improvement area with actionable advice>"
        }
        """

        // Build dynamic user prompt with only the detected metrics
        var metricsSection = ""

        if hasFacialData {
            let facial = gestureMetrics.facialMetrics
            metricsSection += """
            FACIAL EXPRESSION METRICS:
            - Smile frequency: \(String(format: "%.1f%%", facial.smileFrequency * 100))
            - Expression variety: \(String(format: "%.1f%%", facial.expressionVariety * 100))
            - Engagement level: \(String(format: "%.1f%%", facial.averageEngagement * 100))
            - Facial score: \(gestureMetrics.facialScore)/100

            """
        }

        if hasPostureData {
            let posture = gestureMetrics.postureMetrics
            metricsSection += """
            BODY POSTURE METRICS:
            - Posture confidence: \(String(format: "%.1f%%", posture.averageConfidence * 100))
            - Movement consistency: \(String(format: "%.1f%%", posture.movementConsistency * 100))
            - Stability: \(String(format: "%.1f%%", posture.stabilityScore * 100))
            - Posture score: \(gestureMetrics.postureScore)/100

            """
        }

        if hasEyeContactData, let eyeContact = gestureMetrics.eyeContactMetrics, let eyeContactScore = gestureMetrics.eyeContactScore {
            metricsSection += """
            EYE CONTACT METRICS:
            - Camera focus: \(String(format: "%.1f%%", eyeContact.cameraFocusPercentage * 100))
            - Time reading notes (looking down): \(String(format: "%.1f%%", eyeContact.readingNotesPercentage * 100))
            - Gaze stability: \(String(format: "%.1f%%", eyeContact.gazeStability * 100))
            - Eye contact score: \(eyeContactScore)/100

            """
            
            if eyeContact.readingNotesPercentage > 0.15 {
                metricsSection += "NOTE: The speaker frequently looked down, likely reading notes. Address this in the feedback.\n"
            }
        }

        // Build detection note based on what was detected
        var detectionNote = ""
        if hasFacialData && hasPostureData && hasEyeContactData {
            detectionNote = ""  // All metrics detected, no note needed
        } else if hasFacialData && hasPostureData {
            detectionNote = "\nNOTE: Eye contact was not measured in this session."
        } else if hasFacialData && hasEyeContactData {
            detectionNote = "\nNOTE: Body posture was not detected (body not visible in frame)."
        } else if hasFacialData {
            detectionNote = "\nNOTE: Only facial expressions were detected (body not visible, eye contact not measured)."
        } else if hasPostureData {
            detectionNote = "\nNOTE: Only body posture was detected (face not visible in frame)."
        }

        let userPrompt = """
        Please analyze this speaker's body language:

        \(metricsSection)OVERALL GESTURE SCORE: \(gestureMetrics.overallScore)/100
        \(detectionNote)

        FULL PRESENTATION TRANSCRIPTION:
        "\(transcription)"

        Provide your gesture analysis in JSON format as specified. Reference specific moments from the transcription to make your feedback contextual and helpful. Only comment on the metrics that were actually detected.
        """

        // Create chat request
        let chatRequest = GPTChatRequest(
            messages: [
                GPTMessage(role: "system", content: systemPrompt),
                GPTMessage(role: "user", content: userPrompt)
            ],
            maxTokens: 2000,  // Increased from 1000 for detailed, contextual feedback
            temperature: 1.0,  // gpt-5-mini only supports default temperature
            responseFormat: GPTChatRequest.ResponseFormat(type: "json_object")
        )

        // Encode request
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(chatRequest)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.azureAPIKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 60

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("💬 Gesture Feedback Response Status: \(statusCode)")
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("💬 Gesture Feedback Raw Response:")
            print(rawResponse)
        } else {
            print("💬 Gesture Feedback Raw Response: Unable to parse")
        }

        do {
            try validateResponse(response, data: data)

            // Parse GPT response
            let chatResponse = try JSONDecoder().decode(GPTChatResponse.self, from: data)
            guard let messageContent = chatResponse.choices.first?.message.content else {
                throw AzureAPIError.parseError
            }

            print("💬 Message content from GPT:")
            print(messageContent)

            // Parse gesture analysis JSON from message content
            guard let analysisData = messageContent.data(using: .utf8) else {
                throw AzureAPIError.parseError
            }

            print("🔍 JSON to decode (gesture):")
            if let jsonString = String(data: analysisData, encoding: .utf8) {
                print(jsonString)
            }

            let decoder = JSONDecoder()

            // Decode the GPT response which won't have isTemplateFallback field
            // We'll use a temporary struct for decoding then create the proper response
            struct GPTGestureResponse: Codable {
                let gestureFeedback: String
                let gestureStrength: String
                let gestureImprovement: String
            }

            let gptResponse = try decoder.decode(GPTGestureResponse.self, from: analysisData)

            // Create the final response with isTemplateFallback set to false (AI-generated)
            let analysis = GestureAnalysisResponse(
                gestureFeedback: gptResponse.gestureFeedback,
                gestureStrength: gptResponse.gestureStrength,
                gestureImprovement: gptResponse.gestureImprovement,
                isTemplateFallback: false  // This is AI-generated feedback from GPT
            )

            return analysis

        } catch {
            print("❌ Gesture feedback decode error: \(error)")

            // Log detailed decoding error information
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("   Data corrupted - Context: \(context)")
                    print("   Coding path: \(context.codingPath)")
                    print("   Debug description: \(context.debugDescription)")
                    if let underlyingError = context.underlyingError {
                        print("   Underlying error: \(underlyingError)")
                    }
                case .keyNotFound(let key, let context):
                    print("   Missing key: \(key)")
                    print("   Context: \(context)")
                    print("   Coding path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: expected \(type)")
                    print("   Context: \(context)")
                    print("   Coding path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type)")
                    print("   Context: \(context)")
                    print("   Coding path: \(context.codingPath)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }

            print("⚠️ Gesture feedback generation failed, using template")
            // Fallback to template feedback
            return generateTemplateGestureFeedback(for: gestureMetrics)
        }
    }

    /// Generates template gesture feedback when GPT API fails
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

    /// Generates contextual key frame annotation using GPT-4o vision API
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

        // Build API endpoint (using GPT deployment which supports vision)
        let urlString = config.gptURL()
        guard let url = URL(string: urlString) else {
            throw AzureAPIError.configurationError
        }

        // Convert image to base64
        let base64Image = imageData.base64EncodedString()

        // Build context-aware system prompt
        let systemPrompt = """
        You are an expert presentation coach analyzing a specific moment from a presentation. Based on the frame image and transcription context, provide one concise, specific coaching comment (20-40 words).

        Guidelines:
        - Adapt tone to presentation formality (academic = professional, casual = friendly)
        - Reference specific visual details (posture, expression, gaze)
        - Connect to transcription context when relevant
        - Be specific and actionable, not generic
        - For "best" frames: highlight what's working well
        - For "improve" frames: suggest specific improvements
        """

        // Build type-specific guidance
        let typeGuidance: String
        switch type {
        case .bestFacial:
            typeGuidance = "This is a STRENGTH moment for facial expression. Highlight what's working well (eye contact, smile, engagement, etc.)."
        case .bestOverall:
            typeGuidance = "This is a STRENGTH moment overall. Highlight the combination of good expression, posture, and engagement."
        case .improveFacial:
            typeGuidance = "This is an IMPROVEMENT AREA for facial expression. Suggest specific ways to improve engagement, eye contact, or expressiveness."
        case .improvePosture:
            typeGuidance = "This is an IMPROVEMENT AREA for posture. Suggest specific ways to improve body position, confidence, or stability."
        case .improveEyeContact:
            typeGuidance = "This is an IMPROVEMENT AREA for eye contact. Suggest ways to improve camera focus or gaze consistency."
        case .averageMoment:
            typeGuidance = "This is a REPRESENTATIVE moment. Provide neutral, balanced observation."
        }

        let userPrompt = """
        Frame type: \(type.rawValue)
        Timestamp: \(String(format: "%.1f", timestamp))s

        \(typeGuidance)

        Transcription context:
        "\(transcriptionExcerpt)"

        Analyze this presentation frame and provide ONE concise coaching comment (20-40 words). Return ONLY the annotation text, no JSON, no additional formatting.
        """

        // Create vision request with image
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": userPrompt
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]

        let requestBody: [String: Any] = [
            "messages": messages,
            "max_completion_tokens": 1500,  // Increased to allow for reasoning + output
            "temperature": 1.0
        ]

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.azureAPIKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("📸 [VisionAPI] Response status: \(statusCode)")

        try validateResponse(response, data: data)

        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📸 [VisionAPI] Raw response: \(responseString)")
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let annotation = message["content"] as? String else {
            print("❌ [VisionAPI] Failed to parse response - missing expected fields")
            throw AzureAPIError.parseError
        }

        print("📸 [VisionAPI] Raw annotation before cleaning: '\(annotation)'")

        // Clean up annotation (remove quotes, extra whitespace)
        let cleanedAnnotation = annotation
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")

        print("📸 [VisionAPI] Generated annotation: \(cleanedAnnotation)")
        return cleanedAnnotation
    }
}
