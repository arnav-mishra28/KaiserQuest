"""
KaiserQuest - Voice AI Service Stubs
Provides Speech-to-Text (Whisper) and Text-to-Speech (gTTS) endpoints.
These are stubs that can be wired to real implementations when dependencies
are available.
"""

from __future__ import annotations

import io
import logging
import base64
from typing import Optional

logger = logging.getLogger("kaiserquest.voice_service")

# ---------------------------------------------------------------------------
# Check for optional dependencies
# ---------------------------------------------------------------------------
WHISPER_AVAILABLE = False
GTTS_AVAILABLE = False

try:
    import whisper  # type: ignore
    WHISPER_AVAILABLE = True
    logger.info("Whisper STT is available")
except ImportError:
    logger.info("Whisper not installed — STT will use stub responses")

try:
    from gtts import gTTS  # type: ignore
    GTTS_AVAILABLE = True
    logger.info("gTTS is available")
except ImportError:
    logger.info("gTTS not installed — TTS will use stub responses")


# ---------------------------------------------------------------------------
# Speech-to-Text
# ---------------------------------------------------------------------------
_whisper_model = None


def _get_whisper_model():
    global _whisper_model
    if _whisper_model is None and WHISPER_AVAILABLE:
        logger.info("Loading Whisper base model...")
        _whisper_model = whisper.load_model("base")
        logger.info("Whisper model loaded")
    return _whisper_model


async def speech_to_text(audio_bytes: bytes, language: str = "en") -> dict:
    """
    Convert speech audio to text.

    Args:
        audio_bytes: Raw audio file bytes (WAV, MP3, etc.)
        language: Language code (default: "en")

    Returns:
        Dict with "text" and "confidence" keys.
    """
    if not WHISPER_AVAILABLE:
        logger.info("STT stub called — returning placeholder text")
        return {
            "text": "[STT Stub] Install openai-whisper for real speech recognition.",
            "confidence": 0.0,
            "language": language,
            "is_stub": True,
        }

    try:
        import tempfile
        import os

        model = _get_whisper_model()
        if model is None:
            return {"text": "", "confidence": 0.0, "error": "Model not loaded"}

        # Write audio to temp file for Whisper
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        result = model.transcribe(tmp_path, language=language)
        os.unlink(tmp_path)

        text = result.get("text", "").strip()
        # Whisper doesn't give per-segment confidence easily; estimate from segments
        segments = result.get("segments", [])
        avg_confidence = 0.0
        if segments:
            avg_confidence = sum(
                s.get("avg_logprob", -1.0) for s in segments
            ) / len(segments)
            # Convert log-prob to a 0-1 scale (rough heuristic)
            avg_confidence = max(0.0, min(1.0, 1.0 + avg_confidence))

        return {
            "text": text,
            "confidence": round(avg_confidence, 3),
            "language": language,
            "is_stub": False,
        }
    except Exception as e:
        logger.exception("STT error: %s", e)
        return {"text": "", "confidence": 0.0, "error": str(e)}


# ---------------------------------------------------------------------------
# Text-to-Speech
# ---------------------------------------------------------------------------
async def text_to_speech(text: str, language: str = "en") -> dict:
    """
    Convert text to speech audio.

    Args:
        text: The text to speak.
        language: Language code (default: "en").

    Returns:
        Dict with "audio_base64" (base64-encoded MP3) and metadata.
    """
    if not GTTS_AVAILABLE:
        logger.info("TTS stub called — returning placeholder")
        return {
            "audio_base64": "",
            "format": "mp3",
            "text": text,
            "language": language,
            "is_stub": True,
            "message": "Install gTTS for real text-to-speech. pip install gTTS",
        }

    try:
        tts = gTTS(text=text, lang=language, slow=False)
        buf = io.BytesIO()
        tts.write_to_fp(buf)
        buf.seek(0)
        audio_b64 = base64.b64encode(buf.read()).decode("utf-8")

        return {
            "audio_base64": audio_b64,
            "format": "mp3",
            "text": text,
            "language": language,
            "is_stub": False,
            "size_bytes": len(base64.b64decode(audio_b64)),
        }
    except Exception as e:
        logger.exception("TTS error: %s", e)
        return {"audio_base64": "", "error": str(e)}


# ---------------------------------------------------------------------------
# Utility: Validate answer by voice
# ---------------------------------------------------------------------------
async def voice_answer(audio_bytes: bytes, expected_answer: str, language: str = "en") -> dict:
    """
    Convenience: transcribe audio and compare to expected answer.
    Useful for voice-based battle answers.
    """
    stt_result = await speech_to_text(audio_bytes, language)
    spoken_text = stt_result.get("text", "").strip().lower()
    expected = expected_answer.strip().lower()

    is_match = spoken_text == expected
    # Fuzzy: check if expected is contained in spoken text
    is_close = expected in spoken_text or spoken_text in expected

    return {
        "spoken_text": spoken_text,
        "expected_answer": expected_answer,
        "is_match": is_match,
        "is_close_match": is_close,
        "stt_confidence": stt_result.get("confidence", 0.0),
        "is_stub": stt_result.get("is_stub", True),
    }
