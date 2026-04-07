import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../config/constants.dart';

class ReaderProvider extends ChangeNotifier {
  DocumentModel? _currentDocument;
  int _currentPage = 0;
  int _totalPages = 0;
  double _scrollFraction = 0.0;
  int _lastSetPage = 0;
  void Function(double)? _onSliderDrag; // registered by active text reader
  bool _ttsPlaying = false;
  double _ttsSpeed = AppConstants.defaultTtsSpeed;
  String _ttsLanguage = 'en-US';
  bool _showControls = true;
  bool _immersiveMode = false;
  Timer? _autoSaveTimer;
  Timer? _readingTimer;
  int _sessionSeconds = 0;

  final TtsService _tts = TtsService();

  DocumentModel? get currentDocument => _currentDocument;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  double get scrollFraction => _scrollFraction;
  int get lastSetPage => _lastSetPage;

  /// Text-based readers register this so PageSlider can drive them directly.
  void registerSliderDragCallback(void Function(double fraction) cb) {
    _onSliderDrag = cb;
  }

  void unregisterSliderDragCallback() {
    _onSliderDrag = null;
  }

  /// Called by PageSlider.onChanged — moves document instantly while dragging.
  void onSliderDrag(double fraction) {
    _scrollFraction = fraction.clamp(0.0, 1.0);
    final page = _totalPages > 1
        ? (_scrollFraction * (_totalPages - 1)).round() + 1
        : 1;
    _currentPage = page.clamp(1, _totalPages.clamp(1, 999999));
    notifyListeners();
    _onSliderDrag?.call(fraction); // tell DocxReader to jumpTo instantly
  }
  bool get ttsPlaying => _ttsPlaying;
  double get ttsSpeed => _ttsSpeed;
  String get ttsLanguage => _ttsLanguage;
  bool get showControls => _showControls;
  bool get immersiveMode => _immersiveMode;
  double get readingProgress =>
      _totalPages > 0 ? _currentPage / _totalPages : 0.0;

  Future<void> openDocument(DocumentModel doc) async {
    _currentDocument = doc;
    _currentPage = doc.lastPage;
    _totalPages = doc.totalPages;
    _sessionSeconds = 0;
    await _tts.init();
    _startAutoSave();
    _startReadingTimer();
    notifyListeners();
  }

  void setPage(int page) {
    _currentPage = page;
    _lastSetPage = page; // marks this as a user-initiated jump
    _scrollFraction = _totalPages > 1
        ? (page - 1) / (_totalPages - 1)
        : 0.0;
    notifyListeners();
    _saveProgress();
  }

  /// Called on every scroll frame by text-based readers.
  /// Updates fraction + page label smoothly without triggering a save.
  void setScrollFraction(double fraction) {
    _scrollFraction = fraction.clamp(0.0, 1.0);
    final page = _totalPages > 1
        ? (_scrollFraction * (_totalPages - 1)).round() + 1
        : 1;
    _currentPage = page.clamp(1, _totalPages.clamp(1, 999999));
    // No _saveProgress() here — called 60fps, save only on setPage
    notifyListeners();
  }

  void setTotalPages(int total) {
    _totalPages = total;
    notifyListeners();
  }

  Future<void> toggleTts(String text) async {
    if (_ttsPlaying) {
      await _tts.stop();
      _ttsPlaying = false;
    } else {
      await _tts.speak(text);
      _ttsPlaying = true;
      _tts.setCompletionHandler(() {
        _ttsPlaying = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> setTtsSpeed(double speed) async {
    _ttsSpeed = speed;
    await _tts.setSpeed(speed);
    notifyListeners();
  }

  Future<void> setTtsLanguage(String language) async {
    _ttsLanguage = language;
    await _tts.setLanguage(language);
    notifyListeners();
  }

  void toggleControls() {
    _showControls = !_showControls;
    notifyListeners();
  }

  void toggleImmersiveMode() {
    _immersiveMode = !_immersiveMode;
    _showControls = !_immersiveMode;
    notifyListeners();
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: AppConstants.autoSaveIntervalSeconds),
      (_) => _saveProgress(),
    );
  }

  void _startReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
    });
  }

  Future<void> _saveProgress() async {
    if (_currentDocument == null) return;
    final doc = _currentDocument!;
    // Guard: don't re-save a document that was deleted from Hive.
    // Without this check, the auto-save timer would resurrect deleted docs.
    if (StorageService.getAllDocuments().every((d) => d.id != doc.id)) return;
    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;
    final updated = doc.copyWith(
      lastPage: _currentPage,
      totalPages: _totalPages,
      readingProgress: progress,
      lastOpened: DateTime.now(),
      totalReadingSeconds: doc.totalReadingSeconds + _sessionSeconds,
    );
    _currentDocument = updated;
    await StorageService.saveDocument(updated);
    _sessionSeconds = 0;
  }

  Future<void> closeDocument() async {
    await _saveProgress();
    await _tts.stop();
    _autoSaveTimer?.cancel();
    _readingTimer?.cancel();
    _currentDocument = null;
    _ttsPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _readingTimer?.cancel();
    _tts.dispose();
    super.dispose();
  }
}
