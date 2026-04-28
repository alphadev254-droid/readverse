import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/online_tts_service.dart';
import '../services/text_normalizer.dart';

enum OnlineTtsState { idle, loading, playing, paused, error }

/// Provider for online TTS using Piper backend
/// Streams audio sentence-by-sentence with word-by-word highlighting
class OnlineTtsProvider with ChangeNotifier {
  final OnlineTtsService _ttsService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State
  OnlineTtsState _state = OnlineTtsState.idle;
  String _docId = '';
  String _docTitle = '';
  String _voiceId = 'en_US-lessac-high';
  List<String> _sentences = [];
  int _currentIndex = 0;
  double _speed = 1.0;
  String _errorMessage = '';
  
  // Word highlighting
  List<String> _currentWords = [];
  int _currentWordIndex = 0;
  
  // Generation tracking
  bool _isGenerating = false;
  int _generatingIndex = -1;
  
  // Audio cache (optional - cache generated audio)
  final Map<String, Uint8List> _audioCache = {};
  
  // Generation counter for race condition prevention
  int _generationCounter = 0;

  OnlineTtsProvider({OnlineTtsService? ttsService})
      : _ttsService = ttsService ?? OnlineTtsService() {
    _initializePlayer();
    _loadState();
  }

  // Getters
  OnlineTtsState get state => _state;
  bool get isActive => _state != OnlineTtsState.idle;
  bool get isPlaying => _state == OnlineTtsState.playing;
  bool get isPaused => _state == OnlineTtsState.paused;
  bool get isLoading => _state == OnlineTtsState.loading;
  bool get isError => _state == OnlineTtsState.error;
  bool get isGenerating => _isGenerating;
  int get generatingIndex => _generatingIndex;
  String get docId => _docId;
  String get docTitle => _docTitle;
  String get voiceId => _voiceId;
  List<String> get sentences => _sentences;
  int get currentIndex => _currentIndex;
  double get speed => _speed;
  String get errorMessage => _errorMessage;
  List<String> get currentWords => _currentWords;
  int get currentWordIndex => _currentWordIndex;
  
  String get currentSentence =>
      _sentences.isNotEmpty && _currentIndex < _sentences.length
          ? _sentences[_currentIndex]
          : '';

  void _initializePlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onAudioComplete();
      }
    });
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (state.playing && _state == OnlineTtsState.paused) {
      _state = OnlineTtsState.playing;
      _autoSaveState();
      notifyListeners();
    }
  }

  void _onAudioComplete() {
    if (_state == OnlineTtsState.playing) {
      _playNextSentence();
    }
  }

  /// Initialize with document and voice
  Future<void> initialize({
    required String docId,
    required String docTitle,
    required String fullText,
    required String voiceId,
    double speed = 1.0,
  }) async {
    try {
      debugPrint('[OnlineTTS] Initializing: docId=$docId, voice=$voiceId');
      
      _state = OnlineTtsState.loading;
      _docId = docId;
      _docTitle = docTitle;
      _voiceId = voiceId;
      _speed = speed;
      _currentIndex = 0;
      _errorMessage = '';
      _audioCache.clear();
      notifyListeners();

      // Check backend health
      final isHealthy = await _ttsService.checkHealth();
      if (!isHealthy) {
        throw Exception('Backend is not available. Please ensure the Piper TTS server is running.');
      }

      // Normalize and split text in background
      final normalized = await compute(_processTextInBackground, fullText);
      _sentences = normalized;

      if (_sentences.isEmpty) {
        throw Exception('No text to read');
      }

      debugPrint('[OnlineTTS] Initialized with ${_sentences.length} sentences');
      
      _state = OnlineTtsState.paused;
      _autoSaveState();
      notifyListeners();
      
      // Start playing
      await play();
      
    } catch (e) {
      debugPrint('[OnlineTTS] Initialization failed: $e');
      _state = OnlineTtsState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Play from current position
  Future<void> play() async {
    if (_state == OnlineTtsState.idle || _sentences.isEmpty) {
      debugPrint('[OnlineTTS] Cannot play: not initialized');
      return;
    }

    if (_state == OnlineTtsState.playing) {
      debugPrint('[OnlineTTS] Already playing');
      return;
    }

    try {
      _state = OnlineTtsState.playing;
      _errorMessage = '';
      _autoSaveState();
      notifyListeners();

      await _playCurrentSentence();
      
    } catch (e) {
      debugPrint('[OnlineTTS] Play failed: $e');
      _state = OnlineTtsState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Pause playback
  Future<void> pause() async {
    if (_state != OnlineTtsState.playing) return;

    await _audioPlayer.pause();
    _state = OnlineTtsState.paused;
    _autoSaveState();
    notifyListeners();
  }

  /// Resume playback
  Future<void> resume() async {
    if (_state != OnlineTtsState.paused) return;

    await _audioPlayer.play();
    _state = OnlineTtsState.playing;
    _autoSaveState();
    notifyListeners();
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlayer.stop();
    _state = OnlineTtsState.idle;
    _currentIndex = 0;
    _currentWords = [];
    _currentWordIndex = 0;
    _isGenerating = false;
    _generatingIndex = -1;
    _generationCounter++;
    await clearState();
    notifyListeners();
  }

  /// Skip to previous sentence
  Future<void> skipBackward() async {
    if (_currentIndex > 0) {
      await seekToSentence(_currentIndex - 1);
    }
  }

  /// Skip to next sentence
  Future<void> skipForward() async {
    if (_currentIndex < _sentences.length - 1) {
      await seekToSentence(_currentIndex + 1);
    }
  }

  /// Seek to specific sentence
  Future<void> seekToSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;

    await _audioPlayer.stop();
    _currentIndex = index;
    _currentWords = [];
    _currentWordIndex = 0;
    
    if (_state == OnlineTtsState.playing) {
      _autoSaveState();
      notifyListeners();
      await _playCurrentSentence();
    } else {
      _autoSaveState();
      notifyListeners();
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    await _audioPlayer.setSpeed(_speed);
    _autoSaveState();
    notifyListeners();
  }

  /// Play current sentence
  Future<void> _playCurrentSentence() async {
    if (_currentIndex >= _sentences.length) {
      // Reached end
      await stop();
      return;
    }

    final myGeneration = ++_generationCounter;
    final sentence = _sentences[_currentIndex];
    
    try {
      // Parse words for highlighting
      _currentWords = _parseWords(sentence);
      _currentWordIndex = 0;
      notifyListeners();

      // Check cache first
      Uint8List? audioBytes = _audioCache[sentence];
      
      if (audioBytes == null) {
        // Generate audio from backend
        _isGenerating = true;
        _generatingIndex = _currentIndex;
        notifyListeners();

        audioBytes = await _ttsService.generateSpeech(
          text: sentence,
          voiceId: _voiceId,
          speed: _speed,
          format: 'wav', // Use WAV for better compatibility
        );

        if (audioBytes == null) {
          throw Exception('Failed to generate audio');
        }

        // Cache the audio
        _audioCache[sentence] = audioBytes;
        
        _isGenerating = false;
        _generatingIndex = -1;
        notifyListeners();
      }

      // Check if we were cancelled
      if (myGeneration != _generationCounter) {
        debugPrint('[OnlineTTS] Generation cancelled (stale)');
        return;
      }

      // Play the audio
      await _audioPlayer.stop();
      await _audioPlayer.setSpeed(_speed);
      await _audioPlayer.setAudioSource(AudioSource.uri(
        Uri.dataFromBytes(audioBytes, mimeType: 'audio/wav'),
      ));
      await _audioPlayer.play();

      // Start word highlighting
      _highlightWords();
      
    } catch (e) {
      debugPrint('[OnlineTTS] Failed to play sentence: $e');
      _isGenerating = false;
      _generatingIndex = -1;
      
      if (myGeneration == _generationCounter) {
        _state = OnlineTtsState.error;
        _errorMessage = 'Failed to generate audio: $e';
        notifyListeners();
      }
    }
  }

  /// Play next sentence
  Future<void> _playNextSentence() async {
    if (_currentIndex < _sentences.length - 1) {
      _currentIndex++;
      _autoSaveState();
      notifyListeners();
      await _playCurrentSentence();
    } else {
      // Reached end
      await stop();
    }
  }

  /// Parse sentence into words
  List<String> _parseWords(String sentence) {
    return sentence
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Highlight words as they're spoken
  Future<void> _highlightWords() async {
    if (_currentWords.isEmpty) return;

    final duration = _audioPlayer.duration;
    if (duration == null) return;

    final wordDuration = duration ~/ _currentWords.length;

    for (int i = 0; i < _currentWords.length; i++) {
      if (_state != OnlineTtsState.playing) break;
      
      _currentWordIndex = i;
      notifyListeners();
      
      await Future.delayed(wordDuration);
    }
  }

  /// Auto-save state on every change
  Future<void> _autoSaveState() async {
    if (!isActive) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('online_tts_state', jsonEncode({
        'docId': _docId,
        'docTitle': _docTitle,
        'voiceId': _voiceId,
        'sentences': _sentences,
        'currentIndex': _currentIndex,
        'speed': _speed,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('[OnlineTTS] Failed to save state: $e');
    }
  }

  /// Load saved state
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString('online_tts_state');
      
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
      _sentences = List<String>.from(state['sentences']);
      _currentIndex = state['currentIndex'];
      _speed = state['speed'] ?? 1.0;
      _state = OnlineTtsState.paused; // Always restore to paused
      
      debugPrint('[OnlineTTS] Loaded state: ${_sentences.length} sentences, index=$_currentIndex');
      notifyListeners();
      
    } catch (e) {
      debugPrint('[OnlineTTS] Failed to load state: $e');
      await clearState();
    }
  }

  /// Clear saved state
  Future<void> clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('online_tts_state');
    } catch (e) {
      debugPrint('[OnlineTTS] Failed to clear state: $e');
    }
  }

  /// Retry after error
  Future<void> retry() async {
    if (_state != OnlineTtsState.error) return;
    
    _state = OnlineTtsState.paused;
    _errorMessage = '';
    notifyListeners();
    
    await play();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

/// Background text processing
List<String> _processTextInBackground(String text) {
  final normalized = TextNormalizer.normalize(text);
  return _splitIntoSentences(normalized);
}

/// Split text into sentences
List<String> _splitIntoSentences(String text) {
  final sentences = <String>[];
  final regex = RegExp(
    r'[.!?]+(?=\s+[A-Z]|\s*$)',
    multiLine: true,
  );

  int lastEnd = 0;
  for (final match in regex.allMatches(text)) {
    final sentence = text.substring(lastEnd, match.end).trim();
    if (sentence.isNotEmpty) {
      sentences.add(sentence);
    }
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    final remaining = text.substring(lastEnd).trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }
  }

  return _mergeSentences(sentences);
}

/// Merge very short sentences
List<String> _mergeSentences(List<String> sentences) {
  if (sentences.isEmpty) return sentences;

  final merged = <String>[];
  String buffer = sentences[0];

  for (int i = 1; i < sentences.length; i++) {
    final current = sentences[i];
    final words = current.split(RegExp(r'\s+'));

    if (words.length <= 5 && buffer.split(RegExp(r'\s+')).length < 200) {
      buffer += ' $current';
    } else {
      merged.add(buffer);
      buffer = current;
    }
  }

  if (buffer.isNotEmpty) {
    merged.add(buffer);
  }

  return merged;
}
