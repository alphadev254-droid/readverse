import 'package:flutter_tts/flutter_tts.dart';
import '../config/constants.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;
  double _speed = AppConstants.defaultTtsSpeed;
  String _language = 'en-US';

  bool get isPlaying => _isPlaying;
  double get speed => _speed;
  String get language => _language;

  Future<void> init() async {
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_speed);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() => _isPlaying = false);
    _tts.setErrorHandler((msg) => _isPlaying = false);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
    _isPlaying = true;
  }

  Future<void> pause() async {
    await _tts.pause();
    _isPlaying = false;
  }

  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _tts.setSpeechRate(speed);
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    await _tts.setLanguage(language);
  }

  Future<List<dynamic>> getAvailableLanguages() async =>
      await _tts.getLanguages;

  void setCompletionHandler(VoidCallback handler) =>
      _tts.setCompletionHandler(handler);

  void setProgressHandler(Function(String, int, int, String) handler) =>
      _tts.setProgressHandler(handler);

  Future<void> dispose() async => await _tts.stop();
}

typedef VoidCallback = void Function();
