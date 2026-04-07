import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../config/constants.dart';
// ignore_for_file: prefer_final_fields

class SettingsProvider extends ChangeNotifier {
  double _ttsDefaultSpeed = AppConstants.defaultTtsSpeed;
  String _ttsDefaultVoice = 'en-US';
  bool _autoSync = false;
  int _storageUsedBytes = 0;
  bool _autoDeleteRead = false;

  double get ttsDefaultSpeed => _ttsDefaultSpeed;
  String get ttsDefaultVoice => _ttsDefaultVoice;
  bool get autoSync => _autoSync;
  int get storageUsedBytes => _storageUsedBytes;
  bool get autoDeleteRead => _autoDeleteRead;

  String get formattedStorage {
    if (_storageUsedBytes < 1024) return '${_storageUsedBytes}B';
    if (_storageUsedBytes < 1024 * 1024) {
      return '${(_storageUsedBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(_storageUsedBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _ttsDefaultSpeed = prefs.getDouble(AppConstants.ttsSpeedKey) ?? AppConstants.defaultTtsSpeed;
    _ttsDefaultVoice = prefs.getString(AppConstants.ttsVoiceKey) ?? 'en-US';
    _storageUsedBytes = await StorageService.calculateStorageBytes();
    notifyListeners();
  }

  Future<void> setTtsSpeed(double speed) async {
    _ttsDefaultSpeed = speed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.ttsSpeedKey, speed);
    notifyListeners();
  }

  Future<void> setTtsVoice(String voice) async {
    _ttsDefaultVoice = voice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.ttsVoiceKey, voice);
    notifyListeners();
  }

  Future<void> setAutoDeleteRead(bool value) async {
    _autoDeleteRead = value;
    notifyListeners();
  }

  Future<void> clearCache() async {
    await StorageService.clearCache();
    _storageUsedBytes = await StorageService.calculateStorageBytes();
    notifyListeners();
  }

  Future<void> refreshStorage() async {
    _storageUsedBytes = await StorageService.calculateStorageBytes();
    notifyListeners();
  }
}
