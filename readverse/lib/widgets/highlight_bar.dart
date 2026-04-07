import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Shared highlight bar shown as an OverlayEntry above selected text.
/// Used by PdfReader, TxtReader, and MdReader.
/// Never use as a BottomSheet — always insert via Overlay.
class HighlightBar extends StatelessWidget {
  final String selectedText;
  final void Function(Color color) onHighlight;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  const HighlightBar({
    super.key,
    required this.selectedText,
    required this.onHighlight,
    required this.onCopy,
    required this.onClose,
  });

  static const _colors = [
    (color: AppColors.highlightYellow, label: 'Yellow'),
    (color: AppColors.highlightGreen, label: 'Green'),
    (color: AppColors.highlightPink, label: 'Pink'),
    (color: AppColors.highlightBlue, label: 'Blue'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy button
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 14, color: cs.onSurface),
                  const SizedBox(width: 4),
                  Text('Copy', style: TextStyle(fontSize: 12, color: cs.onSurface)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: cs.outline.withValues(alpha: 0.3)),
          const SizedBox(width: 8),
          // Color dots — one tap = saved instantly
          ..._colors.map((item) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onHighlight(item.color),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.45),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(width: 4),
          // Close
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close, size: 18, color: cs.onSurface.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}
