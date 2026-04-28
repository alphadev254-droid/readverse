# Online TTS Implementation Plan

## Summary
Implement streaming TTS from Piper backend with word-by-word highlighting, similar to offline TTS but using high-quality neural voices.

## Backend Updates ✅
- Added 16 voices total (7 high, 6 medium, 3 low quality)
- Includes LibriTTS and Jenny voices
- All voices auto-download on first use

## Flutter Implementation

### Phase 1: OnlineTtsProvider (Similar to ReadAloudProvider)
Create `lib/providers/online_tts_provider.dart` with:

**Features:**
- Sentence-by-sentence streaming from backend
- Word-by-word highlighting (parse words from sentences)
- Persistent state (save/restore like offline)
- Speed control
- Play/pause/stop/seek
- Progress tracking
- Auto-save on every change

**Key Differences from Offline:**
- Fetches audio from backend instead of device TTS
- Streams audio chunks
- Shows "Generating..." state while fetching
- Handles network errors gracefully

### Phase 2: Update Voice Picker
Update `lib/widgets/online_voice_picker.dart`:
- Add new voices (LibriTTS, Jenny)
- Update to 16 total voices
- Keep same beautiful UI

### Phase 3: Streaming Mini-Player
Similar to `ReadAloudBar` but for online TTS:
- Shows current sentence being spoken
- Word highlighting within sentence
- Progress slider (sentence-based)
- Speed control chips
- Play/pause/stop buttons
- Persistent across navigation
- Shows on home screen when active
- Closes when viewing different document

### Phase 4: Integration
Update `reader_screen.dart`:
- When online voice selected → use OnlineTtsProvider
- When offline selected → use ReadAloudProvider
- Both share same UI components where possible

## User Flow

1. User clicks "Read Aloud" → Mode selector appears
2. User selects "Online Reading" → Voice picker appears
3. User selects voice (e.g., "Amy - High Quality") → Clicks "Start Reading"
4. App shows loading indicator "Generating audio..."
5. Backend streams audio sentence-by-sentence
6. Mini-player appears showing:
   - Current sentence with word highlighting
   - Progress (sentence 5/120)
   - Speed control
   - Play/pause/stop buttons
7. User can navigate away → Mini-player persists at top
8. User can tap mini-player → Returns to document
9. User opens different document → Mini-player closes, state saved

## Technical Details

### Streaming Strategy
```dart
// Sentence-by-sentence streaming
for (int i = 0; i < sentences.length; i++) {
  // 1. Show "Generating..." for current sentence
  setState(() => _generatingIndex = i);
  
  // 2. Fetch audio from backend
  final audioBytes = await onlineTtsService.generateSpeech(
    text: sentences[i],
    voiceId: selectedVoice,
    speed: speed,
  );
  
  // 3. Play audio
  await audioPlayer.play(BytesSource(audioBytes));
  
  // 4. Highlight words while playing
  _highlightWordsInSentence(sentences[i]);
  
  // 5. Move to next sentence
}
```

### Word Highlighting
```dart
// Parse sentence into words
final words = sentence.split(RegExp(r'\s+'));
final duration = audioDuration / words.length;

// Highlight each word
for (int j = 0; j < words.length; j++) {
  setState(() => _currentWordIndex = j);
  await Future.delayed(duration);
}
```

### State Persistence
```dart
// Save state
await prefs.setString('online_tts_state', jsonEncode({
  'docId': docId,
  'docTitle': docTitle,
  'voiceId': voiceId,
  'sentences': sentences,
  'currentIndex': currentIndex,
  'speed': speed,
  'isPlaying': false, // Always restore to paused
}));
```

## Files to Create

1. `lib/providers/online_tts_provider.dart` - Main provider
2. `lib/widgets/online_tts_bar.dart` - Mini-player for online TTS
3. `lib/widgets/online_global_mini_player.dart` - Global mini-player

## Files to Update

1. `lib/widgets/online_voice_picker.dart` - Add new voices
2. `lib/screens/reader/reader_screen.dart` - Integration
3. `lib/screens/home/home_screen.dart` - Show global mini-player

## Next Steps

1. ✅ Update backend with more voices
2. ⏳ Update Flutter voice picker
3. ⏳ Create OnlineTtsProvider
4. ⏳ Create online TTS mini-player
5. ⏳ Integrate with reader screen
6. ⏳ Test end-to-end

## Design Consistency

- Use same design language as offline TTS
- Purple accent for online (vs blue for offline)
- Show "ONLINE" badge in mini-player
- Loading states with shimmer effects
- Error handling with retry options

---

**Status**: Backend Ready, Flutter Implementation Next
**Estimated Time**: 2-3 hours for full implementation
