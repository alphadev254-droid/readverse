# Pending Code Changes

These changes need to be applied manually due to disk space constraints during the automated edit.

## 1. TtsPipelineController - Add Word Stream Debug Logging

**File**: `readverse/lib/services/tts_pipeline_controller.dart`

**Location**: In the `start()` method, find the word stream listener (around line 90)

**Current Code**:
```dart
// Listen to word changes from queue
_queue!.currentWordStream.listen((word) {
  _currentWord = word;
  _wordController.add(word);
});
```

**Change To**:
```dart
// Listen to word changes from queue
_queue!.currentWordStream.listen((word) {
  debugPrint('[TtsPipeline] *** WORD RECEIVED: "$word" ***');
  _currentWord = word;
  _wordController.add(word);
});
```

## 2. StreamingTtsProvider - Add Word Stream Debug Logging

**File**: `readverse/lib/providers/streaming_tts_provider.dart`

**Location**: In the `initialize()` method, find the word stream listener (around line 85)

**Current Code**:
```dart
// Listen to word changes
_pipeline!.wordStream.listen((word) {
  _currentWord = word;
  notifyListeners();
});
```

**Change To**:
```dart
// Listen to word changes
_pipeline!.wordStream.listen((word) {
  debugPrint('[StreamingTTS] *** PROVIDER RECEIVED WORD: "$word" ***');
  _currentWord = word;
  notifyListeners();
});
```

## Why These Changes?

These debug logs will help trace the word stream data flow:

```
[AudioChunkQueue] Word: "hello" (pos: 123ms, timing: 100-200ms)
  ↓
[TtsPipeline] *** WORD RECEIVED: "hello" ***
  ↓
[StreamingTTS] *** PROVIDER RECEIVED WORD: "hello" ***
```

If word highlighting isn't working, these logs will show exactly where the data flow breaks.

## Testing After Changes

1. Run the app: `flutter run`
2. Start online TTS playback
3. Watch the console for word logs
4. If you see all three log levels, the word stream is working
5. If you only see some, you know where the break is

## Optional: Remove Debug Logs Later

Once everything is working, you can remove these debug logs to reduce console noise. But keep them for now during testing.
