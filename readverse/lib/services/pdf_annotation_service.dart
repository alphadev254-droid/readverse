import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/highlight_model.dart';

class PlainHighlight {
  final int page;
  final String text;
  final int colorValue;
  final String? note;
  final DateTime createdAt;
  final List<double> bounds;
  final List<double>? boundsCollectionFlat;

  const PlainHighlight({
    required this.page,
    required this.text,
    required this.colorValue,
    this.note,
    required this.createdAt,
    required this.bounds,
    this.boundsCollectionFlat,
  });

  static PlainHighlight fromModel(HighlightModel h) => PlainHighlight(
        page: h.page,
        text: h.text,
        colorValue: h.colorValue,
        note: h.note,
        createdAt: h.createdAt,
        bounds: List<double>.from(h.bounds),
        boundsCollectionFlat: h.boundsCollectionFlat != null
            ? List<double>.from(h.boundsCollectionFlat!)
            : null,
      );
}

/// ⚠️ IMPORTANT: PdfTextLine.bounds from SfPdfViewer are already in PDF coordinate
/// space (origin bottom-left). Do NOT flip Y when injecting them via PdfAnnotationService.
/// This service is now only used as a ONE-TIME MIGRATION path for users who already
/// have saved highlights from an older app version that never called saveDocument().
/// New highlights are persisted by saveDocument() directly from PdfReader.
class PdfAnnotationService {
  static Future<Uint8List> injectPlainHighlights({
    required Uint8List pdfBytes,
    required List<PlainHighlight> highlights,
  }) async {
    if (highlights.isEmpty) return pdfBytes;
    final document = PdfDocument(inputBytes: pdfBytes);
    try {
      for (final h in highlights) {
        if (h.text.trim().isEmpty) continue;
        final pageIdx = h.page.clamp(0, document.pages.count - 1);
        final page = document.pages[pageIdx];

        final color = Color(h.colorValue);
        final pdfColor = PdfColor(
          (color.r * 255).round(),
          (color.g * 255).round(),
          (color.b * 255).round(),
          (color.a * 255).round(),
        );

        final bc = h.boundsCollectionFlat;
        if (bc != null && bc.length >= 4) {
          // ✅ NO Y-flip: PdfTextLine.bounds are already in PDF space
          for (int i = 0; i + 3 < bc.length; i += 4) {
            final rect = Rect.fromLTWH(bc[i], bc[i + 1], bc[i + 2], bc[i + 3]);
            _addAnnotation(page, rect, pdfColor, h);
          }
        } else if (h.bounds.length >= 4 && h.bounds[2] > 1) {
          final b = h.bounds;
          final rect = Rect.fromLTWH(b[0], b[1], b[2], b[3]);
          _addAnnotation(page, rect, pdfColor, h);
        } else {
          // Last resort: text search fallback
          try {
            final results = PdfTextExtractor(document).findText(
              [h.text],
              startPageIndex: pageIdx,
              endPageIndex: pageIdx,
            );
            for (final m in results) {
              _addAnnotation(page, m.bounds, pdfColor, h);
            }
          } catch (_) {}
        }
      }
      final bytes = Uint8List.fromList(await document.save());
      document.dispose();
      return bytes;
    } catch (e) {
      document.dispose();
      debugPrint('[PdfAnnotationService] error: $e');
      return pdfBytes;
    }
  }

  static void _addAnnotation(
      PdfPage page, Rect rect, PdfColor color, PlainHighlight h) {
    if (rect.width < 1 || rect.height < 1) return;
    final a = PdfTextMarkupAnnotation(
      rect,
      h.note ?? '',
      color,
      author: 'ReadVerse',
      subject: 'Highlight',
      textMarkupAnnotationType: PdfTextMarkupAnnotationType.highlight,
      modifiedDate: h.createdAt,
    );
    a.opacity = 0.55;
    page.annotations.add(a);
  }

  static Future<Uint8List> injectHighlights({
    required Uint8List pdfBytes,
    required List<HighlightModel> highlights,
  }) =>
      injectPlainHighlights(
        pdfBytes: pdfBytes,
        highlights: highlights.map(PlainHighlight.fromModel).toList(),
      );
}