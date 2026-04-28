import 'dart:typed_data';

/// Represents word-level timing within a chunk
class WordTiming {
  final int wordIndex;
  final String word;
  final Duration start;  // offset within this chunk's audio
  final Duration end;

  WordTiming({
    required this.wordIndex,
    required this.word,
    required this.start,
    required this.end,
  });

  @override
  String toString() {
    return 'WordTiming(word: "$word", start: ${start.inMilliseconds}ms, end: ${end.inMilliseconds}ms)';
  }
}

/// Represents a single TTS audio chunk with synchronized text and word timings
class TtsChunk {
  final int index;
  final int totalChunks; // total number of chunks in this stream (0 if unknown)
  final Uint8List audioBytes;
  final String text;
  final List<WordTiming> wordTimings;
  final bool isLast;

  TtsChunk({
    required this.index,
    this.totalChunks = 0,
    required this.audioBytes,
    required this.text,
    required this.wordTimings,
    required this.isLast,
  });

  @override
  String toString() {
    return 'TtsChunk(index: $index, total: $totalChunks, audioSize: ${audioBytes.length}, textLen: ${text.length}, words: ${wordTimings.length}, isLast: $isLast)';
  }
}
