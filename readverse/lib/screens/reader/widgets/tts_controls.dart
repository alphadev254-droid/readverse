import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/reader_provider.dart';
import '../../../config/constants.dart';

class TtsControls extends StatelessWidget {
  final String pageText;
  const TtsControls({super.key, required this.pageText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<ReaderProvider>(
      builder: (_, reader, __) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Play/Pause + speed chips
            Row(
              children: [
                // Play/Pause — fixed width, NOT double.infinity
                FilledButton.icon(
                  onPressed: () => reader.toggleTts(pageText),
                  icon: Icon(
                    reader.ttsPlaying ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    reader.ttsPlaying ? 'Pause' : 'Read',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                // Speed chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [0.5, 1.0, 1.5, 2.0].map((speed) {
                        final selected = reader.ttsSpeed == speed;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              '${speed}x',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: selected,
                            onSelected: (_) => reader.setTtsSpeed(speed),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Language selector
            Row(
              children: [
                Icon(Icons.language, size: 16,
                    color: cs.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: reader.ttsLanguage,
                      isExpanded: true,
                      isDense: true,
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurface),
                      items: AppConstants.ttsLanguages.map((lang) {
                        return DropdownMenuItem(
                          value: lang,
                          child: Text(
                            AppConstants.ttsLanguageNames[lang] ?? lang,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) reader.setTtsLanguage(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
