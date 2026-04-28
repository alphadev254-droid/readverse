# Quick Start Guide - Piper TTS Backend

## 🚀 Get Started in 3 Minutes

### 1. Install (1 minute)

```bash
cd readverse-backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

**That's it!** Only ~60MB download, no PyTorch, no CUDA, no espeak-ng needed.

### 2. Run (30 seconds)

```bash
python main.py
```

Server starts at `http://localhost:8880`

### 3. Test (30 seconds)

```bash
# In another terminal
curl -X POST http://localhost:8880/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input":"Hello world","voice":"en_US-lessac-medium"}' \
  --output test.mp3

# Play the audio
# Linux: mpg123 test.mp3
# macOS: afplay test.mp3
# Windows: start test.mp3
```

## 📝 Basic Usage

### Python

```python
import requests

response = requests.post(
    "http://localhost:8880/v1/audio/speech",
    json={
        "input": "Hello from Piper TTS!",
        "voice": "en_US-lessac-medium",
        "response_format": "mp3",
        "speed": 1.0
    }
)

with open("output.mp3", "wb") as f:
    f.write(response.content)
```

### cURL

```bash
curl -X POST http://localhost:8880/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "input": "Hello from Piper TTS!",
    "voice": "en_US-lessac-medium",
    "response_format": "mp3",
    "speed": 1.0
  }' \
  --output output.mp3
```

### JavaScript/Node.js

```javascript
const response = await fetch('http://localhost:8880/v1/audio/speech', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    input: 'Hello from Piper TTS!',
    voice: 'en_US-lessac-medium',
    response_format: 'mp3',
    speed: 1.0
  })
});

const audioBuffer = await response.arrayBuffer();
// Save or play audioBuffer
```

## 🎭 Available Voices

```bash
# List all voices
curl http://localhost:8880/v1/audio/voices
```

**Quick Reference:**
- `en_US-lessac-medium` - Male US (clear, professional)
- `en_US-amy-medium` - Female US (natural, friendly)
- `en_US-ryan-medium` - Male US (authoritative)
- `en_GB-alan-medium` - Male GB (British accent)
- `en_GB-alba-medium` - Female GB (British accent)

**Note**: Voice models (~10-15MB each) download automatically on first use.

## ⚙️ Common Options

### Speed Control

```python
# Slower (0.5x)
{"speed": 0.5}

# Normal (1.0x)
{"speed": 1.0}

# Faster (1.5x)
{"speed": 1.5}

# Very fast (2.0x)
{"speed": 2.0}
```

### Output Formats

```python
# MP3 (compressed, small)
{"response_format": "mp3"}

# WAV (uncompressed, large, no conversion needed)
{"response_format": "wav"}

# OPUS (compressed, good for streaming)
{"response_format": "opus"}

# FLAC (lossless compression)
{"response_format": "flac"}
```

### Streaming

```python
response = requests.post(
    url,
    json={"input": text, "stream": True},
    stream=True
)

for chunk in response.iter_content(chunk_size=1024):
    # Process chunk in real-time
    pass
```

## 🐳 Docker (Optional)

```bash
# Build
docker-compose build

# Run
docker-compose up

# Test
curl http://localhost:8880/health
```

## 🔧 Configuration

Create `.env` file:

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
```

## 📊 Health Check

```bash
curl http://localhost:8880/health
```

Response:
```json
{
  "status": "healthy",
  "version": "1.4.2",
  "model": "Piper TTS",
  "voice": "en_US-lessac-medium"
}
```

## 🎯 Integration Examples

### Flutter/Dart

```dart
final response = await http.post(
  Uri.parse('http://localhost:8880/v1/audio/speech'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'input': 'Hello world',
    'voice': 'en_US-lessac-medium',
    'response_format': 'mp3',
  }),
);

final audioBytes = response.bodyBytes;
```

### React/TypeScript

```typescript
const generateSpeech = async (text: string) => {
  const response = await fetch('http://localhost:8880/v1/audio/speech', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      input: text,
      voice: 'en_US-lessac-medium',
      response_format: 'mp3',
    }),
  });
  
  const blob = await response.blob();
  const audio = new Audio(URL.createObjectURL(blob));
  audio.play();
};
```

## 🐛 Troubleshooting

### Server won't start
```bash
# Check if port is in use
lsof -i :8880  # Linux/macOS
netstat -ano | findstr :8880  # Windows

# Use different port
PORT=8881 python main.py
```

### Voice download fails
```bash
# Check internet connection
# Models download from Hugging Face
# Each voice is ~10-15MB
```

### Format conversion not working
```bash
# Install ffmpeg (optional)
sudo apt-get install ffmpeg  # Linux
brew install ffmpeg          # macOS

# Or use WAV format (no conversion needed)
{"response_format": "wav"}
```

### Slow generation
```bash
# Piper is optimized for CPU
# Check system resources
htop  # Linux/macOS
taskmgr  # Windows

# Reduce text length for faster response
```

## 📚 More Information

- **Full Documentation**: [README.md](README.md)
- **Deployment Guide**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **Storage Requirements**: [STORAGE_REQUIREMENTS.md](STORAGE_REQUIREMENTS.md)
- **API Docs**: http://localhost:8880/docs
- **Piper GitHub**: https://github.com/rhasspy/piper

## 💡 Tips

1. **Use WAV format** if you don't need compression (fastest, no conversion)
2. **Enable streaming** for better perceived performance
3. **Cache audio** for repeated texts
4. **Use multiple workers** for high traffic: `gunicorn -w 4 ...`
5. **Monitor health** endpoint for uptime checks

## 🎉 That's It!

You now have a lightweight, production-ready TTS API running in under 3 minutes!

**Total size**: ~120MB (vs 3.1GB for Kokoro)
**Installation time**: <1 minute (vs 5-10 minutes)
**Memory usage**: ~100MB per request (vs 2GB)

Enjoy! 🚀
