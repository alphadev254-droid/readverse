# ReadVerse Piper TTS Backend

High-quality, lightweight Text-to-Speech API powered by Piper TTS.

## Features

- 🎯 **High Quality**: Natural-sounding speech with neural TTS
- ⚡ **Lightweight**: No PyTorch dependency (~50MB total)
- 🚀 **Fast**: Real-time generation on CPU
- 🌍 **Multi-language**: English (US/GB), Spanish, French, German, and more
- 🎭 **Multiple Voices**: Male and female voices per language
- 🔄 **Streaming**: Real-time audio streaming support
- 📦 **Multiple Formats**: MP3, WAV, OPUS, FLAC support
- 🔧 **OpenAI Compatible**: Drop-in replacement for OpenAI TTS API

## Why Piper?

Unlike Kokoro which requires PyTorch (~2.6GB), Piper is:
- **Tiny**: Only ~50MB total installation
- **Fast**: Runs efficiently on CPU
- **Simple**: No CUDA or heavy ML frameworks needed
- **Quality**: Excellent voice quality using ONNX models

## Quick Start

### Prerequisites

- Python 3.9+
- No other dependencies needed!

### Installation

1. Navigate to backend directory:
```bash
cd readverse-backend
```

2. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Copy environment file (optional):
```bash
cp .env.example .env
```

5. Run the server:
```bash
python main.py
```

The API will be available at `http://localhost:8880`

## API Documentation

### Interactive Docs
- Swagger UI: http://localhost:8880/docs
- ReDoc: http://localhost:8880/redoc

### Endpoints

#### 1. Generate Speech (OpenAI Compatible)
```bash
POST /v1/audio/speech
```

**Request:**
```json
{
  "model": "piper",
  "input": "Hello world!",
  "voice": "en_US-lessac-medium",
  "response_format": "mp3",
  "speed": 1.0
}
```

**Python Example:**
```python
import requests

response = requests.post(
    "http://localhost:8880/v1/audio/speech",
    json={
        "input": "Hello world!",
        "voice": "en_US-lessac-medium",
        "response_format": "mp3"
    }
)

with open("output.mp3", "wb") as f:
    f.write(response.content)
```

**cURL Example:**
```bash
curl -X POST http://localhost:8880/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input":"Hello world","voice":"en_US-lessac-medium"}' \
  --output speech.mp3
```

#### 2. List Available Voices
```bash
GET /v1/audio/voices
```

**Response:**
```json
{
  "voices": [
    {
      "id": "en_US-lessac-medium",
      "name": "Lessac (US)",
      "language": "en-US",
      "gender": "male",
      "description": "Clear American English male voice"
    }
  ],
  "total": 5
}
```

#### 3. Streaming Support
```python
import requests

response = requests.post(
    "http://localhost:8880/v1/audio/speech",
    json={
        "input": "Hello world!",
        "voice": "en_US-lessac-medium",
        "response_format": "mp3",
        "stream": True
    },
    stream=True
)

with open("output.mp3", "wb") as f:
    for chunk in response.iter_content(chunk_size=1024):
        if chunk:
            f.write(chunk)
```

#### 4. Health Check
```bash
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "1.4.2",
  "model": "Piper TTS",
  "voice": "en_US-lessac-medium"
}
```

## Available Voices

### English (US)
- `en_US-lessac-medium` - Male, clear and professional
- `en_US-amy-medium` - Female, natural and friendly
- `en_US-ryan-medium` - Male, authoritative

### English (GB)
- `en_GB-alan-medium` - Male, British accent
- `en_GB-alba-medium` - Female, British accent

See full list: http://localhost:8880/v1/audio/voices

**Note**: Voice models are downloaded automatically on first use (~10-15MB per voice).

## Configuration

Edit `.env` file to customize:

```env
# Server
HOST=0.0.0.0
PORT=8880
LOG_LEVEL=INFO

# TTS
DEFAULT_VOICE=en_US-lessac-medium
DEFAULT_FORMAT=mp3
SAMPLE_RATE=22050

# Performance
ENABLE_STREAMING=true
CHUNK_SIZE=1024
```

## Performance

- **Speed**: Real-time on modern CPUs
- **Latency**: ~100-500ms first token
- **Memory**: ~100MB RAM per request
- **Quality**: High-quality neural TTS

## Integration with Flutter App

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class TTSService {
  final String baseUrl = 'http://your-server:8880';
  
  Future<Uint8List> generateSpeech({
    required String text,
    String voice = 'en_US-lessac-medium',
    String format = 'mp3',
    double speed = 1.0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/audio/speech'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': text,
        'voice': voice,
        'response_format': format,
        'speed': speed,
      }),
    );
    
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('TTS generation failed: ${response.body}');
    }
  }
  
  Future<List<Voice>> getVoices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/audio/voices'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['voices'] as List)
          .map((v) => Voice.fromJson(v))
          .toList();
    } else {
      throw Exception('Failed to load voices');
    }
  }
}
```

## Docker Deployment

```bash
# Build and run
docker-compose up --build

# Access API
curl http://localhost:8880/health
```

## Troubleshooting

### Voice model download fails
- Check internet connection
- Models are downloaded from Hugging Face on first use
- Each voice is ~10-15MB

### Slow generation
- Piper is optimized for CPU, should be fast
- Check system resources
- Reduce text length for faster response

### Format conversion not working
- Install ffmpeg: `sudo apt-get install ffmpeg` (Linux)
- Or use WAV format which requires no conversion

## Storage Requirements

- **Application**: ~0.15 MB
- **Python dependencies**: ~50 MB
- **Voice models**: ~10-15 MB per voice
- **Total minimum**: ~75 MB (1 voice)
- **Recommended**: ~200 MB (5 voices)

See [STORAGE_REQUIREMENTS.md](STORAGE_REQUIREMENTS.md) for details.

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment guides including:
- Systemd service setup
- Nginx reverse proxy
- Cloud deployment (AWS, GCP, Azure)
- Docker deployment
- Kubernetes

## API Compatibility

This API is compatible with OpenAI's TTS API format:

```python
# OpenAI format
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8880/v1")

response = client.audio.speech.create(
    model="piper",
    voice="en_US-lessac-medium",
    input="Hello world"
)
```

## License

Apache 2.0 - See LICENSE file

## Credits

- Piper TTS: https://github.com/rhasspy/piper
- Voice models: https://huggingface.co/rhasspy/piper-voices
- FastAPI framework
- ReadVerse team

## Support

- Documentation: http://localhost:8880/docs
- Issues: GitHub Issues
- Piper Documentation: https://github.com/rhasspy/piper
