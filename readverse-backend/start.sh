#!/bin/bash

# ReadVerse TTS Backend Startup Script

echo "Starting ReadVerse Kokoro TTS Backend..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install/upgrade dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
fi

# Create necessary directories
mkdir -p models output temp

# Check for espeak-ng
if ! command -v espeak-ng &> /dev/null; then
    echo "WARNING: espeak-ng not found. Please install it:"
    echo "  Ubuntu/Debian: sudo apt-get install espeak-ng"
    echo "  macOS: brew install espeak-ng"
    echo ""
fi

# Start the server
echo "Starting server..."
python main.py
