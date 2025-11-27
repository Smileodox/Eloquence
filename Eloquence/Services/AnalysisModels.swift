//
//  AnalysisModels.swift
//  Eloquence
//
//  Data models for Azure OpenAI API integration
//

import Foundation

// MARK: - Whisper API Models

struct WhisperTranscription: Codable {
    let text: String
    let duration: Double?
    let language: String?
}

// MARK: - Speech Metrics (Local Analysis)

struct SpeechMetrics {
    let transcription: String
    let wordCount: Int
    let duration: Double
    let wordsPerMinute: Int
    let pauseCount: Int
    let sentenceCount: Int

    var averageSentenceLength: Double {
        guard sentenceCount > 0 else { return 0 }
        return Double(wordCount) / Double(sentenceCount)
    }
}

// MARK: - GPT API Models

struct GPTChatRequest: Codable {
    let messages: [GPTMessage]
    let maxTokens: Int
    let temperature: Double
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case messages
        case maxTokens = "max_completion_tokens"
        case temperature
        case responseFormat = "response_format"
    }

    struct ResponseFormat: Codable {
        let type: String
    }
}

struct GPTMessage: Codable {
    let role: String
    let content: String
}

struct GPTChatResponse: Codable {
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable {
        let message: GPTMessage
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct GPTAnalysisResponse: Codable {
    let toneScore: Int
    let confidenceScore: Int
    let enthusiasmScore: Int
    let clarityScore: Int
    let feedback: String
    let keyStrengths: [String]
    let areasToImprove: [String]

    var averageToneScore: Int {
        return (toneScore + confidenceScore + clarityScore) / 3
    }
}

// MARK: - Error Models

enum AzureAPIError: Error {
    case invalidResponse
    case networkError(Error)
    case authenticationFailed
    case quotaExceeded
    case invalidAudioFormat
    case parseError
    case configurationError
    case transcriptionFailed
    case emptyTranscription

    var userMessage: String {
        switch self {
        case .authenticationFailed:
            return "API authentication failed. Please check your credentials in Config.plist."
        case .quotaExceeded:
            return "API quota exceeded. Please try again later or check your Azure subscription."
        case .invalidAudioFormat:
            return "Audio format not supported. Please record a new video."
        case .networkError:
            return "Network error. Please check your internet connection."
        case .parseError:
            return "Failed to parse API response. Please try again."
        case .configurationError:
            return "Configuration error. Please check your Config.plist settings."
        case .transcriptionFailed:
            return "Failed to transcribe audio. Please try recording again with clearer audio."
        case .emptyTranscription:
            return "No speech detected in the recording. Please try again and speak clearly."
        case .invalidResponse:
            return "Invalid API response. Please try again."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .quotaExceeded, .invalidResponse, .transcriptionFailed:
            return true
        default:
            return false
        }
    }
}

enum AudioExtractionError: Error {
    case cannotCreateExportSession
    case exportFailed(Error?)
    case fileNotFound
    case invalidFormat
    case noAudioTrack

    var userMessage: String {
        switch self {
        case .cannotCreateExportSession:
            return "Failed to process video. Please try recording again."
        case .exportFailed:
            return "Failed to extract audio from video. Please try again."
        case .fileNotFound:
            return "Video file not found. Please record a new video."
        case .invalidFormat:
            return "Invalid video format. Please try recording again."
        case .noAudioTrack:
            return "No audio found in video. Please ensure microphone access is granted."
        }
    }
}
