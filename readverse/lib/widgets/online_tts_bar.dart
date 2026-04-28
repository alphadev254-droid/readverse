import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streaming_tts_provider.dart';
import '../services/tts_pipeline_controller.dart';

/// Shows the online TTS playback bar when streaming from backend
class OnlineTtsBar extends StatefulWidget {
  final bool isGlobal;
  final VoidCallback? onTap;
  
  const OnlineTtsBar({
    super.key,
    this.isGlobal = false,
    this.onTap,
  });

  @override
  State<OnlineTtsBar> createState() => _OnlineTtsBarState();
}

class _OnlineTtsBarState extends State<OnlineTtsBar> {
  bool _isVisible = true;
  String _lastDocId = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamingTtsProvider>(
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
                // Document title (only in global mode)
                if (widget.isGlobal && tts.docTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Row(
                      children: [
                        Icon(Icons.cloud, 
                          size: 16, 
                          color: Colors.purple.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ONLINE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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

                // Current text display
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: _CurrentTextDisplay(
                    text: tts.currentText,
                    state: tts.state,
                  ),
                ),

                // Progress slider
                if (tts.totalChunks > 0)
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
                              activeTrackColor: Colors.purple,
                              inactiveTrackColor: Colors.purple.withValues(alpha: 0.2),
                              thumbColor: Colors.purple,
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
                              max: (tts.totalChunks - 1).toDouble().clamp(0, double.infinity),
                              divisions: tts.totalChunks > 1 ? tts.totalChunks - 1 : 1,
                              onChanged: (value) {
                                tts.seekToChunk(value.toInt());
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${tts.totalChunks}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Buffering indicator
                if (tts.isBuffering || tts.isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Buffering ${tts.bufferedChunks}/${tts.totalChunks} chunks...',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Controls row
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
                      const SizedBox(width: 4),
                      // Speed chips - scrollable
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                              final isSelected = (tts.speed - s).abs() < 0.01;
                              return Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: _SpeedChip(
                                  speed: s,
                                  isSelected: isSelected,
                                  onTap: () => tts.setSpeed(s),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => tts.stop(),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // Error message
                if (tts.isError)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, 
                          color: Colors.red, 
                          size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tts.errorMessage,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => tts.retry(),
                          child: const Text('Retry'),
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

class _CurrentTextDisplay extends StatelessWidget {
  final String text;
  final TtsPipelineState state;

  const _CurrentTextDisplay({required this.text, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == TtsPipelineState.loading ||
        state == TtsPipelineState.buffering) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(Colors.purple),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state == TtsPipelineState.loading ? 'Loading...' : 'Buffering...',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.purple,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    if (text.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: Container(
        key: ValueKey(text),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final TtsPipelineState state;

  const _PlayPauseButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final tts = context.read<StreamingTtsProvider>();

    IconData icon;
    VoidCallback? onPressed;

    switch (state) {
      case TtsPipelineState.idle:
        icon = Icons.play_arrow_rounded;
        onPressed = null;
        break;
      case TtsPipelineState.loading:
      case TtsPipelineState.buffering:
        icon = Icons.hourglass_empty_rounded;
        onPressed = null;
        break;
      case TtsPipelineState.playing:
        icon = Icons.pause_rounded;
        onPressed = tts.pause;
        break;
      case TtsPipelineState.paused:
        icon = Icons.play_arrow_rounded;
        onPressed = tts.play;
        break;
      case TtsPipelineState.error:
        icon = Icons.refresh_rounded;
        onPressed = tts.retry;
        break;
      case TtsPipelineState.completed:
        icon = Icons.replay_rounded;
        onPressed = () => tts.seekToChunk(0);
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.purple,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: Colors.white,
        iconSize: 28,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final double speed;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.speed,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.purple 
              : Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected 
                ? Colors.white 
                : Colors.purple,
          ),
        ),
      ),
    );
  }
}
