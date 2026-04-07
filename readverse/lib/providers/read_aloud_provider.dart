import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum ReadAloudState { idle, playing, paused }

class ReadAloudProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  ReadAloudState _state = ReadAloudState.idle;
  List<String> _sentences = [];
  int _currentIndex = 0;
  String _docId = '';
  double _speed = 0.48;

  ReadAloudState get state => _state;
  List<String> get sentences => _sentences;
  int get currentIndex => _currentIndex;
  bool get isActive => _state != ReadAloudState.idle;
  double get speed => _speed;
  /// Exposed so RecordingProvider can share the same engine.
  FlutterTts get tts => _tts;

  String get currentSentence =>
      _sentences.isNotEmpty && _currentIndex < _sentences.length
          ? _sentences[_currentIndex]
          : '';

  ReadAloudProvider() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speed);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Use highest-quality voice on iOS if available
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

    _tts.setCompletionHandler(_onSentenceComplete);
    _tts.setCancelHandler(() {
      if (_state != ReadAloudState.paused) {
        _state = ReadAloudState.idle;
        notifyListeners();
      }
    });
  }

  /// Load text for a document. Skips if same doc already loaded.
  Future<void> loadText(String docId, String fullText) async {
    if (_docId == docId && _sentences.isNotEmpty) return;
    await stop();
    _docId = docId;
    _sentences = _splitIntoSentences(fullText);
    _currentIndex = 0;
    notifyListeners();
  }

  List<String> _splitIntoSentences(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'\r\n|\r'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    final raw = cleaned.split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'));
    return raw
        .map((s) => s.trim())
        .where((s) => s.length > 3)
        .toList();
  }

  Future<void> play() async {
    if (_sentences.isEmpty) return;
    _state = ReadAloudState.playing;
    notifyListeners();
    await _speakCurrent();
  }

  Future<void> pause() async {
    await _tts.pause();
    _state = ReadAloudState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_sentences.isEmpty) return;
    _state = ReadAloudState.playing;
    notifyListeners();
    // flutter_tts resume is unreliable on Android — re-speak current sentence
    await _speakCurrent();
  }

  Future<void> stop() async {
    await _tts.stop();
    _state = ReadAloudState.idle;
    _currentIndex = 0;
    notifyListeners();
  }

  Future<void> skipForward() async {
    if (_currentIndex < _sentences.length - 1) {
      await _tts.stop();
      _currentIndex++;
      notifyListeners();
      if (_state == ReadAloudState.playing) await _speakCurrent();
    }
  }

  Future<void> skipBackward() async {
    if (_currentIndex > 0) {
      await _tts.stop();
      _currentIndex--;
      notifyListeners();
      if (_state == ReadAloudState.playing) await _speakCurrent();
    }
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _tts.setSpeechRate(speed);
    // Restart current sentence so new speed takes effect immediately
    if (_state == ReadAloudState.playing) {
      await _tts.stop();
      await _speakCurrent();
    }
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    await _tts.setLanguage(lang);
    notifyListeners();
  }

  Future<void> _speakCurrent() async {
    if (_currentIndex >= _sentences.length) {
      await stop();
      return;
    }
    await _tts.speak(_sentences[_currentIndex]);
  }

  void _onSentenceComplete() {
    if (_state != ReadAloudState.playing) return;
    if (_currentIndex < _sentences.length - 1) {
      _currentIndex++;
      notifyListeners();
      _speakCurrent();
    } else {
      _state = ReadAloudState.idle;
      _currentIndex = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
