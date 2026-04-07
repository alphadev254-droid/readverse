import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import 'package:provider/provider.dart';
import '../../providers/reader_provider.dart';
import '../../models/document_model.dart';

class EpubReader extends StatefulWidget {
  final DocumentModel document;
  const EpubReader({super.key, required this.document});

  @override
  State<EpubReader> createState() => _EpubReaderState();
}

class _EpubReaderState extends State<EpubReader> {
  EpubController? _epubController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initEpub();
  }

  Future<void> _initEpub() async {
    try {
      final bytes = await File(widget.document.filePath).readAsBytes();
      _epubController = EpubController(
        document: EpubDocument.openData(bytes),
      );
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load EPUB: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _epubController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    // No GestureDetector — toggle controls handled by ReaderScreen overlay
    return EpubView(
      controller: _epubController!,
      onChapterChanged: (value) {
        if (value != null) {
          context.read<ReaderProvider>().setPage(value.position.index);
        }
      },
      onDocumentLoaded: (document) {
        final total = document.Chapters?.length ?? 0;
        context.read<ReaderProvider>().setTotalPages(total);
      },
    );
  }
}
