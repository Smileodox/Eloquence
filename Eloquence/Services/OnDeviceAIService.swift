//
//  OnDeviceAIService.swift
//  Eloquence
//
//  On-device AI service using Apple Speech and Foundation Models frameworks.
//  All processing stays on-device — no data leaves the iPhone.
//

import Foundation
import Speech
import FoundationModels

// MARK: - Generable Response Types

@available(iOS 26.0, *)
@Generable
struct OnDeviceSpeechAnalysis {
    @Guide(description: "Tone score: overall vocal quality and appropriateness", .range(0...100))
    var toneScore: Int

    @Guide(description: "Confidence score: assertiveness and conviction", .range(0...100))
    var confidenceScore: Int

    @Guide(description: "Enthusiasm score: energy and engagement", .range(0...100))
    var enthusiasmScore: Int

    @Guide(description: "Clarity score: articulation and organization", .range(0...100))
    var clarityScore: Int

    @Guide(description: "Detailed personalized coaching feedback referencing specific moments from the speech, 2-8 sentences")
    var feedback: String

    @Guide(description: "Two specific strengths with examples from the speech", .count(2))
    var keyStrengths: [String]

    @Guide(description: "Two specific areas to improve with actionable advice", .count(2))
    var areasToImprove: [String]

    @Guide(description: "Specific strength about vocal tone with example")
    var toneStrength: String

    @Guide(description: "Specific actionable improvement for vocal tone")
    var toneImprovement: String

    @Guide(description: "Specific strength about pacing and rhythm")
    var pacingStrength: String

    @Guide(description: "Specific actionable improvement for pacing")
    var pacingImprovement: String
}

@available(iOS 26.0, *)
@Generable
struct OnDeviceGestureAnalysis {
    @Guide(description: "Detailed contextual coaching feedback about body language, 2-3 sentences")
    var gestureFeedback: String

    @Guide(description: "Specific body language strength with example")
    var gestureStrength: String

    @Guide(description: "Specific body language improvement area with actionable advice")
    var gestureImprovement: String
}

// MARK: - On-Device AI Service

@available(iOS 26.0, *)
class OnDeviceAIService {

    // MARK: - Transcription (Speech Framework)

    func transcribeAudio(_ audioURL: URL) async throws -> WhisperTranscription {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw OnDeviceAIError.speechRecognitionUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        let result: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }

        let text = result.bestTranscription.formattedString
        let duration = result.bestTranscription.segments.last.map {
            $0.timestamp + $0.duration
        }

        return WhisperTranscription(text: text, duration: duration, language: nil)
    }

    // MARK: - Speech Metrics (Local — same as AzureOpenAIService)

    func analyzeSpeechMetrics(transcription: String, audioDuration: Double) -> SpeechMetrics {
        let cleanedText = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleanedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
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

    // MARK: - Speech Feedback (Foundation Models)

    func generateFeedback(transcription: String, metrics: SpeechMetrics) async throws -> GPTAnalysisResponse {
        let session = LanguageModelSession {
            """
            You are an expert presentation coach analyzing a practice presentation. Provide detailed, personalized coaching feedback that references specific moments from the transcription.

            Scoring Guidelines:
            - Tone Score (0-100): Overall vocal quality, appropriateness for context
            - Confidence Score (0-100): Assertiveness, clarity, conviction in speech
            - Enthusiasm Score (0-100): Energy, passion, engagement with topic
            - Clarity Score (0-100): Articulation, organization, ease of understanding

            Pacing Guidelines:
            - Ideal: 130-150 words per minute
            - Acceptable: 100-130 or 150-180 WPM
            - Poor: Below 100 or above 180 WPM

            Reference specific moments and quotes from the transcription. Provide actionable advice.
            """
        }

        let prompt = """
        Analyze this presentation:

        TRANSCRIPTION:
        "\(transcription)"

        METRICS:
        - Speaking pace: \(metrics.wordsPerMinute) words per minute
        - Total words: \(metrics.wordCount)
        - Duration: \(String(format: "%.1f", metrics.duration)) seconds
        - Pauses used: \(metrics.pauseCount)
        - Sentences: \(metrics.sentenceCount)
        - Average sentence length: \(String(format: "%.1f", metrics.averageSentenceLength)) words
        """

        let response: LanguageModelSession.Response<OnDeviceSpeechAnalysis>
        do {
            response = try await session.respond(to: prompt, generating: OnDeviceSpeechAnalysis.self)
        } catch let error as LanguageModelSession.GenerationError {
            if case .assetsUnavailable = error {
                throw OnDeviceAIError.modelAssetsUnavailable
            }
            throw error
        }
        let r = response.content

        return GPTAnalysisResponse(
            toneScore: r.toneScore,
            confidenceScore: r.confidenceScore,
            enthusiasmScore: r.enthusiasmScore,
            clarityScore: r.clarityScore,
            feedback: r.feedback,
            keyStrengths: r.keyStrengths,
            areasToImprove: r.areasToImprove,
            toneStrength: r.toneStrength,
            toneImprovement: r.toneImprovement,
            pacingStrength: r.pacingStrength,
            pacingImprovement: r.pacingImprovement
        )
    }

    // MARK: - Gesture Feedback (Foundation Models)

    func generateGestureFeedback(
        gestureMetrics: GestureMetrics,
        transcription: String
    ) async throws -> GestureAnalysisResponse {
        let hasFacial = gestureMetrics.facialMetrics.smileFrequency > 0 ||
            gestureMetrics.facialMetrics.expressionVariety > 0 ||
            gestureMetrics.facialMetrics.averageEngagement > 0
        let hasPosture = gestureMetrics.postureMetrics.averageConfidence > 0 ||
            gestureMetrics.postureMetrics.movementConsistency > 0 ||
            gestureMetrics.postureMetrics.stabilityScore > 0
        let hasEyeContact = (gestureMetrics.eyeContactMetrics?.cameraFocusPercentage ?? 0) > 0 ||
            (gestureMetrics.eyeContactMetrics?.gazeStability ?? 0) > 0

        var focusAreas: [String] = []
        if hasFacial { focusAreas.append("facial expressions") }
        if hasPosture { focusAreas.append("body posture") }
        if hasEyeContact { focusAreas.append("eye contact") }

        var metricsText = ""
        if hasFacial {
            metricsText += """
            FACIAL EXPRESSION METRICS:
            - Smile frequency: \(String(format: "%.1f", gestureMetrics.facialMetrics.smileFrequency * 100))%
            - Expression variety: \(String(format: "%.1f", gestureMetrics.facialMetrics.expressionVariety * 100))%
            - Engagement level: \(String(format: "%.1f", gestureMetrics.facialMetrics.averageEngagement * 100))%

            """
        }
        if hasPosture {
            metricsText += """
            BODY POSTURE METRICS:
            - Posture confidence: \(String(format: "%.1f", gestureMetrics.postureMetrics.averageConfidence * 100))%
            - Movement consistency: \(String(format: "%.1f", gestureMetrics.postureMetrics.movementConsistency * 100))%
            - Stability: \(String(format: "%.1f", gestureMetrics.postureMetrics.stabilityScore * 100))%

            """
        }
        if hasEyeContact {
            let eyeContact = gestureMetrics.eyeContactMetrics!
            metricsText += """
            EYE CONTACT METRICS:
            - Camera focus: \(String(format: "%.1f", eyeContact.cameraFocusPercentage * 100))%
            - Reading notes: \(String(format: "%.1f", eyeContact.readingNotesPercentage * 100))%
            - Gaze stability: \(String(format: "%.1f", eyeContact.gazeStability * 100))%

            """
        }

        let session = LanguageModelSession {
            """
            You are an expert presentation coach analyzing body language. Evaluate the speaker's \(focusAreas.joined(separator: ", ")) and provide detailed coaching feedback. Only comment on metrics that were detected. Connect observations to the presentation content.
            """
        }

        let prompt = """
        Analyze this speaker's body language:

        \(metricsText)
        TRANSCRIPTION:
        "\(transcription)"

        Provide contextual gesture analysis referencing specific moments from the transcription.
        """

        do {
            let response = try await session.respond(to: prompt, generating: OnDeviceGestureAnalysis.self)
            let r = response.content
            return GestureAnalysisResponse(
                gestureFeedback: r.gestureFeedback,
                gestureStrength: r.gestureStrength,
                gestureImprovement: r.gestureImprovement,
                isTemplateFallback: false
            )
        } catch let error as LanguageModelSession.GenerationError {
            if case .assetsUnavailable = error {
                throw OnDeviceAIError.modelAssetsUnavailable
            }
            print("[OnDevice] Gesture feedback failed: \(error), using template")
            return generateTemplateGestureFeedback(for: gestureMetrics)
        } catch {
            print("[OnDevice] Gesture feedback failed: \(error), using template")
            return generateTemplateGestureFeedback(for: gestureMetrics)
        }
    }

    // MARK: - Pacing Score (same as AzureOpenAIService)

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

    // MARK: - Template Fallback for Gestures

    private func generateTemplateGestureFeedback(for metrics: GestureMetrics) -> GestureAnalysisResponse {
        let score = metrics.overallScore
        let feedback: String
        if score >= 85 {
            feedback = "Excellent body language! Your non-verbal communication conveys confidence and engagement."
        } else if score >= 70 {
            feedback = "Good body language overall. There's room for improvement to enhance your presence."
        } else {
            feedback = "Your body language needs attention. Focus on posture, expressions, and eye contact."
        }

        let strength: String
        if metrics.facialMetrics.smileFrequency > 0.3 {
            strength = "Your facial expressions show good engagement with frequent smiling"
        } else if metrics.postureMetrics.averageConfidence > 0.7 {
            strength = "Your upright posture conveys confidence and professionalism"
        } else {
            strength = "You maintained presence during the presentation"
        }

        let improvement: String
        if metrics.facialMetrics.smileFrequency < 0.2 {
            improvement = "Try smiling more to appear more approachable and engaged"
        } else if metrics.postureMetrics.averageConfidence < 0.6 {
            improvement = "Focus on standing up straight with shoulders back for better presence"
        } else {
            improvement = "Work on varying your expressions to emphasize key points"
        }

        return GestureAnalysisResponse(
            gestureFeedback: feedback,
            gestureStrength: strength,
            gestureImprovement: improvement,
            isTemplateFallback: true
        )
    }
}

// MARK: - Errors

enum OnDeviceAIError: Error {
    case speechRecognitionUnavailable
    case foundationModelUnavailable
    case modelAssetsUnavailable

    var userMessage: String {
        switch self {
        case .speechRecognitionUnavailable:
            return "On-device speech recognition is not available. Please check your device settings."
        case .foundationModelUnavailable:
            return "Apple Intelligence is not available on this device. Please disable offline mode in settings."
        case .modelAssetsUnavailable:
            return "Apple Intelligence model is not ready. Please ensure Apple Intelligence is enabled in Settings > Apple Intelligence & Siri, and that the model has finished downloading."
        }
    }
}
