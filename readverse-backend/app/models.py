"""Pydantic models for request/response validation"""

from typing import Literal, Optional
from pydantic import BaseModel, Field, field_validator


class TTSRequest(BaseModel):
    """Text-to-Speech request model (OpenAI compatible)"""
    
    model: str = Field(default="piper", description="Model to use")
    input: str = Field(..., description="Text to convert to speech", max_length=10000)
    voice: str = Field(default="en_US-lessac-high", description="Voice ID")
    response_format: Literal["mp3", "wav", "opus", "flac", "pcm"] = Field(
        default="mp3",
        description="Audio format"
    )
    speed: float = Field(default=1.0, ge=0.25, le=4.0, description="Speech speed")
    stream: bool = Field(default=False, description="Enable streaming")
    
    @field_validator("input")
    @classmethod
    def validate_input(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Input text cannot be empty")
        return v.strip()
    
    @field_validator("voice")
    @classmethod
    def validate_voice(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Voice cannot be empty")
        return v.strip()


class VoiceInfo(BaseModel):
    """Voice information model"""
    
    id: str = Field(..., description="Voice ID")
    name: str = Field(..., description="Voice display name")
    language: str = Field(..., description="Language code")
    gender: Optional[str] = Field(None, description="Voice gender")
    description: Optional[str] = Field(None, description="Voice description")


class VoicesResponse(BaseModel):
    """Response model for voices list"""
    
    voices: list[VoiceInfo]
    total: int


class HealthResponse(BaseModel):
    """Health check response"""
    
    status: str
    version: str
    model: str
    voice: str


class ErrorResponse(BaseModel):
    """Error response model"""
    
    error: str
    detail: Optional[str] = None
    code: Optional[str] = None
