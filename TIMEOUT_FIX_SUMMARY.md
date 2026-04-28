# Timeout Fix Summary

## Problem Analysis

The logs showed:
```
[TtsPipeline] Loading timeout - no chunks received
[TtsPipeline] State: TtsPipelineState.error
[HttpChunkFetcher] Chunk 1: ARTIFICIAL INTELLIGENCE...
```

The timeout fired **before** the first chunk arrived, but chunks arrived shortly after and playback worked anyway. This created a zombie pipeline in error state while audio was playing.

## Root Causes

### 1. Timeout started too early
- Timer started immediately when `start()` was called
- Server needs time to:
  - Receive HTTP request
  - Run TTS inference on 7256 characters
  - Generate first WAV frame
  - Send response
- Timeout should start AFTER HTTP 200 confirmed, not before

### 2. Timeout didn't kill the pipeline
- When timeout fired, it only set error state
- `_fetchSubscription` remained alive
- Chunks kept arriving and being processed
- Created zombie pipeline: error state but audio playing

### 3. No recovery from error state
- If state was error when first chunk arrived, buffering transition was skipped
- Pipeline stuck in error state even though data was flowing

## Fixes Applied

### Fix 1: Start timeout after HTTP connection confirmed

**HttpChunkFetcher** (`readverse/lib/services/http_chunk_fetcher.dart`):
```dart
Stream<TtsChunk> fetchChunks({
  required String text,
  required String voiceId,
  double speed = 1.0,
  VoidCallback? onConnected,  // ← Added callback parameter
}) async* {
  // ... HTTP request setup ...
  
  final response = await _client!.send(request).timeout(
    const Duration(seconds: 30),  // HTTP connection timeout
  );
  
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}: Failed to start stream');
  }
  
  // Server confirmed alive and streaming - notify controller
  onConnected?.call();  // ← Fire callback HERE
  
  // ... continue reading chunks ...
}
```

**TtsPipelineController** (`readverse/lib/services/tts_pipeline_controller.dart`):
```dart
// In start() method:
final chunkStream = _fetcher!.fetchChunks(
  text: text,
  voiceId: voiceId,
  speed: speed,
  onConnected: _startLoadingTimeout,  // ← Start timeout AFTER HTTP 200
);
```

### Fix 2: Timeout kills entire pipeline

```dart
void _startLoadingTimeout() {
  _loadingTimeout?.cancel();
  _loadingTimeout = Timer(const Duration(seconds: 45), () async {
    if (_state == TtsPipelineState.loading || _state == TtsPipelineState.buffering) {
      debugPrint('[TtsPipeline] Loading timeout - server took too long');
      _errorMessage = 'Server took too long to respond';
      await stop();  // ← Kill everything: subscriptions, fetcher, queue
      _setState(TtsPipelineState.error);  // ← Override idle state from stop()
    }
  });
  debugPrint('[TtsPipeline] Loading timeout started (45s)');
}
```

**Why 45 seconds?**
- HTTP connection timeout: 30 seconds (in HttpChunkFetcher)
- First chunk generation: up to 15 seconds for large documents
- Total: 45 seconds is generous but not infinite

### Fix 3: Recover from error state

```dart
Future<void> _onChunkReceived(TtsChunk chunk) async {
  try {
    // Cancel loading timeout on first chunk
    _loadingTimeout?.cancel();
    _loadingTimeout = null;
    
    _bufferedChunks++;
    
    if (chunk.isLast) {
      _totalChunks = chunk.index + 1;
    }
    
    await _queue!.addChunk(chunk);
    
    // Recover from loading OR error state on first chunk
    // (handles transient network hiccups that resolve)
    if ((_state == TtsPipelineState.loading || _state == TtsPipelineState.error) 
        && _bufferedChunks == 1) {
      _setState(TtsPipelineState.buffering);  // ← Recover from error
    }
    
    // ... rest of method ...
  }
}
```

### Fix 4: Proper cleanup

```dart
// In stop():
_loadingTimeout?.cancel();
_loadingTimeout = null;

// In dispose():
_loadingTimeout?.cancel();
// ... other cleanup ...
_loadingTimeout = null;
```

## Timeline Comparison

### Before (Broken)
```
T+0ms:    start() called
T+0ms:    Timer started (15 seconds)
T+100ms:  HTTP request sent
T+500ms:  HTTP 200 received
T+5000ms: Backend generating audio...
T+15000ms: ⚠️ TIMEOUT FIRES → error state
T+16000ms: First chunk arrives
T+16001ms: Chunk processed (zombie pipeline)
T+16002ms: Audio plays (but UI shows error)
```

### After (Fixed)
```
T+0ms:    start() called
T+100ms:  HTTP request sent
T+500ms:  HTTP 200 received
T+500ms:  ✅ Timer started (45 seconds)
T+5000ms: Backend generating audio...
T+16000ms: First chunk arrives
T+16001ms: ✅ Timer cancelled
T+16002ms: State → buffering
T+16003ms: Audio plays normally
```

## Benefits

1. **No false positives** - Timeout only fires if server is truly unresponsive
2. **Generous time window** - 45 seconds allows for slow networks and large documents
3. **Clean failure** - Timeout kills entire pipeline, no zombie state
4. **Recovery** - Can recover from transient errors if chunks arrive
5. **Two-layer timeout**:
   - HTTP layer (30s): Catches connection issues
   - First chunk layer (45s): Catches slow generation

## Testing

Test these scenarios:

1. **Normal operation** - Timeout should never fire
2. **Slow network** - Should work as long as chunks arrive within 45s
3. **Backend down** - HTTP timeout (30s) should trigger error
4. **Backend stalled** - First chunk timeout (45s) should trigger error
5. **Large document** - Should work even if first chunk takes 20-30 seconds
6. **Transient error** - If error state but chunks arrive, should recover

## Files Modified

1. `readverse/lib/services/http_chunk_fetcher.dart` - Added onConnected callback
2. `readverse/lib/services/tts_pipeline_controller.dart` - Implemented all 4 fixes

## Status

✅ All fixes implemented and ready for testing
