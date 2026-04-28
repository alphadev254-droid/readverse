# Storage Requirements - ReadVerse Piper TTS Backend

## Complete Storage Breakdown

### 1. Application Code
```
readverse-backend/
├── app/                    ~50 KB
│   ├── __init__.py        ~0.1 KB
│   ├── api.py             ~15 KB
│   ├── config.py          ~3 KB
│   ├── models.py          ~5 KB
│   └── tts_service.py     ~15 KB
├── scripts/               ~15 KB
│   └── test_api.py        ~15 KB
├── main.py                ~1 KB
├── requirements.txt       ~1 KB
├── Dockerfile             ~1 KB
├── docker-compose.yml     ~1 KB
├── .env.example           ~1 KB
├── .gitignore             ~1 KB
├── start.sh               ~1 KB
├── start.bat              ~1 KB
├── README.md              ~20 KB
├── DEPLOYMENT.md          ~25 KB
└── STORAGE_REQUIREMENTS.md ~15 KB
────────────────────────────────────
TOTAL CODE:                ~150 KB (0.15 MB)
```

### 2. Python Dependencies (Virtual Environment)

**Base Installation:**
```
Package                    Size
─────────────────────────────────
fastapi                    ~5 MB
uvicorn                    ~3 MB
pydantic                   ~8 MB
python-multipart           ~1 MB
loguru                     ~0.5 MB
aiofiles                   ~0.2 MB
python-dotenv              ~0.1 MB
numpy                      ~20 MB
pydub                      ~0.5 MB
requests                   ~2 MB
─────────────────────────────────
Subtotal:                  ~40 MB
```

**Piper TTS Dependencies (NO PyTorch!):**
```
Package                    Size
─────────────────────────────────
piper-tts                  ~5 MB
onnxruntime                ~10 MB
phonemizer (optional)      ~2 MB
─────────────────────────────────
Subtotal:                  ~17 MB
```

**Optional Dependencies:**
```
Package                    Size
─────────────────────────────────
gunicorn                   ~1 MB
ffmpeg (system)            ~50 MB
─────────────────────────────────
Subtotal:                  ~51 MB
```

**Total Python Environment:**
- **Minimal**: ~57 MB (without optional)
- **Recommended**: ~108 MB (with ffmpeg)

### 3. Piper Voice Models

**Individual Voice Sizes:**
```
Voice Model                Size
─────────────────────────────────
en_US-lessac-medium       ~10 MB
en_US-amy-medium          ~10 MB
en_US-ryan-medium         ~12 MB
en_GB-alan-medium         ~11 MB
en_GB-alba-medium         ~10 MB
─────────────────────────────────
Per voice average:        ~10-12 MB
```

**Common Configurations:**
```
Configuration              Total Size
─────────────────────────────────
1 voice (minimal)         ~10 MB
3 voices (recommended)    ~32 MB
5 voices (full English)   ~53 MB
10 voices (multi-lang)    ~110 MB
─────────────────────────────────
```

### 4. System Dependencies

**ffmpeg (optional, for format conversion):**
```
Package                    Size
─────────────────────────────────
ffmpeg                    ~50 MB
```

**Note**: Unlike Kokoro, Piper doesn't require espeak-ng or other phoneme libraries.

### 5. Runtime Storage

**Temporary Files:**
```
Directory                  Typical Size
─────────────────────────────────────
temp/                     ~50 MB (varies)
output/                   ~200 MB (varies)
logs/                     ~20 MB (varies)
─────────────────────────────────────
TOTAL RUNTIME:            ~270 MB (varies)
```

**Cache (if enabled):**
```
Redis cache               ~500 MB - 2 GB (configurable)
```

## Total Storage Requirements

### Minimum Installation
```
Component                  Size
─────────────────────────────────
Application code          0.15 MB
Python dependencies       57 MB
Voice models (1 voice)    10 MB
Runtime (minimal)         50 MB
─────────────────────────────────
TOTAL MINIMUM:            ~117 MB (~0.12 GB)
```

### Recommended Installation
```
Component                  Size
─────────────────────────────────
Application code          0.15 MB
Python dependencies       108 MB (with ffmpeg)
Voice models (3 voices)   32 MB
Runtime storage           270 MB
─────────────────────────────────
TOTAL RECOMMENDED:        ~410 MB (~0.4 GB)
```

### Full Installation (5 English voices)
```
Component                  Size
─────────────────────────────────
Application code          0.15 MB
Python dependencies       108 MB
Voice models (5 voices)   53 MB
Runtime storage           270 MB
─────────────────────────────────
TOTAL FULL:               ~431 MB (~0.43 GB)
```

### Production with Cache
```
Component                  Size
─────────────────────────────────
Base installation         431 MB
Redis cache               1 GB
Generated audio archive   2 GB
Logs (30 days)           200 MB
─────────────────────────────────
TOTAL PRODUCTION:         ~3.6 GB
```

## Comparison: Piper vs Kokoro

```
Feature                    Piper          Kokoro
──────────────────────────────────────────────────
Python dependencies       ~57 MB         ~2.6 GB
Model weights             ~10 MB/voice   ~486 MB
System dependencies       None           ~17 MB
Total minimum             ~117 MB        ~3.1 GB
──────────────────────────────────────────────────
Size reduction:           97% smaller!
```

**Piper is 26x smaller than Kokoro!**

## Docker Image Sizes

### Piper Image
```
Layer                      Size
─────────────────────────────────
Base (python:3.11-slim)   150 MB
System packages           20 MB
Python dependencies       57 MB
Application code          0.15 MB
Voice models (3 voices)   32 MB
─────────────────────────────────
TOTAL IMAGE:              ~259 MB (~0.26 GB)
```

### With ffmpeg
```
Layer                      Size
─────────────────────────────────
Base image                259 MB
ffmpeg                    50 MB
─────────────────────────────────
TOTAL IMAGE:              ~309 MB (~0.31 GB)
```

**Comparison:**
- Piper Docker image: ~260 MB
- Kokoro Docker image: ~5.1 GB
- **Piper is 19x smaller!**

## Storage Growth Over Time

### Daily Usage (1000 requests/day)
```
Metric                     Size/Day
─────────────────────────────────
Generated audio (cached)  ~300 MB
Logs                      ~10 MB
Temp files (cleaned)      ~0 MB
─────────────────────────────────
DAILY GROWTH:             ~310 MB
```

### Monthly Growth
```
Metric                     Size/Month
─────────────────────────────────
Audio cache (if enabled)  ~9 GB
Logs (rotated)           ~200 MB
Backups                  ~500 MB
─────────────────────────────────
MONTHLY GROWTH:           ~9.7 GB
```

## Optimization Strategies

### 1. Minimal Voice Pack
```bash
# Install only 1 voice for testing
# Saves: ~40 MB compared to 5 voices
```

### 2. Disable Caching
```bash
# Don't cache generated audio
# Saves: Variable (0-10 GB)
```

### 3. Log Rotation
```bash
# Rotate logs daily, keep 7 days
# Limits log size to ~70 MB
```

### 4. Cleanup Script
```bash
# Auto-delete temp files older than 1 hour
# Auto-delete output files older than 24 hours
# Keeps runtime storage under 100 MB
```

### 5. Use WAV Format
```bash
# Skip format conversion (no ffmpeg needed)
# Saves: ~50 MB
```

## Recommended Server Specs

### Development
```
Disk Space:    2 GB free
RAM:           2 GB
CPU:           2 cores
```

### Production (Small)
```
Disk Space:    10 GB free
RAM:           4 GB
CPU:           2 cores
```

### Production (Medium)
```
Disk Space:    20 GB free
RAM:           8 GB
CPU:           4 cores
```

### Production (High Traffic)
```
Disk Space:    50 GB free
RAM:           16 GB
CPU:           8 cores
```

**Note**: Piper runs efficiently on CPU, no GPU needed!

## Cloud Storage Costs (Estimated)

### AWS EBS (General Purpose SSD)
```
Storage Type               Cost/Month
─────────────────────────────────────
5 GB (minimum)            $0.50
20 GB (recommended)       $2.00
50 GB (production)        $5.00
```

### Google Cloud Persistent Disk
```
Storage Type               Cost/Month
─────────────────────────────────────
5 GB (minimum)            $0.20
20 GB (recommended)       $0.80
50 GB (production)        $2.00
```

### Azure Managed Disk
```
Storage Type               Cost/Month
─────────────────────────────────────
5 GB (minimum)            $0.30
20 GB (recommended)       $1.20
50 GB (production)        $3.00
```

## Summary

### Quick Reference
```
Scenario                   Disk Space Needed
──────────────────────────────────────────────
Minimal (1 voice)         120 MB
Recommended (3 voices)    500 MB
Production (5 voices)     5 GB
High-traffic (cache)      20 GB
```

### Installation Command Impact
```bash
# Minimal installation
pip install piper-tts
# Downloads: ~17 MB

# Full installation
pip install -r requirements.txt
# Downloads: ~108 MB

# Docker pull
docker pull readverse-tts:piper
# Downloads: ~260 MB
```

## Cleanup Commands

### Manual Cleanup
```bash
# Remove temporary files
rm -rf temp/*

# Remove old output files
find output/ -type f -mtime +1 -delete

# Clear logs older than 7 days
find logs/ -type f -mtime +7 -delete

# Clear pip cache
pip cache purge
```

### Automated Cleanup Script
```bash
#!/bin/bash
# cleanup.sh - Run daily via cron

# Remove temp files older than 1 hour
find temp/ -type f -mmin +60 -delete

# Remove output files older than 24 hours
find output/ -type f -mtime +1 -delete

# Rotate logs
find logs/ -type f -mtime +7 -delete

# Clear model cache if over 500MB
du -sm models/ | awk '{if($1 > 500) system("rm -rf models/cache/*")}'

echo "Cleanup completed: $(date)"
```

## Monitoring Storage

### Check Current Usage
```bash
# Total backend directory size
du -sh readverse-backend/

# Breakdown by directory
du -h --max-depth=1 readverse-backend/

# Voice models size
du -sh readverse-backend/models/

# Runtime storage
du -sh readverse-backend/{temp,output,logs}/

# Docker image size
docker images | grep readverse-tts
```

### Set Up Alerts
```bash
# Alert if disk usage > 80%
df -h | awk '$5 > 80 {print "WARNING: Disk usage high on " $6}'

# Alert if models directory > 200MB
du -sm models/ | awk '$1 > 200 {print "WARNING: Models directory over 200MB"}'
```

## Voice Model Management

### Download Specific Voice
```python
# Voice is auto-downloaded on first use
# Or manually download:
from piper import PiperVoice

voice = PiperVoice.load("models/en_US-lessac-medium.onnx")
# Downloads ~10MB
```

### List Downloaded Voices
```bash
ls -lh models/*.onnx
```

### Remove Unused Voices
```bash
# Remove specific voice
rm models/en_US-amy-medium.onnx*

# Keep only 1 voice
cd models/
ls | grep -v "en_US-lessac-medium" | xargs rm
```

---

## Bottom Line

**Piper TTS Storage Requirements:**
- **Minimum**: 120 MB (1 voice, no extras)
- **Recommended**: 500 MB (3 voices, with ffmpeg)
- **Production**: 5 GB (with cache and logs)
- **High-traffic**: 20 GB (with extensive caching)

**Key Advantages:**
- ✅ **97% smaller** than Kokoro
- ✅ No PyTorch dependency
- ✅ No GPU required
- ✅ Fast installation
- ✅ Low memory footprint
- ✅ Perfect for embedded/edge devices

**Piper is the ideal choice for lightweight, production-ready TTS!**
