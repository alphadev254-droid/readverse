"""Configuration management"""

import os
from pathlib import Path
from typing import Literal
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings"""
    
    # Server
    host: str = "0.0.0.0"
    port: int = 8880
    workers: int = 1
    log_level: str = "INFO"
    
    # Piper TTS
    default_voice: str = "en_US-lessac-high"  # Highest quality voice
    default_speed: float = 1.0
    default_format: Literal["mp3", "wav", "opus", "flac"] = "mp3"
    
    # Audio
    sample_rate: int = 22050  # Piper default
    max_text_length: int = 10000
    
    # Performance
    enable_streaming: bool = True
    chunk_size: int = 1024
    cache_enabled: bool = False
    
    # Paths
    models_dir: Path = Path("./models")
    output_dir: Path = Path("./output")
    temp_dir: Path = Path("./temp")
    
    class Config:
        env_file = ".env"
        case_sensitive = False


# Global settings instance
settings = Settings()

# Create directories
settings.models_dir.mkdir(parents=True, exist_ok=True)
settings.output_dir.mkdir(parents=True, exist_ok=True)
settings.temp_dir.mkdir(parents=True, exist_ok=True)
