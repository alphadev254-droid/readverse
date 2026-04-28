import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/tts_chunk.dart';

/// Manages buffered playback queue using just_audio
class AudioChunkQueue {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  
  final Map<int, TtsChunk> _chunks = {};
  final int maxQueueSize;
  final int minBufferSize;
  
  bool _isInitialized = false;
  bool _userPaused = false;
  int _currentIndex = 0;
  
  final StreamController<int> _chunkIndexController = StreamController<int>.broadcast();
  final StreamController<String> _currentTextController = StreamController<String>.broadcast();
  
  StreamSubscription? _indexSubscription;
  
  AudioChunkQueue({
    this.maxQueueSize = 10,
    this.minBufferSize = 1,
  });

  Stream<int> get chunkIndexStream => _chunkIndexController.stream;
  Stream<String> get currentTextStream => _currentTextController.stream;
  PlayerState get playerState => _player.playerState;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration? get position => _player.position;
  Duration? get duration => _player.duration;
  double get speed => _player.speed;
  int get currentIndex => _currentIndex;
  int get totalChunks => _chunks.length;
  TtsChunk? get currentChunk => _chunks[_currentIndex];
  TtsChunk? getChunk(int index) => _chunks[index];

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _player.setAudioSource(_playlist);
    
    _indexSubscription = _player.currentIndexStream.listen((index) {
      if (index == null) return;
      
      debugPrint('[AudioChunkQueue] Index changed to: $index');
      _currentIndex = index;
      _chunkIndexController.add(index);
      
      final chunk = _chunks[index];
      if (chunk != null) {
        debugPrint('[AudioChunkQueue] Emitting text for chunk $index: ${chunk.text.substring(0, chunk.text.length > 50 ? 50 : chunk.text.length)}...');
        _currentTextController.add(chunk.text);
      }
      
      _cleanupOldChunks(index);
    });
    
    _isInitialized = true;
    debugPrint('[AudioChunkQueue] Initialized');
  }

  Future<void> addChunk(TtsChunk chunk) async {
    if (!_isInitialized) await initialize();
    
    _chunks[chunk.index] = chunk;
    
    final audioSource = _createAudioSource(chunk.audioBytes, chunk.index);
    await _playlist.add(audioSource);
    
    debugPrint('[AudioChunkQueue] Added chunk ${chunk.index}, queue size: ${_chunks.length}, words: ${chunk.wordTimings.length}');
    debugPrint('[AudioChunkQueue] Chunk ${chunk.index} text preview: "${chunk.text.substring(0, chunk.text.length > 100 ? 100 : chunk.text.length)}..."');
    debugPrint('[AudioChunkQueue] Chunk ${chunk.index} first 3 word timings: ${chunk.wordTimings.take(3).map((w) => "${w.word}(${w.start.inMilliseconds}-${w.end.inMilliseconds}ms)").join(", ")}');
    
    // Emit text for chunk 0 immediately (indexStream doesn't fire for initial index=0)
    if (chunk.index == 0) {
      debugPrint('[AudioChunkQueue] *** EMITTING INITIAL TEXT FOR CHUNK 0 ***');
      _currentTextController.add(chunk.text);
      debugPrint('[AudioChunkQueue] Text emitted to stream: "${chunk.text.substring(0, chunk.text.length > 50 ? 50 : chunk.text.length)}..."');
    }
    
    if (_chunks.length >= minBufferSize && !_player.playing && !_userPaused) {
      debugPrint('[AudioChunkQueue] Starting playback (buffered ${_chunks.length} chunks)');
      _userPaused = false;
      await _player.play();
    }
  }

  AudioSource _createAudioSource(Uint8List bytes, int chunkIndex) {
    if (chunkIndex == 0) {
      return AudioSource.uri(Uri.dataFromBytes(bytes, mimeType: 'audio/wav'));
    }
    final wavBytes = _wrapPcmInWav(bytes, sampleRate: 22050, channels: 1, bitsPerSample: 16);
    return AudioSource.uri(Uri.dataFromBytes(wavBytes, mimeType: 'audio/wav'));
  }
  
  Uint8List _wrapPcmInWav(Uint8List pcmData, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final dataSize = pcmData.length;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final header = BytesBuilder();
    header.add('RIFF'.codeUnits);
    header.add(_int32Bytes(36 + dataSize));
    header.add('WAVE'.codeUnits);
    header.add('fmt '.codeUnits);
    header.add(_int32Bytes(16));
    header.add(_int16Bytes(1));
    header.add(_int16Bytes(channels));
    header.add(_int32Bytes(sampleRate));
    header.add(_int32Bytes(byteRate));
    header.add(_int16Bytes(blockAlign));
    header.add(_int16Bytes(bitsPerSample));
    header.add('data'.codeUnits);
    header.add(_int32Bytes(dataSize));
    final result = BytesBuilder();
    result.add(header.toBytes());
    result.add(pcmData);
    return result.toBytes();
  }
  
  List<int> _int32Bytes(int value) => [
    value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF,
  ];
  
  List<int> _int16Bytes(int value) => [
    value & 0xFF, (value >> 8) & 0xFF,
  ];

  void _cleanupOldChunks(int currentIndex) {
    final keysToRemove = _chunks.keys.where((k) => k < currentIndex - 2).toList();
    if (keysToRemove.isNotEmpty) {
      for (final k in keysToRemove) _chunks.remove(k);
      debugPrint('[AudioChunkQueue] Cleaned up ${keysToRemove.length} old chunks');
    }
  }

  Future<void> play() async {
    _userPaused = false;
    await _player.play();
  }

  Future<void> pause() async {
    _userPaused = true;
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    await _playlist.clear();
    _chunks.clear();
    _currentIndex = 0;
    _userPaused = false;
    debugPrint('[AudioChunkQueue] Stopped and cleared');
  }

  Future<void> seekToChunk(int index) async {
    if (_chunks.containsKey(index)) {
      await _player.seek(Duration.zero, index: index);
      debugPrint('[AudioChunkQueue] Seeked to chunk $index');
    }
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  void dispose() {
    _indexSubscription?.cancel();
    _chunkIndexController.close();
    _currentTextController.close();
    _player.dispose();
    debugPrint('[AudioChunkQueue] Disposed');
  }
}
