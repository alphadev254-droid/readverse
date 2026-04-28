"""FastAPI application with TTS endpoints"""

from fastapi import FastAPI, HTTPException, Response
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger
import sys

from .models import (
    TTSRequest,
    VoiceInfo,
    VoicesResponse,
    HealthResponse,
    ErrorResponse
)
from .tts_service import tts_service
from .config import settings
from .streaming import stream_tts_chunks

# Configure logging
logger.remove()
logger.add(
    sys.stderr,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan> - <level>{message}</level>",
    level=settings.log_level
)

# Create FastAPI app
app = FastAPI(
    title="ReadVerse Piper TTS API",
    description="High-quality Text-to-Speech API powered by Piper TTS",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("Starting ReadVerse Piper TTS API")
    logger.info(f"Default voice: {settings.default_voice}")
    logger.info(f"Sample rate: {settings.sample_rate}")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down ReadVerse Piper TTS API")


@app.get("/", response_model=dict)
async def root():
    """Root endpoint"""
    return {
        "name": "ReadVerse Piper TTS API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
        "health": "/health"
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    try:
        health = tts_service.health_check()
        return HealthResponse(
            status=health["status"],
            version=health["version"],
            model=health["model"],
            voice=health["voice"]
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail="Service unhealthy")


@app.get("/v1/audio/voices", response_model=VoicesResponse)
async def list_voices():
    """
    List available voices
    
    Returns list of all available voice IDs with metadata
    """
    try:
        voices_data = tts_service.get_available_voices()
        voices = [VoiceInfo(**v) for v in voices_data]
        
        return VoicesResponse(
            voices=voices,
            total=len(voices)
        )
    except Exception as e:
        logger.error(f"Failed to list voices: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/audio/speech")
async def generate_speech(request: TTSRequest):
    """
    Generate speech from text (OpenAI compatible)
    
    Supports:
    - Multiple voices
    - Multiple output formats
    - Streaming
    - Speed control
    """
    try:
        logger.info(f"Speech request: {len(request.input)} chars, voice={request.voice}")
        
        # Validate text length
        if len(request.input) > settings.max_text_length:
            raise HTTPException(
                status_code=400,
                detail=f"Text too long. Maximum {settings.max_text_length} characters"
            )
        
        # Determine content type
        content_type_map = {
            "mp3": "audio/mpeg",
            "wav": "audio/wav",
            "opus": "audio/opus",
            "flac": "audio/flac",
            "pcm": "audio/pcm"
        }
        content_type = content_type_map.get(request.response_format, "audio/mpeg")
        
        # Streaming response
        if request.stream and settings.enable_streaming:
            logger.info("Generating streaming response")
            
            def audio_stream():
                try:
                    for chunk in tts_service.generate_speech_streaming(
                        text=request.input,
                        voice=request.voice,
                        speed=request.speed,
                        format=request.response_format
                    ):
                        yield chunk
                except Exception as e:
                    logger.error(f"Streaming error: {e}")
                    raise
            
            return StreamingResponse(
                audio_stream(),
                media_type=content_type,
                headers={
                    "Content-Disposition": f"attachment; filename=speech.{request.response_format}"
                }
            )
        
        # Non-streaming response
        logger.info("Generating non-streaming response")
        audio_bytes = tts_service.generate_speech(
            text=request.input,
            voice=request.voice,
            speed=request.speed,
            format=request.response_format
        )
        
        return Response(
            content=audio_bytes,
            media_type=content_type,
            headers={
                "Content-Disposition": f"attachment; filename=speech.{request.response_format}",
                "Content-Length": str(len(audio_bytes))
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Speech generation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/audio/stream")
async def stream_speech(request: TTSRequest):
    """
    Stream TTS audio with binary framing protocol (PRODUCTION ENDPOINT).
    
    This endpoint streams audio chunks with text synchronization.
    Binary frame format:
    [4 bytes: chunk_length]
    [4 bytes: index]
    [4 bytes: text_length]
    [4 bytes: is_last]
    [N bytes: UTF-8 text]
    [M bytes: WAV audio]
    
    Use this for continuous playback with text highlighting.
    """
    try:
        logger.info(f"Stream request: {len(request.input)} chars, voice={request.voice}")
        
        # Validate text length
        if len(request.input) > settings.max_text_length:
            raise HTTPException(
                status_code=400,
                detail=f"Text too long. Maximum {settings.max_text_length} characters"
            )
        
        return StreamingResponse(
            stream_tts_chunks(
                text=request.input,
                voice_id=request.voice,
                speed=request.speed,
                tts_service=tts_service
            ),
            media_type="application/octet-stream",
            headers={
                "X-Content-Type": "audio/wav",
                "Cache-Control": "no-cache",
                "X-Accel-Buffering": "no",  # Disable nginx buffering
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Stream generation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/audio/speech/batch")
async def generate_speech_batch(requests: list[TTSRequest]):
    """
    Generate speech for multiple texts in batch
    
    Returns array of audio files
    """
    if len(requests) > 10:
        raise HTTPException(
            status_code=400,
            detail="Maximum 10 requests per batch"
        )
    
    try:
        results = []
        for req in requests:
            audio_bytes = tts_service.generate_speech(
                text=req.input,
                voice=req.voice,
                speed=req.speed,
                format=req.response_format
            )
            results.append({
                "audio": audio_bytes.hex(),  # Hex encoded for JSON
                "format": req.response_format,
                "size": len(audio_bytes)
            })
        
        return JSONResponse(content={"results": results})
        
    except Exception as e:
        logger.error(f"Batch generation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="Internal server error",
            detail=str(exc)
        ).dict()
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8880)
