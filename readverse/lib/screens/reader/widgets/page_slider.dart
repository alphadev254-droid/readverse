import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/reader_provider.dart';

class PageSlider extends StatefulWidget {
  const PageSlider({super.key});

  @override
  State<PageSlider> createState() => _PageSliderState();
}

class _PageSliderState extends State<PageSlider> {
  double? _draggingFraction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<ReaderProvider>(
      builder: (_, reader, __) {
        final total = reader.totalPages;
        final current = reader.currentPage;
        if (total <= 0) return const SizedBox.shrink();

        // While dragging: use local value so thumb follows finger exactly.
        // While scrolling: use provider fraction so bar follows document.
        final displayFraction =
            _draggingFraction ?? reader.scrollFraction.clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed:
                    current > 1 ? () => reader.setPage(current - 1) : null,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14),
                      ),
                      child: Slider(
                        value: displayFraction,
                        min: 0.0,
                        max: 1.0,
                        onChangeStart: (v) {
                          setState(() => _draggingFraction = v);
                        },
                        onChanged: (v) {
                          setState(() => _draggingFraction = v);
                          // Drives document scroll live via registered callback
                          reader.onSliderDrag(v);
                        },
                        onChangeEnd: (v) {
                          _draggingFraction = null;
                          // Stay exactly where the finger lifted — no snapping
                          reader.setScrollFraction(v);
                        },
                      ),
                    ),
                    Text(
                      'Page $current / $total',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: current < total
                    ? () => reader.setPage(current + 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }
}
