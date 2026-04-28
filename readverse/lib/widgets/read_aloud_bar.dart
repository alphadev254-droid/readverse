import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/read_aloud_provider.dart';

/// Shows the read-aloud playback bar when TTS is active.
/// Can be shown at bottom of reader screen or at top globally.
class ReadAloudBar extends StatefulWidget {
  final bool isGlobal; // If true, shows at top with document title
  final VoidCallback? onTap; // Callback when tapped (to navigate back to document)
  
  const ReadAloudBar({
    super.key,
    this.isGlobal = false,
    this.onTap,
  });

  @override
  State<ReadAloudBar> createState() => _ReadAloudBarState();
}

class _ReadAloudBarState extends State<ReadAloudBar> {
  bool _isVisible = true;
  String _lastDocId = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<ReadAloudProvider>(
      builder: (_, tts, __) {
        // Reset visibility when a new document starts playing
        if (tts.isActive && tts.docId != _lastDocId) {
          _lastDocId = tts.docId;
          _isVisible = true;
        }
        
        if (!tts.isActive || !_isVisible) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: widget.isGlobal 
                ? const EdgeInsets.fromLTRB(12, 8, 12, 0)
                : const EdgeInsets.fromLTRB(12, 0, 12, 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Document title (only in global mode) ──
                if (widget.isGlobal && tts.docTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, 
                          size: 16, 
                          color: cs.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tts.docTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Sentence preview ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: _SentencePreview(
                    sentences: tts.sentences,
                    currentIndex: tts.currentIndex,
                  ),
                ),

                // ── Draggable progress slider ──
                if (tts.sentences.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          '${tts.currentIndex + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                            ),
                            child: Slider(
                              value: tts.currentIndex.toDouble(),
                              min: 0,
                              max: (tts.sentences.length - 1).toDouble(),
                              divisions: tts.sentences.length - 1,
                              onChanged: (value) {
                                tts.seekToSentence(value.toInt());
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${tts.sentences.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Controls row ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: tts.skipBackward,
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                      ),
                      _PlayPauseButton(state: tts.state),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: tts.skipForward,
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                      ),
                      // Speed chips 0.1x – 2x
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                                .map((s) => Padding(
                                      padding:
                                          const EdgeInsets.only(right: 4),
                                      child: ChoiceChip(
                                        label: Text('${s}x',
                                            style: const TextStyle(
                                                fontSize: 11)),
                                        selected: (tts.speed - s).abs() < 0.01,
                                        onSelected: (_) => tts.setSpeed(s),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 4),
                                        visualDensity:
                                            VisualDensity.compact,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                      // Close/Hide button
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: widget.isGlobal
                            ? () {
                                // In global mode, just hide the bar
                                setState(() => _isVisible = false);
                              }
                            : () {
                                // In reader mode, stop playback
                                tts.stop();
                              },
                        visualDensity: VisualDensity.compact,
                        tooltip: widget.isGlobal ? 'Hide' : 'Stop',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SentencePreview extends StatelessWidget {
  final List<String> sentences;
  final int currentIndex;
  const _SentencePreview(
      {required this.sentences, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (sentences.isEmpty) return const SizedBox.shrink();
    final prev =
        currentIndex > 0 ? sentences[currentIndex - 1] : null;
    final curr = sentences[currentIndex];
    final next = currentIndex < sentences.length - 1
        ? sentences[currentIndex + 1]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prev != null)
          Text(prev,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.32),
                  height: 1.4)),
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(
              top: prev != null ? 4 : 0,
              bottom: next != null ? 4 : 0),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(curr,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onPrimaryContainer,
                  height: 1.5)),
        ),
        if (next != null)
          Text(next,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.32),
                  height: 1.4)),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final ReadAloudState state;
  const _PlayPauseButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tts = context.read<ReadAloudProvider>();
    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => state == ReadAloudState.playing
            ? tts.pause()
            : tts.resume(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            state == ReadAloudState.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            color: cs.onPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}
