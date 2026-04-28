import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/text_normalizer.dart';

enum ReadAloudState { idle, playing, paused }

class ReadAloudProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  ReadAloudState _state = ReadAloudState.idle;
  List<String> _sentences = [];
  int _currentIndex = 0;
  String _docId = '';
  String _docTitle = ''; // Track document title for persistence
  double _speed = 0.5; // Default to 0.5x speed (matches UI chip)
  String _language = 'en-US';

  // ── Guards ─────────────────────────────────────────────────────────────

  bool _intentionalStop = false;
  bool _engineReady = false;
  DateTime? _lastSentenceEndTime; // Track timing between sentences

  // FIX: Replace the boolean _isSpeaking flag with a generation counter.
  //
  // The old boolean caused a race on Android:
  //   1. speak(sentenceA) fires → _isSpeaking = true
  //   2. setSpeed/skip calls _stopEngine() → _isSpeaking = false
  //   3. _speakCurrent() called again → _isSpeaking = true
  //   4. Android delivers stale completion for sentenceA
  //      → _onSentenceComplete() runs, sets _isSpeaking = false
  //   5. Real completion for sentenceB fires
  //      → _isSpeaking already false → _speakCurrent() BLOCKED → silence
  //
  // With a generation counter each speak() call increments _speakGeneration
  // and captures it locally. The completion handler checks whether its
  // captured generation still matches the current one. If not, it's stale
  // and is discarded without touching any state.
  int _speakGeneration = 0;

  // ── Public getters ─────────────────────────────────────────────────────

  ReadAloudState get state => _state;
  List<String> get sentences => _sentences;
  int get currentIndex => _currentIndex;
  bool get isActive => _state != ReadAloudState.idle;
  double get speed => _speed;
  String get docId => _docId;
  String get docTitle => _docTitle;
  double get progress => _sentences.isEmpty ? 0 : _currentIndex / _sentences.length;

  String get currentSentence =>
      _sentences.isNotEmpty && _currentIndex < _sentences.length
          ? _sentences[_currentIndex]
          : '';

  ReadAloudProvider() {
    _initTts();
  }

  // ── Auto-save on every state change ───────────────────────────────────
  
  @override
  void notifyListeners() {
    super.notifyListeners();
    // Always save state on any change - ensures state is always current
    _autoSaveState();
  }

  void _autoSaveState() {
    // Only save if we have an active playback session
    if (!isActive || _docId.isEmpty || _docTitle.isEmpty) return;
    
    // Save asynchronously without blocking
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('tts_doc_id', _docId);
      prefs.setString('tts_doc_title', _docTitle);
      prefs.setInt('tts_current_index', _currentIndex);
      prefs.setDouble('tts_speed', _speed);
      prefs.setBool('tts_is_playing', _state == ReadAloudState.playing);
    }).catchError((e) {
      debugPrint('[ReadAloudProvider] Auto-save failed: $e');
    });
  }

  // ── Init ───────────────────────────────────────────────────────────────

  Future<void> _initTts() async {
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_speed);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // KEY FIX: makes speak() block until utterance completes — no callback race
    // This solves the MIUI/Android issue where completion callbacks are dropped
    if (!kIsWeb) {
      await _tts.awaitSpeakCompletion(true);
    }

    // Force Google TTS engine on Android (fixes MIUI/Samsung silent failures)
    // Only called once during initialization
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final engines = await _tts.getEngines as List?;
        debugPrint('[ReadAloudProvider] Available TTS engines: $engines');
        if (engines != null) {
          // Look for Google TTS engine
          final googleEngine = engines.firstWhere(
            (engine) => engine.toString().contains('com.google.android.tts'),
            orElse: () => null,
          );
          if (googleEngine != null) {
            debugPrint('[ReadAloudProvider] Setting Google TTS engine: $googleEngine');
            await _tts.setEngine('com.google.android.tts');
            debugPrint('[ReadAloudProvider] Google TTS engine set successfully');
            
            // CRITICAL: Re-register handlers after setEngine() because it resets the TTS instance
            _registerHandlers();
          } else {
            debugPrint('[ReadAloudProvider] Google TTS engine not found, using default');
          }
        }
      } catch (e) {
        debugPrint('[ReadAloudProvider] Failed to set TTS engine: $e');
      }
    }

    if (!kIsWeb && Platform.isIOS) {
      final voices = await _tts.getVoices as List?;
      if (voices != null) {
        final premium = voices.firstWhere(
          (v) => (v['quality'] ?? '').toString().contains('enhanced'),
          orElse: () => null,
        );
        if (premium != null) {
          await _tts.setVoice({
            'name': premium['name'],
            'locale': premium['locale'],
          });
        }
      }
    }

    // Register handlers (cancel and error only — completion handled by awaitSpeakCompletion)
    _registerHandlers();
    
    _engineReady = true;
  }

  /// Register TTS event handlers globally.
  /// MUST be called after setEngine() because setEngine() resets the TTS instance.
  /// Note: setCompletionHandler is NOT needed — awaitSpeakCompletion(true) handles it.
  void _registerHandlers() {
    debugPrint('[ReadAloudProvider] 🎯 Registering TTS handlers');
    
    // Cancel handler for external interruptions (phone calls, audio focus stolen, etc.)
    _tts.setCancelHandler(() {
      if (_intentionalStop) {
        _intentionalStop = false;
        return;
      }
      // External interruption — invalidate generation so speak loop exits
      _speakGeneration++;
      if (_state != ReadAloudState.paused) {
        _state = ReadAloudState.idle;
        notifyListeners();
      }
    });

    _tts.setErrorHandler((msg) {
      debugPrint('[ReadAloudProvider] TTS Error: $msg');
      // Error advances generation so the speak() Future unblocks via the
      // generation check in _speakLoop
      _speakGeneration++;
    });
    
    // NO setCompletionHandler needed — awaitSpeakCompletion(true) handles it
  }

  // ── Internal stop helper ───────────────────────────────────────────────

  Future<void> _stopEngine() async {
    // Increment generation BEFORE stopping. Any in-flight speak() will check
    // generation when it completes and exit the loop.
    _speakGeneration++;
    _intentionalStop = true;
    await _tts.stop();
    _intentionalStop = false;
  }

  // ── Text loading ───────────────────────────────────────────────────────

  Future<void> loadText(String docId, String fullText, {String docTitle = ''}) async {
    if (_docId == docId && _sentences.isNotEmpty) return;
    await stop();
    _docId = docId;
    _docTitle = docTitle;

    // Run heavy text processing in background isolate to avoid UI freeze
    final sentences = await compute(_processTextInBackground, fullText);
    _sentences = sentences;

    debugPrint('[ReadAloudProvider] Loaded ${_sentences.length} sentences for $docId');
    for (int i = 0; i < _sentences.length && i < 5; i++) {
      debugPrint('[ReadAloudProvider] Sentence $i: "${_sentences[i]}"');
    }

    _currentIndex = 0;
    notifyListeners();
  }

  // Static method for isolate execution
  static List<String> _processTextInBackground(String fullText) {
    final normalized = TextNormalizer.normalize(fullText);
    return _splitIntoSentencesStatic(normalized);
  }

  List<String> _splitIntoSentences(String text) {
    return _splitIntoSentencesStatic(text);
  }

  static List<String> _splitIntoSentencesStatic(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'\r\n|\r'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    final raw = cleaned.split(RegExp(
      r'(?<![A-Z])(?<![A-Z][a-z])\.(?=\s+[A-Z])|(?<=[!?])\s+(?=[A-Z])',
    ));

    final sentences = raw
        .map((s) => s.trim())
        .where((s) => s.trim().split(' ').length > 1 || s.length > 10) // Prevent single words becoming chunks
        .toList();

    final chunked = <String>[];
    
    for (final sentence in sentences) {
      if (sentence.length <= 200) {
        // Clean trailing punctuation from short sentences
        final cleaned = sentence.trim().replaceAll(RegExp(r'[,;—]+$'), '');
        if (cleaned.trim().split(' ').length > 1 || cleaned.length > 10) {
          chunked.add(cleaned);
        }
      } else {
        final parts = sentence.split(RegExp(r'(?<=[,;—])\s+'));
        String buffer = '';
        for (final part in parts) {
          if (buffer.isEmpty) {
            buffer = part;
          } else if ((buffer.length + part.length) <= 200) {
            buffer += ' $part';
          } else {
            // Clean trailing punctuation before adding
            final cleaned = buffer.trim().replaceAll(RegExp(r'[,;—]+$'), '');
            if (cleaned.trim().split(' ').length > 1 || cleaned.length > 10) {
              chunked.add(cleaned);
            }
            buffer = part;
          }
        }
        if (buffer.isNotEmpty) {
          // Clean trailing punctuation from final buffer
          final cleaned = buffer.trim().replaceAll(RegExp(r'[,;—]+$'), '');
          if (cleaned.trim().split(' ').length > 1 || cleaned.length > 10) {
            chunked.add(cleaned);
          }
        }
      }
    }

    // CRITICAL FIX: Merge pass to combine orphaned fragments
    final merged = _mergeSentences(chunked);
    
    return merged.where((c) => c.trim().split(' ').length > 1 || c.length > 10).toList();
  }

  /// Merge pass: combines short fragments (≤5 words) with previous sentence
  /// AND detects orphaned proper nouns prepended to long sentences
  /// This prevents orphaned words like "Kenya" or "Nairobi" from becoming
  /// standalone TTS chunks that cause the engine to fail.
  static List<String> _mergeSentences(List<String> raw) {
    final result = <String>[];
    String buffer = '';

    for (int i = 0; i < raw.length; i++) {
      final s = raw[i].trim();
      final words = s.split(RegExp(r'\s+'));
      
      // SHORT fragment (≤5 words) — merge with previous
      if (words.length <= 5) {
        buffer = buffer.isEmpty ? s : '$buffer, $s';
        continue;
      }
      
      // STARTS WITH orphaned geographic/proper noun (1-2 words before a heading)
      // Detects: "Kenya EXECUTIVE SUMMARY..." where "Kenya" was orphaned
      final startsWithOrphan = RegExp(
        r'^([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)\s+[A-Z]{3,}'
      ).hasMatch(s);
      
      if (startsWithOrphan) {
        final match = RegExp(
          r'^([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)\s+(.+)$',
          dotAll: true
        ).firstMatch(s);
        
        if (match != null) {
          final orphan = match.group(1)!;
          final remainder = match.group(2)!.trim();
          
          if (buffer.isNotEmpty) {
            // OLD path — orphan attaches to in-progress buffer
            buffer = '$buffer, $orphan';
            result.add(buffer.trim());
            buffer = '';
          } else if (result.isNotEmpty) {
            // NEW: buffer already flushed → attach orphan to the last result item
            result[result.length - 1] = '${result.last}, $orphan';
          }
          // Either way, continue with the remainder as the new buffer
          if (remainder.isNotEmpty) buffer = remainder;
          continue;
        }
      }
      
      // Normal sentence — flush buffer first
      if (buffer.isNotEmpty) {
        result.add(buffer.trim());
        buffer = '';
      }
      result.add(s);
    }

    // Don't forget the last buffer
    if (buffer.isNotEmpty) {
      result.add(buffer.trim());
    }

    return result;
  }

  // ── Playback controls ──────────────────────────────────────────────────

  Future<void> play() async {
    if (_sentences.isEmpty) return;
    
    // Safety check: ensure engine is ready (should already be from constructor)
    if (!_engineReady) await _initTts();
    
    // CRITICAL: Sync speed with TTS engine before starting playback
    // This ensures the engine uses the current UI speed, not the default
    await _tts.setSpeechRate(_speed);
    debugPrint('[ReadAloudProvider] 🔊 Set TTS speed to $_speed before play');
    
    _state = ReadAloudState.playing;
    notifyListeners();
    await _speakLoop();
  }

  Future<void> pause() async {
    _speakGeneration++; // discard any in-flight completion
    _intentionalStop = true;
    await _tts.pause();
    _intentionalStop = false;
    _state = ReadAloudState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_sentences.isEmpty) return;
    _state = ReadAloudState.playing;
    notifyListeners();
    await _speakLoop();
  }

  Future<void> stop() async {
    await _stopEngine();
    _state = ReadAloudState.idle;
    _currentIndex = 0;
    notifyListeners();
  }

  Future<void> skipForward() async {
    if (_currentIndex >= _sentences.length - 1) return;
    await _stopEngine();
    _currentIndex++;
    notifyListeners();
    if (_state == ReadAloudState.playing) await _speakLoop();
  }

  Future<void> skipBackward() async {
    if (_currentIndex <= 0) return;
    await _stopEngine();
    _currentIndex--;
    notifyListeners();
    if (_state == ReadAloudState.playing) await _speakLoop();
  }

  Future<void> setSpeed(double speed) async {
    if (_speed == speed) return; // No change, skip
    
    final wasPlaying = _state == ReadAloudState.playing;

    // Stop engine first — _state is preserved because _stopEngine() does not
    // touch it.
    if (wasPlaying) await _stopEngine();

    // Apply the new rate AFTER the engine has fully stopped, avoiding the race
    // where setSpeechRate arrives while the engine is mid-utterance.
    _speed = speed;
    await _tts.setSpeechRate(speed);
    
    debugPrint('[ReadAloudProvider] 🔊 Speed changed to $_speed');

    // Resume from the same sentence with the new speed.
    if (wasPlaying) {
      _state = ReadAloudState.playing;
      await _speakLoop();
    }
    
    // Notify AFTER setting speed to ensure UI updates
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final wasPlaying = _state == ReadAloudState.playing;
    if (wasPlaying) await _stopEngine();
    await _tts.setLanguage(lang);
    if (wasPlaying) await _speakLoop();
    notifyListeners();
  }

  // Manual method to force TTS engine selection (for debugging MIUI issues)
  Future<void> forceGoogleTtsEngine() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final engines = await _tts.getEngines as List?;
        debugPrint('[ReadAloudProvider] Available TTS engines: $engines');
        if (engines != null) {
          // Look for Google TTS engine
          final googleEngine = engines.firstWhere(
            (engine) => engine.toString().contains('com.google.android.tts'),
            orElse: () => null,
          );
          if (googleEngine != null) {
            debugPrint('[ReadAloudProvider] Setting Google TTS engine: $googleEngine');
            await _tts.setEngine('com.google.android.tts');
            debugPrint('[ReadAloudProvider] Google TTS engine set successfully');
            
            // CRITICAL: Re-register handlers after setEngine()
            _registerHandlers();
          } else {
            debugPrint('[ReadAloudProvider] Google TTS engine not found, available engines: $engines');
          }
        }
      } catch (e) {
        debugPrint('[ReadAloudProvider] Failed to set TTS engine: $e');
      }
    }
  }

  // ── Internal speak loop ────────────────────────────────────────────────

  /// Main TTS loop using awaitSpeakCompletion pattern.
  /// With awaitSpeakCompletion(true), speak() blocks until the utterance completes,
  /// eliminating the callback race condition on MIUI/Android.
  Future<void> _speakLoop() async {
    while (_state == ReadAloudState.playing && _currentIndex < _sentences.length) {
      final int myGeneration = _speakGeneration;
      final sentence = _sentences[_currentIndex];

      // Measure gap between sentences
      if (_lastSentenceEndTime != null) {
        final gap = DateTime.now().difference(_lastSentenceEndTime!);
        debugPrint('[ReadAloudProvider] ⏱️ Gap since last sentence: ${gap.inMilliseconds}ms');
      }

      final startTime = DateTime.now();
      debugPrint('[ReadAloudProvider] Speaking gen=$myGeneration idx=$_currentIndex: "$sentence"');
      
      // FIX: Strip trailing period to prevent TTS engine from adding long pause
      // Periods trigger ~200-400ms of silence padding on most engines
      final toSpeak = sentence.endsWith('.') 
          ? sentence.substring(0, sentence.length - 1)
          : sentence;
      
      debugPrint('[TTS] Chunk length: ${toSpeak.length}, content: "$toSpeak"');

      try {
        // With awaitSpeakCompletion(true), this Future completes ONLY when
        // the utterance finishes — no callback race possible.
        await _tts.speak(toSpeak);
        
        final duration = DateTime.now().difference(startTime);
        debugPrint('[ReadAloudProvider] ✅ Speak completed for idx=$_currentIndex in ${duration.inMilliseconds}ms');
        _lastSentenceEndTime = DateTime.now();
      } catch (e) {
        debugPrint('[ReadAloudProvider] speak() threw: $e');
      }

      // If generation changed while we were awaiting, we were stopped/skipped.
      // Exit the loop — the new caller will start their own loop with the new generation.
      if (myGeneration != _speakGeneration) {
        debugPrint('[ReadAloudProvider] Generation changed mid-speak (was $myGeneration, now $_speakGeneration), exiting loop');
        return;
      }

      if (_state != ReadAloudState.playing) {
        debugPrint('[ReadAloudProvider] State changed to $_state, exiting loop');
        return;
      }

      // ═══════════════════════════════════════════════════════════════════
      // THIS IS WHERE WE ADVANCE TO THE NEXT SENTENCE
      // ═══════════════════════════════════════════════════════════════════
      if (_currentIndex < _sentences.length - 1) {
        _currentIndex++;
        debugPrint('[ReadAloudProvider] 🔄 Advancing to sentence $_currentIndex: "${_sentences[_currentIndex]}"');
        notifyListeners();
        // Loop continues immediately to speak the next sentence
      } else {
        // End of document
        debugPrint('[ReadAloudProvider] 🏁 End of document');
        _state = ReadAloudState.idle;
        _currentIndex = 0;
        _lastSentenceEndTime = null;
        notifyListeners();
        return;
      }
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────

  /// Load playback state from SharedPreferences
  Future<void> loadPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDocId = prefs.getString('tts_doc_id');
      
      debugPrint('[ReadAloudProvider] 📂 Attempting to load state for docId=$_docId, saved=$savedDocId');
      
      // Only load if it's the same document
      if (savedDocId == null || savedDocId != _docId) {
        debugPrint('[ReadAloudProvider] No matching saved state found');
        return;
      }
      
      final savedIndex = prefs.getInt('tts_current_index') ?? 0;
      final savedSpeed = prefs.getDouble('tts_speed') ?? 0.5; // Default to 0.5x
      final wasPlaying = prefs.getBool('tts_is_playing') ?? false;
      
      _docTitle = prefs.getString('tts_doc_title') ?? '';
      
      debugPrint('[ReadAloudProvider] 📂 Found saved state: idx=$savedIndex, speed=$savedSpeed, playing=$wasPlaying, title=$_docTitle');
      
      // Restore state
      if (savedIndex < _sentences.length) {
        _currentIndex = savedIndex;
        _speed = savedSpeed;
        
        // IMPORTANT: Set speech rate BEFORE starting playback
        await _tts.setSpeechRate(_speed);
        debugPrint('[ReadAloudProvider] 🔊 Set TTS speed to $_speed');
        
        // PRODUCTION FIX: Only restore to paused state, never auto-play
        // User must explicitly press play to resume
        if (wasPlaying) {
          _state = ReadAloudState.paused;
          debugPrint('[ReadAloudProvider] ⏸️ Restored to paused state (was playing)');
        }
        
        notifyListeners();
        debugPrint('[ReadAloudProvider] ✅ State restored successfully');
      } else {
        debugPrint('[ReadAloudProvider] ⚠️ Saved index $savedIndex out of range (total: ${_sentences.length})');
      }
    } catch (e) {
      debugPrint('[ReadAloudProvider] ❌ Failed to load state: $e');
    }
  }

  /// Clear saved playback state
  Future<void> clearPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tts_doc_id');
      await prefs.remove('tts_doc_title');
      await prefs.remove('tts_current_index');
      await prefs.remove('tts_speed');
      await prefs.remove('tts_is_playing');
      debugPrint('[ReadAloudProvider] 🗑️ Cleared saved state');
    } catch (e) {
      debugPrint('[ReadAloudProvider] Failed to clear state: $e');
    }
  }

  // ── Seek ───────────────────────────────────────────────────────────────

  /// Seek to a specific sentence index (for draggable progress bar)
  Future<void> seekToSentence(int targetIndex) async {
    if (targetIndex < 0 || targetIndex >= _sentences.length) return;
    
    final wasPlaying = _state == ReadAloudState.playing;
    
    // Stop current playback
    if (wasPlaying) await _stopEngine();
    
    // Update index
    _currentIndex = targetIndex;
    debugPrint('[ReadAloudProvider] 🎯 Seeked to sentence $targetIndex');
    notifyListeners();
    
    // Resume if was playing
    if (wasPlaying) {
      _state = ReadAloudState.playing;
      await _speakLoop();
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _speakGeneration++; // silence any final callbacks
    _intentionalStop = true;
    _tts.stop();
    super.dispose();
  }
}