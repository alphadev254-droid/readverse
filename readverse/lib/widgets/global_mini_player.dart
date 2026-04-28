import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/read_aloud_provider.dart';

/// Global mini-player that shows at the top of non-reader screens
/// when TTS is active. Add this to the top of your screen's Column/Stack.
class GlobalMiniPlayer extends StatelessWidget {
  const GlobalMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReadAloudProvider>(
      builder: (context, tts, _) {
        if (!tts.isActive) return const SizedBox.shrink();
        
        final cs = Theme.of(context).colorScheme;
        
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                // Navigate back to the document
                if (tts.docId.isNotEmpty) {
                  context.push('/reader/${tts.docId}');
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Play/Pause button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          tts.state == ReadAloudState.playing
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: cs.onPrimary,
                          size: 20,
                        ),
                        onPressed: () {
                          if (tts.state == ReadAloudState.playing) {
                            tts.pause();
                          } else {
                            tts.resume();
                          }
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Document info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tts.docTitle.isNotEmpty)
                            Text(
                              tts.docTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            'Sentence ${tts.currentIndex + 1} of ${tts.sentences.length}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: tts.progress,
                              backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation(cs.primary),
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Speed indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${tts.speed}x',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
