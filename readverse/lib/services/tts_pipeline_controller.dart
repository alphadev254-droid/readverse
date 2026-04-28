import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/tts_chunk.dart';
import 'http_chunk_fetcher.dart';
import 'audio_chunk_queue.dart';

enum TtsPipelineState {
  idle,
  loading,      // First chunk fetching
  buffering,    // First chunk received, waiting for more
  playing,      // 2+ chunks ready, audio started
  paused,
  error,
  completed,
}

/// Orchestrates the entire TTS streaming pipeline
class TtsPipelineController {
  final String baseUrl;
  
  HttpChunkFetcher? _fetcher;
  AudioChunkQueue? _queue;
  StreamSubscription<TtsChunk>? _fetchSubscription;
  StreamSubscription<String>? _textSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _loadingTimeout;  // Timeout for first chunk after connection confirmed
  
  TtsPipelineState _state = TtsPipelineState.idle;
  String _errorMessage = '';
  String _currentText = '';
  int _totalChunks = 0;
  int _bufferedChunks = 0;
  
  final StreamController<TtsPipelineState> _stateController = 
      StreamController<TtsPipelineState>.broadcast();
  final StreamController<String> _textController = 
      StreamController<String>.broadcast();
  final StreamController<double> _progressController = 
      StreamController<double>.broadcast();

  TtsPipelineController({required this.baseUrl});

  // Getters
  TtsPipelineState get state => _state;
  String get errorMessage => _errorMessage;
  String get currentText => _currentText;
  int get totalChunks => _totalChunks;
  int get bufferedChunks => _bufferedChunks;
  int get currentIndex => _queue?.currentIndex ?? 0;
  double get speed => _queue?.speed ?? 1.0;
  
  // Streams
  Stream<TtsPipelineState> get stateStream => _stateController.stream;
  Stream<String> get textStream => _textController.stream;
  Stream<double> get progressStream => _progressController.stream;
  Stream<int> get indexStream => _queue?.chunkIndexStream ?? const Stream.empty();

  /// Start streaming TTS
  Future<void> start({
    required String text,
    required String voiceId,
    double speed = 1.0,
  }) async {
    // Re-entry guard: stop any existing pipeline first
    await stop();
    
    try {
      debugPrint('[TtsPipeline] Starting: ${text.length} chars, voice=$voiceId');
      
      _setState(TtsPipelineState.loading);
      
      // Initialize components
      _fetcher = HttpChunkFetcher(baseUrl: baseUrl);
      _queue = AudioChunkQueue(maxQueueSize: 10, minBufferSize: 1);  // Start immediately
      
      await _queue!.initialize();
      await _queue!.setSpeed(speed);
      
      // Wire queue streams to provider state BEFORE fetching
      _textSubscription = _queue!.currentTextStream.listen((text) {
        debugPrint('[TtsPipeline] *** TEXT RECEIVED: "${text.substring(0, text.length > 50 ? 50 : text.length)}..." ***');
        _currentText = text;
        _textController.add(text);
      });
      
      // Listen to player state for completion
      _playerStateSubscription = _queue!.playerStateStream.listen((playerState) {
        // Transition to playing from loading OR buffering (handles minBufferSize=1 race)
        if (playerState.playing && 
            (_state == TtsPipelineState.buffering || _state == TtsPipelineState.loading)) {
          _setState(TtsPipelineState.playing);
        }
        
        // Only detect completion if we were actually playing AND have buffered chunks
        // (avoid false completion on initial empty playlist)
        if (playerState.processingState == ProcessingState.completed && 
            (_state == TtsPipelineState.playing || _state == TtsPipelineState.paused) &&
            _bufferedChunks > 0) {
          _setState(TtsPipelineState.completed);
          debugPrint('[TtsPipeline] Audio playback completed');
        }
      });
      
      // Start fetching chunks
      final chunkStream = _fetcher!.fetchChunks(
        text: text,
        voiceId: voiceId,
        speed: speed,
        onConnected: _startLoadingTimeout,  // Start timeout AFTER HTTP 200
      );
      
      _fetchSubscription = chunkStream.listen(
        (chunk) async {
          await _onChunkReceived(chunk);
        },
        onError: (error) {
          debugPrint('[TtsPipeline] Fetch error: $error');
          _setState(TtsPipelineState.error);
          _errorMessage = error.toString();
        },
        onDone: () {
          debugPrint('[TtsPipeline] All chunks fetched');
          // If isLast never arrived, treat buffered count as total
          if (_totalChunks == 0 && _bufferedChunks > 0) {
            debugPrint('[TtsPipeline] isLast chunk never arrived, using buffered count as total');
            _totalChunks = _bufferedChunks;
            _progressController.add(1.0);
          }
        },
        cancelOnError: false,
      );
      
    } catch (e) {
      debugPrint('[TtsPipeline] Start error: $e');
      _setState(TtsPipelineState.error);
      _errorMessage = e.toString();
    }
  }

  /// Start loading timeout after HTTP connection confirmed
  /// Gives server 45 seconds to generate and send first chunk
  void _startLoadingTimeout() {
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 45), () async {
      if (_state == TtsPipelineState.loading || _state == TtsPipelineState.buffering) {
        debugPrint('[TtsPipeline] Loading timeout - server took too long to respond');
        _errorMessage = 'Server took too long to respond';
        await stop();  // Kill everything
        _setState(TtsPipelineState.error);  // Override idle state from stop()
      }
    });
    debugPrint('[TtsPipeline] Loading timeout started (45s)');
  }

  /// Handle received chunk
  Future<void> _onChunkReceived(TtsChunk chunk) async {
    try {
      // Cancel loading timeout on first chunk
      _loadingTimeout?.cancel();
      _loadingTimeout = null;
      
      _bufferedChunks++;
      
      if (chunk.isLast) {
        _totalChunks = chunk.index + 1;
      }
      
      // Add to queue
      await _queue!.addChunk(chunk);
      
      // Recover from loading OR error state on first chunk
      if ((_state == TtsPipelineState.loading || _state == TtsPipelineState.error) 
          && _bufferedChunks == 1) {
        _setState(TtsPipelineState.buffering);
      }
      
      // Update progress
      if (_totalChunks > 0) {
        final progress = _bufferedChunks / _totalChunks;
        _progressController.add(progress);
      }
      
      debugPrint('[TtsPipeline] Chunk ${chunk.index} received, buffered: $_bufferedChunks/$_totalChunks');
      
    } catch (e) {
      debugPrint('[TtsPipeline] Error handling chunk: $e');
    }
  }

  /// Play
  Future<void> play() async {
    if (_queue != null && _state == TtsPipelineState.paused) {
      _setState(TtsPipelineState.playing);  // Optimistic update - UI responds instantly
      await _queue!.play();
    }
  }

  /// Pause
  Future<void> pause() async {
    if (_queue != null && _state == TtsPipelineState.playing) {
      _setState(TtsPipelineState.paused);  // Optimistic update - UI responds instantly
      await _queue!.pause();
    }
  }

  /// Stop
  Future<void> stop() async {
    debugPrint('[TtsPipeline] Stopping');
    
    // Set idle state FIRST - UI hides immediately
    _setState(TtsPipelineState.idle);
    
    // Clear state immediately for instant UI update
    _currentText = '';
    _totalChunks = 0;
    _bufferedChunks = 0;
    
    // Cancel loading timeout synchronously
    _loadingTimeout?.cancel();
    _loadingTimeout = null;
    
    // Cancel fetcher synchronously
    _fetcher?.cancel();
    
    // Cancel subscriptions IMMEDIATELY
    await _textSubscription?.cancel();
    _textSubscription = null;
    
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    
    await _fetchSubscription?.cancel();
    _fetchSubscription = null;
    
    // Capture references for async cleanup
    final queue = _queue;
    
    // Clear references immediately
    _fetcher = null;
    _queue = null;
    
    // Do audio cleanup asynchronously (fire-and-forget)
    // This allows the method to return immediately while cleanup happens in background
    if (queue != null) {
      _cleanupAudioAsync(queue);
    }
  }
  
  /// Async audio cleanup helper - runs in background after stop() returns
  Future<void> _cleanupAudioAsync(AudioChunkQueue queue) async {
    try {
      await queue.stop();
      queue.dispose();
      debugPrint('[TtsPipeline] Async audio cleanup completed');
    } catch (e) {
      debugPrint('[TtsPipeline] Audio cleanup error (non-fatal): $e');
    }
  }

  /// Seek to chunk
  Future<void> seekToChunk(int index) async {
    if (_queue != null) {
      await _queue!.seekToChunk(index);
    }
  }

  /// Set speed
  Future<void> setSpeed(double speed) async {
    if (_queue != null) {
      await _queue!.setSpeed(speed);
    }
  }

  /// Skip forward
  Future<void> skipForward() async {
    if (_queue == null) return;
    // Use buffered chunks as fallback until isLast arrives
    final maxKnown = _totalChunks > 0 ? _totalChunks - 1 : _bufferedChunks - 1;
    final nextIndex = (_queue!.currentIndex + 1).clamp(0, maxKnown);
    await seekToChunk(nextIndex);
  }

  /// Skip backward
  Future<void> skipBackward() async {
    if (_queue == null) return;
    final prevIndex = (_queue!.currentIndex - 1).clamp(0, _totalChunks > 0 ? _totalChunks - 1 : _bufferedChunks - 1);
    await seekToChunk(prevIndex);
  }

  /// Set state and notify
  void _setState(TtsPipelineState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      debugPrint('[TtsPipeline] State: $newState');
    }
  }

  /// Dispose
  void dispose() {
    debugPrint('[TtsPipeline] Disposing');
    
    // Defensive: Set idle state if not already idle
    // This ensures UI gets the signal even if dispose() is called without stop()
    if (_state != TtsPipelineState.idle) {
      _setState(TtsPipelineState.idle);
    }
    
    // Cancel loading timeout
    _loadingTimeout?.cancel();
    _loadingTimeout = null;
    
    // Cancel fetcher
    _fetcher?.cancel();
    _fetcher = null;
    
    // Cancel all subscriptions BEFORE closing stream controllers
    _fetchSubscription?.cancel();
    _fetchSubscription = null;
    
    _textSubscription?.cancel();
    _textSubscription = null;
    
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    
    // Stop and dispose queue
    if (_queue != null) {
      _queue!.stop().then((_) => _queue?.dispose());
      _queue = null;
    }
    
    // Close stream controllers AFTER a small delay to ensure idle state propagates
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_stateController.isClosed) _stateController.close();
      if (!_textController.isClosed) _textController.close();
      if (!_progressController.isClosed) _progressController.close();
    });
    
    debugPrint('[TtsPipeline] Disposed');
  }
}
