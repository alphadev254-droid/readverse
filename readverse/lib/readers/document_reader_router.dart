import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../screens/reader/pdf_reader.dart';
import '../screens/reader/pdf_reader_controller.dart';
import '../screens/reader/epub_reader.dart';
import 'txt_reader.dart';
import 'md_reader.dart';
import 'docx_reader.dart';

/// Routes to the correct reader widget based on file extension.
/// All readers share the same constructor signature:
///   document + readerController
class DocumentReaderRouter extends StatelessWidget {
  final DocumentModel document;
  final PdfReaderController readerController;

  const DocumentReaderRouter({
    super.key,
    required this.document,
    required this.readerController,
  });

  @override
  Widget build(BuildContext context) {
    final ext = document.type.toLowerCase();
    switch (ext) {
      case 'pdf':
        return PdfReader(
          document: document,
          readerController: readerController,
        );
      case 'epub':
        // EPUB uses its own viewer; readerController is a no-op for now
        return EpubReader(document: document);
      case 'txt':
        return TxtReader(
          document: document,
          readerController: readerController,
        );
      case 'md':
        return MdReader(
          document: document,
          readerController: readerController,
        );
      case 'docx':
        return DocxReader(
          document: document,
          readerController: readerController,
        );
      default:
        return _UnsupportedFormatWidget(extension: ext);
    }
  }
}

class _UnsupportedFormatWidget extends StatelessWidget {
  final String extension;
  const _UnsupportedFormatWidget({required this.extension});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Unsupported format',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '.${extension.toUpperCase()} files are not supported.\nSupported: PDF, EPUB, TXT, MD, DOCX',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
