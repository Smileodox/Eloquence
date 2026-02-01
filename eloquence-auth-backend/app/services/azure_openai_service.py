"""
Azure OpenAI Service - Handles all Azure OpenAI API calls.
"""
import httpx
import base64
import logging
from typing import Optional
from app.config import settings

# Configure logging
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


class AzureOpenAIService:
    """Service for Azure OpenAI API interactions (Whisper + GPT)."""

    def _get_voice_style_instruction(self, voice_style: str) -> str:
        """Get coaching style instruction based on voice style setting."""
        if voice_style == "Motivational":
            return """
Coaching Style: MOTIVATIONAL
- Use encouraging, energetic language
- Celebrate strengths enthusiastically
- Frame improvements as exciting opportunities
- Use phrases like "Great job!", "You're on the right track!", "Keep pushing!"
"""
        elif voice_style == "Analytical":
            return """
Coaching Style: ANALYTICAL
- Use precise, data-driven language
- Focus on metrics and measurable observations
- Provide structured, logical feedback
- Avoid emotional language, be objective and clinical
"""
        else:  # Neutral
            return """
Coaching Style: NEUTRAL
- Use balanced, professional language
- Mix encouragement with constructive criticism
- Be direct but supportive
"""

    def __init__(self):
        # Whisper config (separate resource)
        self.whisper_endpoint = settings.azure_whisper_endpoint.rstrip("/")
        self.whisper_api_key = settings.azure_whisper_api_key
        self.whisper_deployment = settings.azure_whisper_deployment
        self.whisper_api_version = settings.azure_whisper_api_version

        # GPT config (separate resource)
        self.gpt_endpoint = settings.azure_gpt_endpoint.rstrip("/")
        self.gpt_api_key = settings.azure_gpt_api_key
        self.gpt_deployment = settings.azure_gpt_deployment
        self.gpt_api_version = settings.azure_gpt_api_version

        # Log config on init (mask API keys)
        masked_whisper_key = f"{self.whisper_api_key[:4]}...{self.whisper_api_key[-4:]}" if len(self.whisper_api_key) > 8 else "NOT SET"
        masked_gpt_key = f"{self.gpt_api_key[:4]}...{self.gpt_api_key[-4:]}" if len(self.gpt_api_key) > 8 else "NOT SET"
        logger.info(f"[Whisper] Endpoint: {self.whisper_endpoint}")
        logger.info(f"[Whisper] API Key: {masked_whisper_key}")
        logger.info(f"[Whisper] Deployment: {self.whisper_deployment} (v{self.whisper_api_version})")
        logger.info(f"[GPT] Endpoint: {self.gpt_endpoint}")
        logger.info(f"[GPT] API Key: {masked_gpt_key}")
        logger.info(f"[GPT] Deployment: {self.gpt_deployment} (v{self.gpt_api_version})")

    def _whisper_url(self) -> str:
        return f"{self.whisper_endpoint}/openai/deployments/{self.whisper_deployment}/audio/transcriptions?api-version={self.whisper_api_version}"

    def _gpt_url(self) -> str:
        return f"{self.gpt_endpoint}/openai/deployments/{self.gpt_deployment}/chat/completions?api-version={self.gpt_api_version}"

    async def transcribe_audio(self, audio_data: bytes, filename: str = "audio.m4a") -> dict:
        """
        Transcribe audio using Azure Whisper API.

        Args:
            audio_data: Raw audio file bytes
            filename: Original filename for content-type detection

        Returns:
            dict with text, duration, language
        """
        url = self._whisper_url()
        logger.info(f"[Whisper] Request URL: {url}")
        logger.info(f"[Whisper] Audio size: {len(audio_data)} bytes, filename: {filename}")

        # Determine content type from filename
        content_type = "audio/m4a"
        if filename.endswith(".wav"):
            content_type = "audio/wav"
        elif filename.endswith(".mp3"):
            content_type = "audio/mpeg"
        logger.info(f"[Whisper] Content-Type: {content_type}")

        files = {
            "file": (filename, audio_data, content_type),
            "model": (None, "whisper-1"),
        }

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                logger.info(f"[Whisper] Sending request...")
                response = await client.post(
                    url,
                    headers={"api-key": self.whisper_api_key},
                    files=files,
                )
                logger.info(f"[Whisper] Response status: {response.status_code}")

                if response.status_code != 200:
                    logger.error(f"[Whisper] Error response body: {response.text}")

                response.raise_for_status()
                result = response.json()
                logger.info(f"[Whisper] Success - transcribed {len(result.get('text', ''))} chars")
                return result
        except httpx.TimeoutException as e:
            logger.error(f"[Whisper] Timeout after 60s: {e}")
            raise
        except httpx.HTTPStatusError as e:
            logger.error(f"[Whisper] HTTP error {e.response.status_code}: {e.response.text}")
            raise
        except Exception as e:
            logger.error(f"[Whisper] Unexpected error: {type(e).__name__}: {e}")
            raise

    async def analyze_speech(
        self,
        transcription: str,
        word_count: int,
        duration: float,
        words_per_minute: int,
        pause_count: int,
        sentence_count: int,
        average_sentence_length: float,
        voice_style: str = "Neutral",
    ) -> dict:
        """
        Generate speech feedback using GPT.

        Returns:
            dict with toneScore, confidenceScore, enthusiasmScore, clarityScore,
            feedback, keyStrengths, areasToImprove
        """
        voice_style_instruction = self._get_voice_style_instruction(voice_style)

        system_prompt = f"""You are an expert presentation coach analyzing a practice presentation. Provide detailed, personalized coaching feedback that references specific moments from the transcription.

{voice_style_instruction}

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
{{
  "toneScore": <number 0-100>,
  "confidenceScore": <number 0-100>,
  "enthusiasmScore": <number 0-100>,
  "clarityScore": <number 0-100>,
  "feedback": "<detailed, personalized coaching feedback>",
  "keyStrengths": ["<specific strength with example>", "<specific strength with example>"],
  "areasToImprove": ["<specific area with actionable advice>", "<specific area with actionable advice>"],
  "toneStrength": "<specific strength about vocal tone with example from the speech>",
  "toneImprovement": "<specific actionable improvement for vocal tone>",
  "pacingStrength": "<specific strength about pacing/rhythm, reference the WPM if relevant>",
  "pacingImprovement": "<specific actionable improvement for pacing>"
}}"""

        user_prompt = f"""Please analyze this presentation:

TRANSCRIPTION:
"{transcription}"

METRICS:
- Speaking pace: {words_per_minute} words per minute
- Total words: {word_count}
- Duration: {duration:.1f} seconds
- Pauses used: {pause_count}
- Sentences: {sentence_count}
- Average sentence length: {average_sentence_length:.1f} words

Provide your analysis in JSON format as specified."""

        return await self._chat_completion(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            max_tokens=2000,
            json_response=True,
        )

    async def analyze_gesture(
        self,
        transcription: str,
        smile_frequency: float,
        expression_variety: float,
        engagement_level: float,
        confidence_score: float,
        movement_consistency: float,
        stability_score: float,
        camera_focus_percentage: float,
        reading_notes_percentage: float,
        gaze_stability_score: float,
        voice_style: str = "Neutral",
    ) -> dict:
        """
        Generate gesture feedback using GPT.

        Returns:
            dict with gestureFeedback, gestureStrength, gestureImprovement
        """
        # Determine what was detected
        has_facial = smile_frequency > 0 or expression_variety > 0 or engagement_level > 0
        has_posture = confidence_score > 0 or movement_consistency > 0 or stability_score > 0
        has_eye_contact = camera_focus_percentage > 0 or gaze_stability_score > 0

        focus_areas = []
        if has_facial:
            focus_areas.append("facial expressions (smiling, engagement, expressiveness)")
        if has_posture:
            focus_areas.append("body posture (confidence, natural movement, stability)")
        if has_eye_contact:
            focus_areas.append("eye contact (camera focus, gaze stability)")

        voice_style_instruction = self._get_voice_style_instruction(voice_style)

        system_prompt = f"""You are an expert presentation coach analyzing body language and non-verbal communication. Based on the gesture metrics and presentation content provided, evaluate the speaker's {", ".join(focus_areas)} and provide detailed, contextual coaching feedback.

{voice_style_instruction}

IMPORTANT: Only provide feedback about the metrics that were detected. Do not mention facial expressions if no facial data is available, do not mention posture if no posture data is available, and do not mention eye contact if no eye contact data is available.

Feedback Quality Guidelines:
- Connect body language observations to specific moments in the presentation
- Reference the presentation content to make feedback contextual
- Provide actionable advice with concrete examples
- Match your tone to the presentation's formality and topic
- Be specific and helpful, not generic (use as much detail as needed)

Respond ONLY with valid JSON matching this exact structure (no additional text):
{{
  "gestureFeedback": "<detailed, contextual coaching feedback about detected body language>",
  "gestureStrength": "<specific strength with example from the presentation>",
  "gestureImprovement": "<specific improvement area with actionable advice>"
}}"""

        # Build metrics section
        metrics_section = ""
        if has_facial:
            metrics_section += f"""FACIAL EXPRESSION METRICS:
- Smile frequency: {smile_frequency * 100:.1f}%
- Expression variety: {expression_variety * 100:.1f}%
- Engagement level: {engagement_level * 100:.1f}%

"""
        if has_posture:
            metrics_section += f"""BODY POSTURE METRICS:
- Posture confidence: {confidence_score * 100:.1f}%
- Movement consistency: {movement_consistency * 100:.1f}%
- Stability: {stability_score * 100:.1f}%

"""
        if has_eye_contact:
            metrics_section += f"""EYE CONTACT METRICS:
- Camera focus: {camera_focus_percentage * 100:.1f}%
- Time reading notes (looking down): {reading_notes_percentage * 100:.1f}%
- Gaze stability: {gaze_stability_score * 100:.1f}%

"""
            if reading_notes_percentage > 0.15:
                metrics_section += "NOTE: The speaker frequently looked down, likely reading notes. Address this in the feedback.\n"

        user_prompt = f"""Please analyze this speaker's body language:

{metrics_section}
FULL PRESENTATION TRANSCRIPTION:
"{transcription}"

Provide your gesture analysis in JSON format as specified. Reference specific moments from the transcription to make your feedback contextual and helpful. Only comment on the metrics that were actually detected."""

        return await self._chat_completion(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            max_tokens=2000,
            json_response=True,
        )

    async def annotate_key_frame(
        self,
        image_base64: str,
        frame_type: str,
        transcription_excerpt: str,
        timestamp: float,
        voice_style: str = "Neutral",
    ) -> str:
        """
        Generate key frame annotation using GPT Vision.

        Args:
            image_base64: Base64-encoded JPEG image
            frame_type: Type of key frame (bestFacial, bestOverall, improveFacial, etc.)
            transcription_excerpt: Transcription context around this timestamp
            timestamp: Timestamp in seconds
            voice_style: Coaching style (Neutral, Motivational, Analytical)

        Returns:
            Annotation text (20-40 words)
        """
        voice_style_instruction = self._get_voice_style_instruction(voice_style)

        system_prompt = f"""You are an expert presentation coach analyzing a specific moment from a presentation. Based on the frame image and transcription context, provide one concise, specific coaching comment (20-40 words).

{voice_style_instruction}

Guidelines:
- Adapt tone to presentation formality (academic = professional, casual = friendly)
- Reference specific visual details (posture, expression, gaze)
- Connect to transcription context when relevant
- Be specific and actionable, not generic
- For "best" frames: highlight what's working well
- For "improve" frames: suggest specific improvements"""

        # Build type-specific guidance
        type_guidance = {
            "bestFacial": "This is a STRENGTH moment for facial expression. Highlight what's working well (eye contact, smile, engagement, etc.).",
            "bestOverall": "This is a STRENGTH moment overall. Highlight the combination of good expression, posture, and engagement.",
            "improveFacial": "This is an IMPROVEMENT AREA for facial expression. Suggest specific ways to improve engagement, eye contact, or expressiveness.",
            "improvePosture": "This is an IMPROVEMENT AREA for posture. Suggest specific ways to improve body position, confidence, or stability.",
            "improveEyeContact": "This is an IMPROVEMENT AREA for eye contact. Suggest ways to improve camera focus or gaze consistency.",
            "averageMoment": "This is a REPRESENTATIVE moment. Provide neutral, balanced observation.",
        }.get(frame_type, "Provide a balanced observation.")

        user_prompt = f"""Frame type: {frame_type}
Timestamp: {timestamp:.1f}s

{type_guidance}

Transcription context:
"{transcription_excerpt}"

Analyze this presentation frame and provide ONE concise coaching comment (20-40 words). Return ONLY the annotation text, no JSON, no additional formatting."""

        messages = [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": user_prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"},
                    },
                ],
            },
        ]

        url = self._gpt_url()
        logger.info(f"[Vision] Request URL: {url}")
        logger.info(f"[Vision] Frame type: {frame_type}, timestamp: {timestamp:.1f}s, image: {len(image_base64)} chars base64")

        request_body = {
            "messages": messages,
            "max_completion_tokens": 1500,
            "temperature": 1.0,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                logger.info(f"[Vision] Sending request...")
                response = await client.post(
                    url,
                    headers={
                        "api-key": self.gpt_api_key,
                        "Content-Type": "application/json",
                    },
                    json=request_body,
                )
                logger.info(f"[Vision] Response status: {response.status_code}")

                if response.status_code != 200:
                    logger.error(f"[Vision] Error response body: {response.text}")

                response.raise_for_status()
                data = response.json()

            # Extract annotation from response
            annotation = data["choices"][0]["message"]["content"]
            logger.info(f"[Vision] Success - annotation: {annotation[:50]}...")
            # Clean up annotation
            return annotation.strip().replace('"', "")
        except httpx.TimeoutException as e:
            logger.error(f"[Vision] Timeout after 30s: {e}")
            raise
        except httpx.HTTPStatusError as e:
            logger.error(f"[Vision] HTTP error {e.response.status_code}: {e.response.text}")
            raise
        except Exception as e:
            logger.error(f"[Vision] Unexpected error: {type(e).__name__}: {e}")
            raise

    async def _chat_completion(
        self,
        system_prompt: str,
        user_prompt: str,
        max_tokens: int = 2000,
        json_response: bool = False,
    ) -> dict:
        """Internal helper for GPT chat completions."""
        url = self._gpt_url()
        logger.info(f"[GPT] Request URL: {url}")
        logger.info(f"[GPT] Prompt length: {len(user_prompt)} chars, max_tokens: {max_tokens}")

        request_body = {
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "max_completion_tokens": max_tokens,
            "temperature": 1.0,
        }

        # NOTE: response_format: json_object removed - GPT-5 returns empty responses with it.
        # JSON output is already enforced via "Respond ONLY with valid JSON" in prompts.

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                logger.info(f"[GPT] Sending request...")
                response = await client.post(
                    url,
                    headers={
                        "api-key": self.gpt_api_key,
                        "Content-Type": "application/json",
                    },
                    json=request_body,
                )
                logger.info(f"[GPT] Response status: {response.status_code}")

                if response.status_code != 200:
                    logger.error(f"[GPT] Error response body: {response.text}")

                response.raise_for_status()
                data = response.json()

            # Parse the content from the response
            content = data["choices"][0]["message"]["content"]

            # Handle empty responses (safety net)
            if not content:
                finish_reason = data["choices"][0].get("finish_reason", "unknown")
                logger.error(f"[GPT] Empty response received (finish_reason: {finish_reason})")
                raise ValueError(f"GPT returned empty response (finish_reason: {finish_reason})")

            logger.info(f"[GPT] Success - response {len(content)} chars")

            if json_response:
                import json
                return json.loads(content)
            return {"content": content}
        except httpx.TimeoutException as e:
            logger.error(f"[GPT] Timeout after 60s: {e}")
            raise
        except httpx.HTTPStatusError as e:
            logger.error(f"[GPT] HTTP error {e.response.status_code}: {e.response.text}")
            raise
        except Exception as e:
            logger.error(f"[GPT] Unexpected error: {type(e).__name__}: {e}")
            raise
