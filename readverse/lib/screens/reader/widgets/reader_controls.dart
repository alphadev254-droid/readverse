import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/reader_provider.dart';
import 'page_slider.dart';

class ReaderControls extends StatelessWidget {
  final String pageText;
  const ReaderControls({super.key, required this.pageText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<ReaderProvider>(
      builder: (_, reader, __) {
        return IgnorePointer(
          ignoring: !reader.showControls,
          child: AnimatedOpacity(
            opacity: reader.showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: cs.surface,
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Divider(height: 1),
                    PageSlider(),
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
