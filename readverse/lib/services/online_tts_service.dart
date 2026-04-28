import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for communicating with Piper TTS backend
class OnlineTtsService {
  final String baseUrl;
  
  OnlineTtsService({String? baseUrl}) : baseUrl = baseUrl ?? _getDefaultBaseUrl();
  
  /// Get default base URL based on platform
  static String _getDefaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8880';
    } else if (Platform.isAndroid) {
      // For physical Android device - using your computer's WiFi IP
      return 'http://192.168.10.2:8880';
    } else {
      // iOS simulator, desktop, etc.
      return 'http://localhost:8880';
    }
  }

  /// Generate speech from text
  Future<Uint8List?> generateSpeech({
    required String text,
    required String voiceId,
    double speed = 1.0,
    String format = 'mp3',
  }) async {
    try {
      debugPrint('[OnlineTTS] Generating speech: ${text.length} chars, voice=$voiceId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/v1/audio/speech'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': text,
          'voice': voiceId,
          'response_format': format,
          'speed': speed,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[OnlineTTS] Speech generated: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        debugPrint('[OnlineTTS] Speech generation failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[OnlineTTS] Speech generation error: $e');
      return null;
    }
  }

  // NOTE: For streaming TTS with binary frames, use HttpChunkFetcher directly.
  // The /v1/audio/speech endpoint returns raw audio bytes, not binary-framed chunks.
  // The streaming pipeline uses /v1/audio/stream via HttpChunkFetcher.

  /// Get available voices from backend
  Future<List<Map<String, dynamic>>> getAvailableVoices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v1/audio/voices'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['voices']);
      } else {
        debugPrint('[OnlineTTS] Failed to fetch voices: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[OnlineTTS] Error fetching voices: $e');
      return [];
    }
  }

  /// Check if backend is available
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[OnlineTTS] Backend health check failed: $e');
      return false;
    }
  }
}
