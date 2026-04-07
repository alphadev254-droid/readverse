import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/recording_model.dart';

const String _recordingsBox = 'recordings_box';

enum RecordingState { idle, synthesizing, playing, playerPaused }

class RecordingProvider extends ChangeNotifier {
  // Shared TTS instance — injected from ReadAloudProvider so there is
  // only ever ONE FlutterTts engine in the app.
  FlutterTts? _tts;
  final AudioPlayer _player = AudioPlayer();

  List<RecordingModel> _recordings = [];
  RecordingState _state = RecordingState.idle;
  String? _activeRecordingId;

  // Synthesis session
  List<String> _sentences = [];
  int _currentSentenceIndex = 0;
  List<String> _tempFiles = [];
  bool _stopRequested = false;
  String _sessionId = '';

  // Called when synthesis finishes — ReaderScreen listens to trigger save dialog
  void Function()? onSynthesisComplete;

  List<RecordingModel> get recordings => _recordings;
  RecordingState get state => _state;
  bool get isSynthesizing => _state == RecordingState.synthesizing;
  String? get activeRecordingId => _activeRecordingId;
  int get synthesizedCount => _currentSentenceIndex;
  int get totalSentences => _sentences.length;
  double get synthesisProgress => _sentences.isEmpty
      ? 0.0
      : (_currentSentenceIndex / _sentences.length).clamp(0.0, 1.0);

  RecordingProvider() {
    _initStorage();
  }

  /// Inject the shared TTS engine from ReadAloudProvider.
  void setTts(FlutterTts tts) {
    _tts = tts;
  }

  Future<void> _initStorage() async {
    Hive.registerAdapter(RecordingModelAdapter());
    final box = await Hive.openBox<RecordingModel>(_recordingsBox);
    _recordings = box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _state = RecordingState.idle;
        _activeRecordingId = null;
        notifyListeners();
      }
    });
  }

  // ── Synthesis ──────────────────────────────────────────────────────────

  Future<void> startSynthesis(
      List<String> sentences, double speed, String language) async {
    if (sentences.isEmpty || _tts == null) return;

    _sentences = sentences;
    _currentSentenceIndex = 0;
    _tempFiles = [];
    _stopRequested = false;
    _sessionId = const Uuid().v4();
    _state = RecordingState.synthesizing;
    notifyListeners();

    await _tts!.setLanguage(language);
    await _tts!.setSpeechRate(speed);
    
    // Enable await completion - this makes synthesizeToFile actually wait
    await _tts!.awaitSynthCompletion(true);

    // Use temporary directory - guaranteed writable by TTS engine
    final dir = await getTemporaryDirectory();
    final tmpDir = Directory('${dir.path}/tts_$_sessionId');
    await tmpDir.create(recursive: true);
    debugPrint('[RecordingProvider] Created temp directory: ${tmpDir.path}');

    // Run synthesis loop — sentence by sentence
    while (_currentSentenceIndex < _sentences.length && !_stopRequested) {
      final sentence = _sentences[_currentSentenceIndex];
      final fileName = 's_${_currentSentenceIndex.toString().padLeft(5, '0')}.wav';
      final filePath = '${tmpDir.path}/$fileName';

      debugPrint('[RecordingProvider] Synthesizing sentence $_currentSentenceIndex to: $filePath');
      debugPrint('[RecordingProvider] Sentence length: ${sentence.length} characters');

      // Delete any existing file first
      try {
        final existingFile = File(filePath);
        if (await existingFile.exists()) {
          await existingFile.delete();
        }
      } catch (e) {
        debugPrint('[RecordingProvider] Failed to delete existing file: $e');
      }

      // Retry up to 3 times for failed sentences
      bool success = false;
      for (int attempt = 0; attempt < 3 && !success && !_stopRequested; attempt++) {
        if (attempt > 0) {
          debugPrint('[RecordingProvider] Retry attempt $attempt for sentence $_currentSentenceIndex');
          // Wait longer between retries
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }

        // Use Completer to wait for actual completion
        final completer = Completer<bool>();
        bool handlerCalled = false;
        
        _tts!.setCompletionHandler(() {
          if (handlerCalled) return;
          handlerCalled = true;
          final file = File(filePath);
          final exists = file.existsSync();
          final size = exists ? file.lengthSync() : 0;
          debugPrint('[RecordingProvider] Completion handler: exists=$exists, size=$size');
          if (!completer.isCompleted) {
            completer.complete(exists && size > 1024);
          }
        });
        
        _tts!.setErrorHandler((msg) {
          if (handlerCalled) return;
          handlerCalled = true;
          debugPrint('[RecordingProvider] TTS Error: $msg');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });

        try {
          // Pass true for isFullPath - critical fix!
          final result = await _tts!.synthesizeToFile(sentence, filePath, true);
          debugPrint('[RecordingProvider] synthesizeToFile returned: $result');
          
          if (result == 1) {
            // Wait for completion handler OR error handler to fire
            final completed = await completer.future.timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                debugPrint('[RecordingProvider] Timeout waiting for completion');
                return false;
              },
            );
            
            if (completed) {
              _tempFiles.add(filePath);
              success = true;
              debugPrint('[RecordingProvider] ✓ Successfully created sentence $_currentSentenceIndex');
            } else {
              debugPrint('[RecordingProvider] ✗ Attempt $attempt failed for sentence $_currentSentenceIndex');
            }
          } else {
            debugPrint('[RecordingProvider] ✗ synthesizeToFile returned error: $result');
          }
        } catch (e) {
          debugPrint('[RecordingProvider] ✗ Exception during synthesis: $e');
        }
      }

      if (!success) {
        debugPrint('[RecordingProvider] ⚠️ WARNING: Failed to synthesize sentence $_currentSentenceIndex after 3 attempts - SKIPPING');
        // We have to skip this sentence to continue, but log it prominently
      }

      if (_stopRequested) break;
      
      _currentSentenceIndex++;
      notifyListeners();
      
      // Small delay between sentences to prevent TTS engine overload
      if (_currentSentenceIndex < _sentences.length) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    // Disable await completion after we're done
    await _tts!.awaitSynthCompletion(false);

    if (_stopRequested) {
      debugPrint('[RecordingProvider] Synthesis cancelled');
      await _cleanupTempFiles();
      _state = RecordingState.idle;
      notifyListeners();
      return;
    }

    debugPrint('[RecordingProvider] Synthesis complete. Created ${_tempFiles.length}/${_sentences.length} files');
    
    // Only show save dialog if we have at least some files
    if (_tempFiles.isEmpty) {
      debugPrint('[RecordingProvider] No files created, not showing save dialog');
      _state = RecordingState.idle;
      notifyListeners();
      return;
    }
    
    _state = RecordingState.idle;
    notifyListeners();
    Future.microtask(() => onSynthesisComplete?.call());
  }

  Future<void> cancelSynthesis() async {
    _stopRequested = true;
    await _cleanupTempFiles();
    _state = RecordingState.idle;
    _sentences = [];
    _currentSentenceIndex = 0;
    notifyListeners();
  }

  Future<RecordingModel?> saveRecording(String name) async {
    if (_tempFiles.isEmpty) {
      debugPrint('[RecordingProvider] No temp files to save');
      return null;
    }

    try {
      debugPrint('[RecordingProvider] Saving recording with ${_tempFiles.length} files');
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final id = const Uuid().v4();
      final outPath = '${recordingsDir.path}/$id.wav';

      debugPrint('[RecordingProvider] Concatenating files to $outPath');
      await _concatenateWavFiles(_tempFiles, outPath);

      final file = File(outPath);
      if (!await file.exists()) {
        debugPrint('[RecordingProvider] Output file does not exist after concatenation');
        return null;
      }
      final size = await file.length();
      if (size < 1024) {
        debugPrint('[RecordingProvider] Output file too small: $size bytes');
        await file.delete();
        return null;
      }

      debugPrint('[RecordingProvider] Successfully created recording: $size bytes');

      // Estimate duration: total words / (130 words/min * speed)
      final wordCount = _sentences.join(' ').split(RegExp(r'\s+')).length;
      final estimatedSeconds = (wordCount / 130 * 60).round().clamp(1, 999999);

      final recording = RecordingModel(
        id: id,
        name: name.trim().isEmpty ? 'Audio ${_recordings.length + 1}' : name.trim(),
        filePath: outPath,
        createdAt: DateTime.now(),
        durationSeconds: estimatedSeconds,
        fileSizeBytes: size,
      );

      final box = await Hive.openBox<RecordingModel>(_recordingsBox);
      await box.put(id, recording);
      _recordings.insert(0, recording);

      await _cleanupTempFiles();
      _sentences = [];
      _currentSentenceIndex = 0;
      notifyListeners();
      return recording;
    } catch (e, stackTrace) {
      debugPrint('[RecordingProvider] saveRecording error: $e');
      debugPrint('[RecordingProvider] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Concatenates WAV files by properly scanning chunk headers for the
  /// 'data' chunk — does NOT assume PCM starts at byte 44.
  Future<void> _concatenateWavFiles(List<String> inputs, String output) async {
    final allPcm = <int>[];
    int sampleRate = 16000;
    int channels = 1;
    int bitsPerSample = 16;
    bool headerParsed = false;

    debugPrint('[RecordingProvider] Concatenating ${inputs.length} files');

    for (final path in inputs) {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[RecordingProvider] File does not exist: $path');
        continue;
      }
      final bytes = await file.readAsBytes();
      debugPrint('[RecordingProvider] Processing file: $path (${bytes.length} bytes)');
      if (bytes.length < 44) {
        debugPrint('[RecordingProvider] File too small, skipping: $path');
        continue;
      }

      // Parse fmt chunk from first valid file
      if (!headerParsed) {
        int i = 12; // skip RIFF+size+WAVE
        while (i + 8 < bytes.length) {
          final chunkId = String.fromCharCodes(bytes.sublist(i, i + 4));
          final chunkSize = bytes[i + 4] |
              (bytes[i + 5] << 8) |
              (bytes[i + 6] << 16) |
              (bytes[i + 7] << 24);
          if (chunkId == 'fmt ') {
            channels = bytes[i + 10] | (bytes[i + 11] << 8);
            sampleRate = bytes[i + 12] |
                (bytes[i + 13] << 8) |
                (bytes[i + 14] << 16) |
                (bytes[i + 15] << 24);
            bitsPerSample = bytes[i + 22] | (bytes[i + 23] << 8);
            headerParsed = true;
          }
          i += 8 + chunkSize;
          if (chunkSize % 2 != 0) i++; // WAV chunks are word-aligned
        }
      }

      // Find and extract 'data' chunk PCM bytes
      int i = 12;
      while (i + 8 < bytes.length) {
        final chunkId = String.fromCharCodes(bytes.sublist(i, i + 4));
        final chunkSize = bytes[i + 4] |
            (bytes[i + 5] << 8) |
            (bytes[i + 6] << 16) |
            (bytes[i + 7] << 24);
        if (chunkId == 'data') {
          final end = (i + 8 + chunkSize).clamp(0, bytes.length);
          allPcm.addAll(bytes.sublist(i + 8, end));
          break;
        }
        i += 8 + chunkSize;
        if (chunkSize % 2 != 0) i++;
      }
    }

    if (allPcm.isEmpty) {
      debugPrint('[RecordingProvider] No PCM data extracted from files');
      return;
    }

    debugPrint('[RecordingProvider] Total PCM data: ${allPcm.length} bytes');

    final pcm = Uint8List.fromList(allPcm);
    final dataSize = pcm.length;
    final fileSize = dataSize + 36;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;

    try {
      final outFile = File(output);
      final sink = outFile.openWrite();
      sink.add([
        0x52, 0x49, 0x46, 0x46, // RIFF
        fileSize & 0xFF, (fileSize >> 8) & 0xFF, (fileSize >> 16) & 0xFF, (fileSize >> 24) & 0xFF,
        0x57, 0x41, 0x56, 0x45, // WAVE
        0x66, 0x6D, 0x74, 0x20, // fmt
        0x10, 0x00, 0x00, 0x00, // chunk size 16
        0x01, 0x00,             // PCM
        channels & 0xFF, (channels >> 8) & 0xFF,
        sampleRate & 0xFF, (sampleRate >> 8) & 0xFF, (sampleRate >> 16) & 0xFF, (sampleRate >> 24) & 0xFF,
        byteRate & 0xFF, (byteRate >> 8) & 0xFF, (byteRate >> 16) & 0xFF, (byteRate >> 24) & 0xFF,
        blockAlign & 0xFF, (blockAlign >> 8) & 0xFF,
        bitsPerSample & 0xFF, (bitsPerSample >> 8) & 0xFF,
        0x64, 0x61, 0x74, 0x61, // data
        dataSize & 0xFF, (dataSize >> 8) & 0xFF, (dataSize >> 16) & 0xFF, (dataSize >> 24) & 0xFF,
      ]);
      sink.add(pcm);
      await sink.flush();
      await sink.close();
      debugPrint('[RecordingProvider] Successfully wrote output file: $output');
    } catch (e) {
      debugPrint('[RecordingProvider] Error writing output file: $e');
      rethrow;
    }
  }

  Future<void> _cleanupTempFiles() async {
    debugPrint('[RecordingProvider] Cleaning up ${_tempFiles.length} temp files');
    for (final path in _tempFiles) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
          debugPrint('[RecordingProvider] Deleted temp file: $path');
        }
      } catch (e) {
        debugPrint('[RecordingProvider] Failed to delete temp file $path: $e');
      }
    }
    _tempFiles = [];
    try {
      final dir = await getTemporaryDirectory();
      final tmpDir = Directory('${dir.path}/tts_$_sessionId');
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
        debugPrint('[RecordingProvider] Deleted temp directory: ${tmpDir.path}');
      }
    } catch (e) {
      debugPrint('[RecordingProvider] Failed to delete temp directory: $e');
    }
  }

  // ── Playback ───────────────────────────────────────────────────────────

  Future<void> playRecording(RecordingModel recording) async {
    if (_state == RecordingState.playing || _state == RecordingState.playerPaused) {
      await _player.stop();
    }
    _activeRecordingId = recording.id;
    _state = RecordingState.playing;
    notifyListeners();
    await _player.setFilePath(recording.filePath);
    await _player.play();
  }

  Future<void> pausePlayback() async {
    await _player.pause();
    _state = RecordingState.playerPaused;
    notifyListeners();
  }

  Future<void> resumePlayback() async {
    await _player.play();
    _state = RecordingState.playing;
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    _state = RecordingState.idle;
    _activeRecordingId = null;
    notifyListeners();
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // ── Manage recordings ──────────────────────────────────────────────────

  Future<void> deleteRecording(String id) async {
    if (_activeRecordingId == id) await stopPlayback();
    final recording = _recordings.firstWhere((r) => r.id == id);
    final file = File(recording.filePath);
    if (await file.exists()) await file.delete();
    final box = await Hive.openBox<RecordingModel>(_recordingsBox);
    await box.delete(id);
    _recordings.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> renameRecording(String id, String newName) async {
    final index = _recordings.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final r = _recordings[index];
    final updated = RecordingModel(
      id: r.id,
      name: newName.trim(),
      filePath: r.filePath,
      createdAt: r.createdAt,
      durationSeconds: r.durationSeconds,
      fileSizeBytes: r.fileSizeBytes,
    );
    final box = await Hive.openBox<RecordingModel>(_recordingsBox);
    await box.put(id, updated);
    _recordings[index] = updated;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
