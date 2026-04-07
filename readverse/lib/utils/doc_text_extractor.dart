import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DocTextExtractor {
  /// Extracts full plain text from PDF, TXT, MD, or DOCX.
  static Future<String> extract(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return _extractPdf(filePath);
      case 'txt':
      case 'md':
        return File(filePath).readAsString();
      case 'docx':
        return _extractDocx(filePath);
      default:
        return '';
    }
  }

  static Future<String> _extractPdf(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      debugPrint('[DocTextExtractor] PDF error: $e');
      return '';
    }
  }

  static Future<String> _extractDocx(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final xmlFile = archive.findFile('word/document.xml');
      if (xmlFile == null) return '';
      final xml = String.fromCharCodes(xmlFile.content as List<int>);
      final text = xml
          .replaceAll(RegExp(r'<w:br[^/]*/?>'), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&apos;', "'")
          .replaceAll('&quot;', '"')
          .replaceAll(RegExp(r' {2,}'), ' ')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      return text;
    } catch (e) {
      debugPrint('[DocTextExtractor] DOCX error: $e');
      return '';
    }
  }
}
