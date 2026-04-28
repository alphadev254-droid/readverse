"""
ReadVerse Kokoro TTS Backend
FastAPI server for high-quality text-to-speech generation
"""

import uvicorn
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8880))
    workers = int(os.getenv("WORKERS", 1))
    log_level = os.getenv("LOG_LEVEL", "info").lower()
    
    uvicorn.run(
        "app.api:app",
        host=host,
        port=port,
        workers=workers,
        log_level=log_level,
        reload=True,  # Set to False in production
    )
