@echo off
REM ReadVerse TTS Backend Startup Script for Windows

echo Starting ReadVerse Kokoro TTS Backend...

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install/upgrade dependencies
echo Installing dependencies...
pip install -r requirements.txt

REM Check if .env exists
if not exist ".env" (
    echo Creating .env from .env.example...
    copy .env.example .env
)

REM Create necessary directories
if not exist "models" mkdir models
if not exist "output" mkdir output
if not exist "temp" mkdir temp

REM Check for espeak-ng
where espeak-ng >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: espeak-ng not found. Please install it from:
    echo https://github.com/espeak-ng/espeak-ng/releases
    echo.
)

REM Start the server
echo Starting server...
python main.py

pause
