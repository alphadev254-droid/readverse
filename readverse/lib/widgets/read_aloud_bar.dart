import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/read_aloud_provider.dart';

/// Shows the read-aloud playback bar when TTS is active.
/// Synthesis/recording is handled separately via the Generate Audio FAB.
class ReadAloudBar extends StatelessWidget {
  const ReadAloudBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReadAloudProvider>(
      builder: (_, tts, __) {
        if (!tts.isActive) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
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
              // ── Sentence preview ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: _SentencePreview(
                  sentences: tts.sentences,
                  currentIndex: tts.currentIndex,
                ),
              ),

              // ── Reading progress bar ──
              if (tts.sentences.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: tts.sentences.isEmpty
                          ? 0
                          : (tts.currentIndex + 1) / tts.sentences.length,
                      backgroundColor:
                          cs.onSurface.withValues(alpha: 0.08),
                      minHeight: 3,
                    ),
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
                                      selected: tts.speed == s,
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
                    // Close
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: tts.stop,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
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
