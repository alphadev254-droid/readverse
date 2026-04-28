# ReadVerse Piper TTS Backend - Deployment Guide

## Quick Start

### Local Development

1. **Install Prerequisites**:
   ```bash
   # Python 3.9+
   python --version
   
   # Optional: ffmpeg for format conversion
   # Ubuntu/Debian:
   sudo apt-get install ffmpeg
   
   # macOS:
   brew install ffmpeg
   
   # Windows: Download from
   # https://ffmpeg.org/download.html
   ```

2. **Setup**:
   ```bash
   # Linux/macOS
   chmod +x start.sh
   ./start.sh
   
   # Windows
   start.bat
   ```

3. **Test**:
   ```bash
   # In another terminal
   python scripts/test_api.py
   ```

### Docker Deployment

1. **Build and Run**:
   ```bash
   docker-compose up --build
   ```

2. **Access**:
   - API: http://localhost:8880
   - Docs: http://localhost:8880/docs

### Production Deployment

#### Option 1: Systemd Service (Linux)

1. Create service file `/etc/systemd/system/readverse-tts.service`:
   ```ini
   [Unit]
   Description=ReadVerse Piper TTS API
   After=network.target

   [Service]
   Type=simple
   User=www-data
   WorkingDirectory=/opt/readverse-tts
   Environment="PATH=/opt/readverse-tts/venv/bin"
   ExecStart=/opt/readverse-tts/venv/bin/python main.py
   Restart=always
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

2. Enable and start:
   ```bash
   sudo systemctl enable readverse-tts
   sudo systemctl start readverse-tts
   sudo systemctl status readverse-tts
   ```

#### Option 2: Nginx Reverse Proxy

1. Install Nginx:
   ```bash
   sudo apt-get install nginx
   ```

2. Create config `/etc/nginx/sites-available/readverse-tts`:
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;

       location / {
           proxy_pass http://localhost:8880;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
           
           # For streaming
           proxy_buffering off;
           proxy_cache off;
       }
   }
   ```

3. Enable and restart:
   ```bash
   sudo ln -s /etc/nginx/sites-available/readverse-tts /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

#### Option 3: Cloud Deployment

**AWS EC2:**
```bash
# Launch Ubuntu instance
# Install dependencies
sudo apt-get update
sudo apt-get install python3-pip ffmpeg

# Clone and setup
git clone <your-repo>
cd readverse-backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run with gunicorn
gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.api:app --bind 0.0.0.0:8880
```

**Google Cloud Run:**
```bash
# Build and deploy
gcloud builds submit --tag gcr.io/PROJECT-ID/readverse-tts
gcloud run deploy readverse-tts \
  --image gcr.io/PROJECT-ID/readverse-tts \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

**Heroku:**
```bash
# Create Procfile
echo "web: python main.py" > Procfile

# Deploy
heroku create readverse-tts
git push heroku main
```

## Performance Optimization

### CPU Optimization

Piper is optimized for CPU and doesn't require GPU:

```bash
# Check CPU cores
nproc

# Run with multiple workers (1 per core)
gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.api:app
```

### Load Balancing

For high traffic, use multiple workers:

```bash
# Gunicorn with multiple workers
gunicorn -w 4 -k uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8880 \
  --timeout 120 \
  --worker-class uvicorn.workers.UvicornWorker \
  app.api:app
```

### Caching

Enable Redis caching for repeated requests:

```python
# Add to .env
CACHE_ENABLED=true
REDIS_URL=redis://localhost:6379
```

## Monitoring

### Health Checks

```bash
# Simple health check
curl http://localhost:8880/health

# Detailed monitoring
curl http://localhost:8880/health | jq
```

### Logging

Logs are output to stderr. Capture with:

```bash
# Systemd
sudo journalctl -u readverse-tts -f

# Docker
docker logs -f readverse-tts

# File logging
python main.py 2>&1 | tee logs/app.log
```

### Metrics

Add Prometheus metrics:

```python
# Install
pip install prometheus-fastapi-instrumentator

# Add to app.api.py
from prometheus_fastapi_instrumentator import Instrumentator

Instrumentator().instrument(app).expose(app)
```

## Security

### API Key Authentication

Add to `app/api.py`:

```python
from fastapi.security import APIKeyHeader

API_KEY = os.getenv("API_KEY", "your-secret-key")
api_key_header = APIKeyHeader(name="X-API-Key")

async def verify_api_key(api_key: str = Depends(api_key_header)):
    if api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API key")
    return api_key

# Add to endpoints
@app.post("/v1/audio/speech", dependencies=[Depends(verify_api_key)])
```

### HTTPS

Use Let's Encrypt with Nginx:

```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### Rate Limiting

Add rate limiting:

```python
# Install
pip install slowapi

# Add to app
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.post("/v1/audio/speech")
@limiter.limit("10/minute")
async def generate_speech(request: Request, tts_request: TTSRequest):
    ...
```

## Troubleshooting

### Common Issues

1. **Voice model download fails**:
   ```bash
   # Check internet connection
   # Models download from Hugging Face on first use
   # Each voice is ~10-15MB
   ```

2. **Format conversion not working**:
   - Install ffmpeg: `sudo apt-get install ffmpeg`
   - Or use WAV format (no conversion needed)

3. **Slow generation**:
   - Piper is optimized for CPU
   - Check system resources
   - Reduce text length

4. **Port already in use**:
   ```bash
   # Change port in .env
   PORT=8881
   ```

### Debug Mode

Enable debug logging:

```bash
# In .env
LOG_LEVEL=DEBUG

# Or environment variable
export LOG_LEVEL=DEBUG
python main.py
```

## Backup and Recovery

### Backup Models

```bash
# Backup voice models directory
tar -czf models-backup.tar.gz models/

# Restore
tar -xzf models-backup.tar.gz
```

### Database Backup

If using database for caching:

```bash
# PostgreSQL
pg_dump readverse_tts > backup.sql

# Restore
psql readverse_tts < backup.sql
```

## Scaling

### Horizontal Scaling

Use load balancer with multiple instances:

```nginx
upstream tts_backend {
    server 10.0.1.1:8880;
    server 10.0.1.2:8880;
    server 10.0.1.3:8880;
}

server {
    location / {
        proxy_pass http://tts_backend;
    }
}
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: readverse-tts
spec:
  replicas: 3
  selector:
    matchLabels:
      app: readverse-tts
  template:
    metadata:
      labels:
        app: readverse-tts
    spec:
      containers:
      - name: tts-api
        image: readverse-tts:latest
        ports:
        - containerPort: 8880
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
```

## Support

For issues and questions:
- GitHub Issues: [your-repo]/issues
- Documentation: http://localhost:8880/docs
- Email: support@readverse.com
