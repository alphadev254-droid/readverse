import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tts_chunk.dart';

/// Fetches and parses binary-framed TTS chunks from HTTP stream
class HttpChunkFetcher {
  final String baseUrl;
  http.Client? _client;
  
  HttpChunkFetcher({required this.baseUrl});

  /// Stream TTS chunks from backend
  /// 
  /// Binary frame format:
  /// [4 bytes: chunk_length]
  /// [4 bytes: index]
  /// [4 bytes: text_length]
  /// [4 bytes: is_last]
  /// [N bytes: UTF-8 text]
  /// [M bytes: WAV audio]
  Stream<TtsChunk> fetchChunks({
    required String text,
    required String voiceId,
    double speed = 1.0,
    VoidCallback? onConnected,  // Callback fired after HTTP 200 confirmed
  }) async* {
    _client = http.Client();
    
    try {
      debugPrint('[HttpChunkFetcher] Starting stream: ${text.length} chars, voice=$voiceId');
      
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/v1/audio/stream'),
      );
      
      request.headers['Content-Type'] = 'application/json';
      request.body = '{"input": "${_escapeJson(text)}", "voice": "$voiceId", "speed": $speed}';
      
      final response = await _client!.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('HTTP request timed out after 30 seconds');
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: Failed to start stream');
      }
      
      // Connection confirmed - server is alive and streaming
      onConnected?.call();
      
      debugPrint('[HttpChunkFetcher] Stream started, reading chunks...');
      
      // Read binary stream
      final BytesBuilder buffer = BytesBuilder();
      int chunksReceived = 0;
      
      await for (var bytes in response.stream) {
        buffer.add(bytes);
        
        // Try to parse complete chunks from buffer
        while (true) {
          final chunk = _tryParseChunk(buffer);
          if (chunk == null) break;
          
          chunksReceived++;
          debugPrint('[HttpChunkFetcher] Chunk $chunksReceived: ${chunk.text.substring(0, chunk.text.length > 50 ? 50 : chunk.text.length)}...');
          
          yield chunk;
          
          if (chunk.isLast) {
            debugPrint('[HttpChunkFetcher] Received last chunk, total: $chunksReceived');
            return;
          }
        }
      }
      
      debugPrint('[HttpChunkFetcher] Stream completed, total chunks: $chunksReceived');
      
    } catch (e) {
      debugPrint('[HttpChunkFetcher] Error: $e');
      rethrow;
    } finally {
      _client?.close();
      _client = null;
    }
  }

  /// Try to parse a complete chunk from buffer
  /// Returns null if buffer doesn't contain a complete chunk yet
  /// 
  /// Frame format with word timings:
  /// [4 bytes: chunk_length]
  /// [4 bytes: index]
  /// [4 bytes: text_length]
  /// [4 bytes: is_last]
  /// [N bytes: UTF-8 text]
  /// [4 bytes: timings_count]
  /// For each timing:
  ///   [4 bytes: start_ms]
  ///   [4 bytes: end_ms]
  ///   [2 bytes: word_length]
  ///   [K bytes: UTF-8 word]
  /// [M bytes: WAV audio]
  TtsChunk? _tryParseChunk(BytesBuilder buffer) {
    final bytes = buffer.toBytes();
    
    // Need at least 20 bytes for header (added total_chunks field)
    if (bytes.length < 20) return null;
    
    // Read header (big-endian)
    final chunkLength = _readUint32BE(bytes, 0);
    final index = _readUint32BE(bytes, 4);
    final textLength = _readUint32BE(bytes, 8);
    final isLastInt = _readUint32BE(bytes, 12);
    final totalChunks = _readUint32BE(bytes, 16);
    
    int offset = 20; // header is now 20 bytes
    
    // Check if we have text
    if (bytes.length < offset + textLength) return null;
    
    // Extract text
    final textBytes = bytes.sublist(offset, offset + textLength);
    final text = String.fromCharCodes(textBytes);
    offset += textLength;
    
    // Check if we have timings count
    if (bytes.length < offset + 4) return null;
    
    final timingsCount = _readUint32BE(bytes, offset);
    offset += 4;
    
    // Parse word timings
    final wordTimings = <WordTiming>[];
    for (int i = 0; i < timingsCount; i++) {
      // Need at least 10 bytes for timing header (start + end + word_len)
      if (bytes.length < offset + 10) return null;
      
      final startMs = _readUint32BE(bytes, offset);
      offset += 4;
      final endMs = _readUint32BE(bytes, offset);
      offset += 4;
      final wordLen = _readUint16BE(bytes, offset);
      offset += 2;
      
      // Check if we have the word
      if (bytes.length < offset + wordLen) return null;
      
      final wordBytes = bytes.sublist(offset, offset + wordLen);
      final word = String.fromCharCodes(wordBytes);
      offset += wordLen;
      
      wordTimings.add(WordTiming(
        wordIndex: i,
        word: word,
        start: Duration(milliseconds: startMs),
        end: Duration(milliseconds: endMs),
      ));
    }
    
    // chunkLength = index(4) + text_length(4) + is_last(4) + total_chunks(4) + text(N) + timings_count(4) + timings(T) + audio(A)
    // offset after parsing = 20 + textLength + 4 + timingsSize
    // bytesConsumedInChunkLength = offset - 4 (everything except the first 4 bytes)
    final bytesConsumedInChunkLength = offset - 4;
    final audioSize = chunkLength - bytesConsumedInChunkLength;
    
    // Check if we have complete audio
    if (bytes.length < offset + audioSize) return null;
    
    // Extract audio
    final audioBytes = Uint8List.fromList(bytes.sublist(offset, offset + audioSize));
    
    // Calculate total frame size
    final frameSize = offset + audioSize;
    
    // Remove parsed chunk from buffer
    buffer.clear();
    if (bytes.length > frameSize) {
      buffer.add(bytes.sublist(frameSize));
    }
    
    return TtsChunk(
      index: index,
      totalChunks: totalChunks,
      audioBytes: audioBytes,
      text: text,
      wordTimings: wordTimings,
      isLast: isLastInt == 1,
    );
  }

  /// Read 16-bit unsigned integer (big-endian)
  int _readUint16BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  /// Read 32-bit unsigned integer (big-endian)
  int _readUint32BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
           (bytes[offset + 1] << 16) |
           (bytes[offset + 2] << 8) |
           bytes[offset + 3];
  }

  /// Escape JSON string
  String _escapeJson(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Cancel ongoing fetch
  void cancel() {
    _client?.close();
    _client = null;
    debugPrint('[HttpChunkFetcher] Cancelled');
  }

  void dispose() {
    cancel();
  }
}
