"""
Streaming TTS module with binary framing protocol including word timings.

Protocol:
[4 bytes: chunk_length (total size excluding first 4 bytes)]
[4 bytes: index]
[4 bytes: text_length]
[4 bytes: is_last]
[4 bytes: total_chunks]
[text_length bytes: UTF-8 text]
[4 bytes: timings_count]
For each timing:
  [4 bytes: start_ms]
  [4 bytes: end_ms]
  [2 bytes: word_length]
  [word_length bytes: UTF-8 word]
[remaining bytes: WAV audio data (PCM for chunks 1+)]
"""

import struct
import re
import asyncio
from typing import AsyncIterator, List, Tuple
from io import BytesIO
from loguru import logger
from .tts_service import TTSService
from .text_normalizer import normalize_text


def strip_wav_header(wav_bytes: bytes) -> bytes:
    """
    Remove 44-byte WAV header, return raw PCM data.
    Only chunks after the first need this - the first chunk keeps its header.
    """
    if len(wav_bytes) <= 44:
        return wav_bytes
    return wav_bytes[44:]


def estimate_word_timings(text: str, audio_duration_ms: int) -> List[Tuple[str, int, int]]:
    """
    Estimate word timings based on text and audio duration.
    Uses character count as a proxy for phoneme count (better than linear).
    
    Returns list of (word, start_ms, end_ms) tuples.
    """
    words = text.split()
    if not words:
        return []
    
    # Weight each word by character length as phoneme proxy
    char_counts = [max(1, len(w)) for w in words]
    total_chars = sum(char_counts)
    
    timings = []
    elapsed = 0
    for word, chars in zip(words, char_counts):
        duration = int((chars / total_chars) * audio_duration_ms)
        timings.append((word, elapsed, elapsed + duration))
        elapsed += duration
    
    return timings


def segment_text(text: str, max_words: int = 50) -> list[str]:
    """
    Segment text into natural sentence boundaries.
    
    Args:
        text: Full document text
        max_words: Maximum words per segment
        
    Returns:
        List of text segments
    """
    # Normalize text first
    text = normalize_text(text)
    
    # Split by sentence boundaries
    import re
    sentences = re.split(r'(?<=[.!?])\s+', text)
    
    segments = []
    current_segment = []
    current_word_count = 0
    
    for sentence in sentences:
        words = sentence.split()
        word_count = len(words)
        
        # If single sentence is too long, split it
        if word_count > max_words:
            if current_segment:
                segments.append(' '.join(current_segment))
                current_segment = []
                current_word_count = 0
            
            # Split long sentence at commas or conjunctions
            parts = re.split(r'(?:,\s+|(?:\s+(?:and|but|or|yet|so)\s+))', sentence)
            for part in parts:
                part_words = part.split()
                if len(part_words) > max_words:
                    # Force split at max_words
                    for i in range(0, len(part_words), max_words):
                        chunk = ' '.join(part_words[i:i+max_words])
                        segments.append(chunk)
                else:
                    segments.append(part)
        else:
            # Add to current segment if it fits
            if current_word_count + word_count <= max_words:
                current_segment.append(sentence)
                current_word_count += word_count
            else:
                # Start new segment
                if current_segment:
                    segments.append(' '.join(current_segment))
                current_segment = [sentence]
                current_word_count = word_count
    
    # Add remaining segment
    if current_segment:
        segments.append(' '.join(current_segment))
    
    return segments


def create_chunk_frame(index: int, text: str, audio_bytes: bytes, is_last: bool = False, total_chunks: int = 0) -> bytes:
    """
    Create binary frame for a TTS chunk with word timings.
    
    Frame format:
    [4 bytes: total chunk length (excluding first 4 bytes)]
    [4 bytes: index]
    [4 bytes: text length]
    [4 bytes: is_last flag (0 or 1)]
    [4 bytes: total_chunks (0 if unknown)]
    [N bytes: UTF-8 text]
    [4 bytes: timings_count]
    For each timing:
      [4 bytes: start_ms]
      [4 bytes: end_ms]
      [2 bytes: word_length]
      [K bytes: UTF-8 word]
    [M bytes: WAV audio]
    """
    text_bytes = text.encode('utf-8')
    text_length = len(text_bytes)
    audio_length = len(audio_bytes)
    
    # Estimate audio duration (WAV: 44100 Hz, 16-bit, mono = 88200 bytes/sec)
    audio_data_bytes = max(0, audio_length - 44)
    audio_duration_ms = int((audio_data_bytes / 88.2))
    
    # Generate word timings
    word_timings = estimate_word_timings(text, audio_duration_ms)
    timings_count = len(word_timings)
    
    # Calculate timings section size
    timings_bytes = bytearray()
    for word, start_ms, end_ms in word_timings:
        word_bytes = word.encode('utf-8')
        word_length = len(word_bytes)
        timings_bytes.extend(struct.pack('>I', start_ms))
        timings_bytes.extend(struct.pack('>I', end_ms))
        timings_bytes.extend(struct.pack('>H', word_length))
        timings_bytes.extend(word_bytes)
    
    # chunk_length = index(4) + text_length(4) + is_last(4) + total_chunks(4) + text(N) + timings_count(4) + timings(T) + audio(A)
    chunk_length = 4 + 4 + 4 + 4 + text_length + 4 + len(timings_bytes) + audio_length
    
    # Pack header (now includes total_chunks)
    header = struct.pack(
        '>IIIII',
        chunk_length,
        index,
        text_length,
        1 if is_last else 0,
        total_chunks,
    )
    
    timings_header = struct.pack('>I', timings_count)
    
    return header + text_bytes + timings_header + timings_bytes + audio_bytes


async def stream_tts_chunks(
    text: str,
    voice_id: str,
    speed: float = 1.0,
    tts_service: TTSService = None
) -> AsyncIterator[bytes]:
    """
    Stream TTS audio chunks with binary framing (async generator).
    
    Args:
        text: Full document text
        voice_id: Piper voice ID
        speed: Speech speed multiplier
        tts_service: TTS service instance
        
    Yields:
        Binary frames containing audio chunks
    """
    if tts_service is None:
        tts_service = TTSService()
    
    logger.info(f"Starting TTS stream: {len(text)} chars, voice={voice_id}, speed={speed}")
    
    # Segment text
    segments = segment_text(text)
    total_segments = len(segments)
    
    logger.info(f"Segmented into {total_segments} chunks")
    
    # Generate and stream each segment
    for index, segment in enumerate(segments):
        is_last = (index == total_segments - 1)
        
        try:
            # Generate audio for this segment (blocking operation, run in executor)
            loop = asyncio.get_event_loop()
            audio_bytes = await loop.run_in_executor(
                None,
                lambda: tts_service.generate_speech(
                    text=segment,
                    voice=voice_id,
                    speed=speed
                )
            )
            
            if not audio_bytes:
                logger.error(f"Failed to generate audio for chunk {index}")
                continue
            
            # Strip WAV header from chunks 1+ (keep header only in chunk 0)
            if index > 0:
                audio_bytes = strip_wav_header(audio_bytes)
                logger.debug(f"Stripped WAV header from chunk {index}, PCM size: {len(audio_bytes)}")
            
            # Create binary frame
            frame = create_chunk_frame(index, segment, audio_bytes, is_last, total_segments)
            
            logger.info(f"Yielding chunk {index}/{total_segments}: {len(segment)} chars, {len(audio_bytes)} bytes audio, frame size: {len(frame)}")
            
            yield frame
            
            logger.info(f"Chunk {index} yielded successfully")
            
        except Exception as e:
            logger.error(f"Error generating chunk {index}: {e}")
            import traceback
            traceback.print_exc()
            # Continue with next chunk instead of failing entire stream
            continue
    
    logger.success(f"Completed streaming {total_segments} chunks")
