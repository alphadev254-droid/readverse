"""Piper TTS Service - Core text-to-speech functionality"""

import io
import wave
import json
from typing import Generator, Optional
from pathlib import Path
from loguru import logger
from piper import PiperVoice

from .config import settings


class TTSService:
    """Text-to-Speech service using Piper"""
    
    def __init__(self):
        self.voice: Optional[PiperVoice] = None
        self.current_voice_name: str = settings.default_voice
        self._initialize_voice()
    
    def _initialize_voice(self):
        """Initialize Piper voice"""
        try:
            logger.info(f"Initializing Piper voice: {self.current_voice_name}")
            
            # Download voice model if not exists
            model_path = settings.models_dir / f"{self.current_voice_name}.onnx"
            config_path = settings.models_dir / f"{self.current_voice_name}.onnx.json"
            
            if not model_path.exists():
                logger.info(f"Downloading voice model: {self.current_voice_name}")
                self._download_voice_model(self.current_voice_name)
            
            # Load voice
            self.voice = PiperVoice.load(str(model_path), config_path=str(config_path) if config_path.exists() else None)
            logger.success(f"Piper voice loaded: {self.current_voice_name}")
            
        except Exception as e:
            logger.error(f"Failed to initialize Piper voice: {e}")
            raise
    
    def _download_voice_model(self, voice_name: str):
        """Download voice model from Hugging Face"""
        import requests
        
        # Piper models are hosted on Hugging Face
        base_url = "https://huggingface.co/rhasspy/piper-voices/resolve/main"
        
        # Map voice names to model paths
        # Format: voice_name -> path on Hugging Face
        voice_map = {
            # High quality voices (best quality, larger models ~30-50MB)
            "en_US-lessac-high": "en/en_US/lessac/high/en_US-lessac-high",
            "en_US-amy-high": "en/en_US/amy/high/en_US-amy-high",
            "en_US-ryan-high": "en/en_US/ryan/high/en_US-ryan-high",
            "en_US-libritts-high": "en/en_US/libritts/high/en_US-libritts-high",
            "en_GB-alan-high": "en/en_GB/alan/high/en_GB-alan-high",
            "en_GB-alba-high": "en/en_GB/alba/high/en_GB-alba-high",
            "en_GB-jenny_dioco-high": "en/en_GB/jenny_dioco/high/en_GB-jenny_dioco-high",
            
            # Medium quality voices (good balance, ~10-15MB)
            "en_US-lessac-medium": "en/en_US/lessac/medium/en_US-lessac-medium",
            "en_US-amy-medium": "en/en_US/amy/medium/en_US-amy-medium",
            "en_US-ryan-medium": "en/en_US/ryan/medium/en_US-ryan-medium",
            "en_US-libritts-medium": "en/en_US/libritts/medium/en_US-libritts-medium",
            "en_GB-alan-medium": "en/en_GB/alan/medium/en_GB-alan-medium",
            "en_GB-alba-medium": "en/en_GB/alba/medium/en_GB-alba-medium",
            
            # Low quality voices (fastest, smallest ~5MB)
            "en_US-lessac-low": "en/en_US/lessac/low/en_US-lessac-low",
            "en_US-amy-low": "en/en_US/amy/low/en_US-amy-low",
            "en_US-ryan-low": "en/en_US/ryan/low/en_US-ryan-low",
        }
        
        model_path_template = voice_map.get(voice_name, f"en/en_US/lessac/medium/en_US-lessac-medium")
        
        # Download .onnx file
        onnx_url = f"{base_url}/{model_path_template}.onnx"
        json_url = f"{base_url}/{model_path_template}.onnx.json"
        
        model_file = settings.models_dir / f"{voice_name}.onnx"
        config_file = settings.models_dir / f"{voice_name}.onnx.json"
        
        logger.info(f"Downloading from {onnx_url}")
        
        # Download model
        response = requests.get(onnx_url, stream=True)
        response.raise_for_status()
        with open(model_file, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        # Download config
        response = requests.get(json_url)
        response.raise_for_status()
        with open(config_file, 'wb') as f:
            f.write(response.content)
        
        logger.success(f"Downloaded voice model: {voice_name}")
    
    def generate_speech(
        self,
        text: str,
        voice: str = None,
        speed: float = 1.0,
        format: str = "wav"
    ) -> bytes:
        """
        Generate speech from text
        
        Args:
            text: Input text
            voice: Voice name (if different from current)
            speed: Speech speed multiplier
            format: Output audio format (wav, mp3)
            
        Returns:
            Audio bytes in specified format
        """
        if not self.voice:
            raise RuntimeError("TTS voice not initialized")
        
        # Switch voice if needed
        if voice and voice != self.current_voice_name:
            self.current_voice_name = voice
            self._initialize_voice()
        
        try:
            logger.info(f"Generating speech: {len(text)} chars, voice={self.current_voice_name}, speed={speed}")
            
            # Generate audio using Piper
            audio_bytes = io.BytesIO()
            wav_file = None
            
            # Synthesize - returns iterator of audio chunks
            for audio_chunk in self.voice.synthesize(text):
                if wav_file is None:
                    # Initialize WAV file with chunk properties
                    wav_file = wave.open(audio_bytes, 'wb')
                    wav_file.setframerate(audio_chunk.sample_rate)
                    wav_file.setsampwidth(audio_chunk.sample_width)
                    wav_file.setnchannels(audio_chunk.sample_channels)
                
                # Write audio data
                wav_file.writeframes(audio_chunk.audio_int16_bytes)
            
            if wav_file is not None:
                wav_file.close()
            
            audio_data = audio_bytes.getvalue()
            
            # Apply speed adjustment if needed (via pydub)
            if speed != 1.0:
                audio_data = self._adjust_speed(audio_data, speed)
            
            # Convert format if needed
            if format != "wav":
                audio_data = self._convert_format(audio_data, format)
            
            logger.success(f"Generated {len(audio_data)} bytes of audio")
            return audio_data
            
        except Exception as e:
            logger.error(f"Speech generation failed: {e}")
            raise
    
    def generate_speech_streaming(
        self,
        text: str,
        voice: str = None,
        speed: float = 1.0,
        format: str = "wav"
    ) -> Generator[bytes, None, None]:
        """
        Generate speech with streaming support
        
        Args:
            text: Input text
            voice: Voice name
            speed: Speech speed
            format: Output format
            
        Yields:
            Audio chunks as bytes
        """
        if not self.voice:
            raise RuntimeError("TTS voice not initialized")
        
        # Switch voice if needed
        if voice and voice != self.current_voice_name:
            self.current_voice_name = voice
            self._initialize_voice()
        
        try:
            logger.info(f"Streaming speech: {len(text)} chars, voice={self.current_voice_name}")
            
            # Piper's synthesize() returns an iterator of audio chunks
            for audio_chunk in self.voice.synthesize(text):
                # Convert chunk to WAV format
                chunk_bytes = self._chunk_to_wav(audio_chunk)
                logger.debug(f"Streaming chunk: {len(chunk_bytes)} bytes")
                yield chunk_bytes
                
        except Exception as e:
            logger.error(f"Streaming generation failed: {e}")
            raise
    
    def _chunk_to_wav(self, audio_chunk) -> bytes:
        """Convert Piper audio chunk to WAV format"""
        buffer = io.BytesIO()
        with wave.open(buffer, 'wb') as wav_file:
            wav_file.setframerate(audio_chunk.sample_rate)
            wav_file.setsampwidth(audio_chunk.sample_width)
            wav_file.setnchannels(audio_chunk.sample_channels)
            wav_file.writeframes(audio_chunk.audio_int16_bytes)
        return buffer.getvalue()
    
    def _pcm_to_wav(self, pcm_data: bytes) -> bytes:
        """Convert raw PCM data to WAV format (legacy method, kept for compatibility)"""
        buffer = io.BytesIO()
        with wave.open(buffer, 'wb') as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)  # 16-bit
            wav_file.setframerate(self.voice.config.sample_rate)
            wav_file.writeframes(pcm_data)
        return buffer.getvalue()
    
    def _adjust_speed(self, audio_data: bytes, speed: float) -> bytes:
        """
        Adjust audio playback speed using pydub
        
        Args:
            audio_data: WAV audio bytes
            speed: Speed multiplier (0.5 = slower, 2.0 = faster)
            
        Returns:
            Speed-adjusted audio bytes
        """
        try:
            from pydub import AudioSegment
            from pydub.effects import speedup
            
            # Load audio
            audio = AudioSegment.from_wav(io.BytesIO(audio_data))
            
            # Adjust speed
            if speed > 1.0:
                # Speed up
                audio = speedup(audio, playback_speed=speed)
            elif speed < 1.0:
                # Slow down by changing frame rate
                new_frame_rate = int(audio.frame_rate * speed)
                audio = audio._spawn(audio.raw_data, overrides={'frame_rate': new_frame_rate})
                audio = audio.set_frame_rate(audio.frame_rate)
            
            # Export back to bytes
            output = io.BytesIO()
            audio.export(output, format='wav')
            
            logger.debug(f"Adjusted speed to {speed}x")
            return output.getvalue()
            
        except ImportError:
            logger.warning("pydub not installed, speed adjustment not available")
            return audio_data
        except Exception as e:
            logger.error(f"Speed adjustment failed: {e}, returning original audio")
            return audio_data
    
    def _convert_format(self, audio_data: bytes, target_format: str) -> bytes:
        """
        Convert audio to different format using pydub
        
        Args:
            audio_data: WAV audio bytes
            target_format: Target format (mp3, opus, etc.)
            
        Returns:
            Converted audio bytes
        """
        if target_format == "wav":
            return audio_data
        
        try:
            from pydub import AudioSegment
            import io
            
            # Load WAV from bytes
            audio = AudioSegment.from_wav(io.BytesIO(audio_data))
            
            # Convert to target format
            output = io.BytesIO()
            audio.export(output, format=target_format)
            
            logger.debug(f"Converted audio to {target_format}")
            return output.getvalue()
            
        except ImportError:
            logger.warning(f"pydub not installed, format conversion to {target_format} not available, returning WAV")
            return audio_data
        except Exception as e:
            logger.error(f"Format conversion failed: {e}, returning WAV")
            return audio_data
    
    def get_available_voices(self) -> list[dict]:
        """
        Get list of available voices
        
        Returns:
            List of voice information dictionaries
        """
        # Piper voice list with quality tiers
        voices = [
            # HIGH QUALITY (Best quality, ~30-50MB each)
            {
                "id": "en_US-lessac-high",
                "name": "Lessac (US) - High Quality",
                "language": "en-US",
                "gender": "male",
                "description": "Highest quality clear American English male voice",
                "quality": "high"
            },
            {
                "id": "en_US-amy-high",
                "name": "Amy (US) - High Quality",
                "language": "en-US",
                "gender": "female",
                "description": "Highest quality natural American English female voice",
                "quality": "high"
            },
            {
                "id": "en_US-ryan-high",
                "name": "Ryan (US) - High Quality",
                "language": "en-US",
                "gender": "male",
                "description": "Highest quality professional American English male voice",
                "quality": "high"
            },
            {
                "id": "en_US-libritts-high",
                "name": "LibriTTS (US) - High Quality",
                "language": "en-US",
                "gender": "neutral",
                "description": "Highest quality expressive American English voice",
                "quality": "high"
            },
            {
                "id": "en_GB-alan-high",
                "name": "Alan (GB) - High Quality",
                "language": "en-GB",
                "gender": "male",
                "description": "Highest quality British English male voice",
                "quality": "high"
            },
            {
                "id": "en_GB-alba-high",
                "name": "Alba (GB) - High Quality",
                "language": "en-GB",
                "gender": "female",
                "description": "Highest quality British English female voice",
                "quality": "high"
            },
            {
                "id": "en_GB-jenny_dioco-high",
                "name": "Jenny (GB) - High Quality",
                "language": "en-GB",
                "gender": "female",
                "description": "Highest quality British English female voice, warm tone",
                "quality": "high"
            },
            
            # MEDIUM QUALITY (Good balance, ~10-15MB each)
            {
                "id": "en_US-lessac-medium",
                "name": "Lessac (US) - Medium Quality",
                "language": "en-US",
                "gender": "male",
                "description": "Clear American English male voice",
                "quality": "medium"
            },
            {
                "id": "en_US-amy-medium",
                "name": "Amy (US) - Medium Quality",
                "language": "en-US",
                "gender": "female",
                "description": "Natural American English female voice",
                "quality": "medium"
            },
            {
                "id": "en_US-ryan-medium",
                "name": "Ryan (US) - Medium Quality",
                "language": "en-US",
                "gender": "male",
                "description": "Professional American English male voice",
                "quality": "medium"
            },
            {
                "id": "en_US-libritts-medium",
                "name": "LibriTTS (US) - Medium Quality",
                "language": "en-US",
                "gender": "neutral",
                "description": "Expressive American English voice",
                "quality": "medium"
            },
            {
                "id": "en_GB-alan-medium",
                "name": "Alan (GB) - Medium Quality",
                "language": "en-GB",
                "gender": "male",
                "description": "British English male voice",
                "quality": "medium"
            },
            {
                "id": "en_GB-alba-medium",
                "name": "Alba (GB) - Medium Quality",
                "language": "en-GB",
                "gender": "female",
                "description": "British English female voice",
                "quality": "medium"
            },
            
            # LOW QUALITY (Fastest, smallest ~5MB each)
            {
                "id": "en_US-lessac-low",
                "name": "Lessac (US) - Low Quality",
                "language": "en-US",
                "gender": "male",
                "description": "Fast American English male voice (smaller model)",
                "quality": "low"
            },
            {
                "id": "en_US-amy-low",
                "name": "Amy (US) - Low Quality",
                "language": "en-US",
                "gender": "female",
                "description": "Fast American English female voice (smaller model)",
                "quality": "low"
            },
            {
                "id": "en_US-ryan-low",
                "name": "Ryan (US) - Low Quality",
                "language": "en-US",
                "gender": "male",
                "description": "Fast American English male voice (smaller model)",
                "quality": "low"
            },
        ]
        
        return voices
    
    def health_check(self) -> dict:
        """
        Check service health
        
        Returns:
            Health status dictionary
        """
        return {
            "status": "healthy" if self.voice else "unhealthy",
            "model": "Piper TTS",
            "voice": self.current_voice_name,
            "version": "1.4.2"
        }


# Global TTS service instance
tts_service = TTSService()
