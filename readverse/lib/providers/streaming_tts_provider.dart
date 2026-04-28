import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tts_pipeline_controller.dart';
import '../services/online_tts_service.dart';

/// Provider for streaming TTS using production pipeline architecture
class StreamingTtsProvider with ChangeNotifier {
  TtsPipelineController? _pipeline;
  final OnlineTtsService _ttsService = OnlineTtsService();

  // State
  String _docId = '';
  String _docTitle = '';
  String _voiceId = 'en_US-lessac-high';
  double _speed = 1.0;
  
  // Current playback info
  String _currentText = '';
  int _currentIndex = 0;
  int _totalChunks = 0;
  int _bufferedChunks = 0;
  double _progress = 0.0;
  
  TtsPipelineState _state = TtsPipelineState.idle;
  String _errorMessage = '';

  // Getters
  bool get isActive => _state != TtsPipelineState.idle;
  bool get isPlaying => _state == TtsPipelineState.playing;
  bool get isPaused => _state == TtsPipelineState.paused;
  bool get isLoading => _state == TtsPipelineState.loading;
  bool get isBuffering => _state == TtsPipelineState.buffering;
  bool get isError => _state == TtsPipelineState.error;
  bool get isCompleted => _state == TtsPipelineState.completed;
  
  String get docId => _docId;
  String get docTitle => _docTitle;
  String get voiceId => _voiceId;
  double get speed => _speed;
  String get currentText => _currentText;
  int get currentIndex => _currentIndex;
  int get totalChunks => _totalChunks;
  int get bufferedChunks => _bufferedChunks;
  double get progress => _progress;
  TtsPipelineState get state => _state;
  String get errorMessage => _errorMessage;

  /// Initialize and start streaming
  Future<void> initialize({
    required String docId,
    required String docTitle,
    required String fullText,
    required String voiceId,
    double speed = 1.0,
  }) async {
    try {
      debugPrint('[StreamingTTS] Initializing: docId=$docId, voice=$voiceId');
      
      _docId = docId;
      _docTitle = docTitle;
      _voiceId = voiceId;
      _speed = speed;
      
      // Check backend health
      final isHealthy = await _ttsService.checkHealth();
      if (!isHealthy) {
        throw Exception('Backend is not available. Please ensure the Piper TTS server is running.');
      }
      
      // Create pipeline
      _pipeline = TtsPipelineController(baseUrl: _ttsService.baseUrl);
      
      // Listen to state changes
      _pipeline!.stateStream.listen((state) {
        debugPrint('[StreamingTTS] *** STATE CHANGED: $state ***');
        _state = state;
        _autoSaveState();
        notifyListeners();
      });
      
      // Listen to text changes
      _pipeline!.textStream.listen((text) {
        debugPrint('[StreamingTTS] *** PROVIDER RECEIVED TEXT: "${text.substring(0, text.length > 50 ? 50 : text.length)}..." ***');
        _currentText = text;
        notifyListeners();
      });
      
      // Listen to chunk index changes (real-time, not just on buffering)
      _pipeline!.indexStream.listen((index) {
        _currentIndex = index;
        notifyListeners();
      });
      
      // Listen to progress
      _pipeline!.progressStream.listen((progress) {
        _progress = progress;
        _bufferedChunks = _pipeline!.bufferedChunks;
        _totalChunks = _pipeline!.totalChunks;
        // currentIndex now comes from indexStream, not here
        notifyListeners();
      });
      
      // Start streaming
      await _pipeline!.start(
        text: fullText,
        voiceId: voiceId,
        speed: speed,
      );
      
      debugPrint('[StreamingTTS] Initialized successfully');
      
    } catch (e) {
      debugPrint('[StreamingTTS] Initialization failed: $e');
      _state = TtsPipelineState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Play
  Future<void> play() async {
    debugPrint('[StreamingTTS] play() called, current state: $_state');
    if (_pipeline != null) {
      await _pipeline!.play();
    }
  }

  /// Pause
  Future<void> pause() async {
    debugPrint('[StreamingTTS] pause() called, current state: $_state');
    if (_pipeline != null) {
      await _pipeline!.pause();
    }
  }

  /// Stop
  Future<void> stop() async {
    // Set idle state FIRST - UI updates immediately
    _state = TtsPipelineState.idle;
    _currentText = '';
    _currentIndex = 0;
    _totalChunks = 0;
    _bufferedChunks = 0;
    _progress = 0.0;
    
    // Notify listeners immediately for instant UI update
    notifyListeners();
    
    // Cleanup in background (non-blocking)
    if (_pipeline != null) {
      final pipeline = _pipeline!;  // Use ! since we just checked null
      _pipeline = null;
      
      // Fire-and-forget cleanup
      pipeline.stop().then((_) {
        pipeline.dispose();
        debugPrint('[StreamingTTS] Pipeline cleanup completed');
      }).catchError((e) {
        debugPrint('[StreamingTTS] Pipeline cleanup error (non-fatal): $e');
      });
    }
    
    // Clear saved state asynchronously
    clearState();
  }

  /// Skip forward
  Future<void> skipForward() async {
    if (_pipeline != null) {
      await _pipeline!.skipForward();
    }
  }

  /// Skip backward
  Future<void> skipBackward() async {
    if (_pipeline != null) {
      await _pipeline!.skipBackward();
    }
  }

  /// Seek to chunk
  Future<void> seekToChunk(int index) async {
    if (_pipeline != null) {
      await _pipeline!.seekToChunk(index);
    }
  }

  /// Set speed
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    if (_pipeline != null) {
      await _pipeline!.setSpeed(_speed);
    }
    _autoSaveState();
    notifyListeners();
  }

  /// Auto-save state
  Future<void> _autoSaveState() async {
    if (!isActive) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('streaming_tts_state', jsonEncode({
        'docId': _docId,
        'docTitle': _docTitle,
        'voiceId': _voiceId,
        'speed': _speed,
        'currentIndex': _currentIndex,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('[StreamingTTS] Failed to save state: $e');
    }
  }

  /// Load saved state
  Future<void> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString('streaming_tts_state');
      
      if (stateJson == null) return;

      final state = jsonDecode(stateJson);
      
      // Check if state is recent (within 24 hours)
      final timestamp = DateTime.parse(state['timestamp']);
      if (DateTime.now().difference(timestamp).inHours > 24) {
        await clearState();
        return;
      }

      _docId = state['docId'];
      _docTitle = state['docTitle'];
      _voiceId = state['voiceId'] ?? 'en_US-lessac-high';
      _speed = state['speed'] ?? 1.0;
      _currentIndex = state['currentIndex'] ?? 0;
      
      debugPrint('[StreamingTTS] Loaded state: docId=$_docId, index=$_currentIndex');
      notifyListeners();
      
    } catch (e) {
      debugPrint('[StreamingTTS] Failed to load state: $e');
      await clearState();
    }
  }

  /// Clear saved state
  Future<void> clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('streaming_tts_state');
    } catch (e) {
      debugPrint('[StreamingTTS] Failed to clear state: $e');
    }
  }

  /// Retry after error
  Future<void> retry() async {
    if (_state == TtsPipelineState.error && _docId.isNotEmpty) {
      // Would need to re-extract text here
      // For now, just clear error
      _state = TtsPipelineState.idle;
      _errorMessage = '';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pipeline?.dispose();
    super.dispose();
  }
}
