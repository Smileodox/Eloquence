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

        // Build system prompt
        let systemPrompt = """
        You are an expert presentation coach analyzing a practice presentation. Based on the transcription and metrics provided, evaluate the speaker's performance and provide constructive coaching feedback.

        Scoring Guidelines:
        - Tone Score (0-100): Overall vocal quality, appropriateness for context
        - Confidence Score (0-100): Assertiveness, clarity, conviction in speech
        - Enthusiasm Score (0-100): Energy, passion, engagement with topic
        - Clarity Score (0-100): Articulation, organization, ease of understanding

        Pacing Guidelines:
        - Ideal: 130-150 words per minute (clear, comfortable pace)
        - Acceptable: 100-130 or 150-180 WPM (slightly slow or fast)
        - Poor: Below 100 or above 180 WPM (too slow or rushed)

        Respond ONLY with valid JSON matching this exact structure (no additional text):
        {
          "toneScore": <number 0-100>,
          "confidenceScore": <number 0-100>,
          "enthusiasmScore": <number 0-100>,
          "clarityScore": <number 0-100>,
          "feedback": "<2-3 sentences of personalized coaching feedback>",
          "keyStrengths": ["<strength 1>", "<strength 2>"],
          "areasToImprove": ["<area 1>", "<area 2>"]
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
            maxTokens: 800,
            temperature: 1.0,
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
    /// - Returns: Score from 0-100
    func calculatePacingScore(wpm: Int) -> Int {
        switch wpm {
        case 130...150:
            // Ideal pace
            return Int.random(in: 90...100)
        case 120..<130, 150...160:
            // Good pace
            return Int.random(in: 80...89)
        case 100..<120, 160...180:
            // Acceptable pace
            return Int.random(in: 70...79)
        case 80..<100, 180...200:
            // Needs improvement
            return Int.random(in: 60...69)
        default:
            // Poor pace (too slow or too fast)
            return Int.random(in: 50...59)
        }
    }
}
