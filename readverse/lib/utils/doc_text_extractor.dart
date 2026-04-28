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
      // Run PDF extraction in background isolate to avoid UI freeze
      return await compute(_extractPdfInIsolate, filePath);
    } catch (e) {
      debugPrint('[DocTextExtractor] PDF error: $e');
      return '';
    }
  }

  static String _extractPdfInIsolate(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      debugPrint('[DocTextExtractor] PDF isolate error: $e');
      return '';
    }
  }

  static Future<String> _extractDocx(String filePath) async {
    try {
      // Run DOCX extraction in background isolate to avoid UI freeze
      return await compute(_extractDocxInIsolate, filePath);
    } catch (e) {
      debugPrint('[DocTextExtractor] DOCX error: $e');
      return '';
    }
  }

  static String _extractDocxInIsolate(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final xmlFile = archive.findFile('word/document.xml');
      if (xmlFile == null) return '';
      final xml = String.fromCharCodes(xmlFile.content as List<int>);
      
      debugPrint('[DocTextExtractor] Raw XML length: ${xml.length}');
      
      final text = xml
          // Paragraph tags → newline (sentence boundary)
          .replaceAll(RegExp(r'<w:p[ >][^>]*>|<w:p/>'), '\n')
          // Line breaks → newline
          .replaceAll(RegExp(r'<w:br[^>]*/?>'), '\n')
          // Table cells/rows → space + newline
          .replaceAll(RegExp(r'<w:tc[ >][^>]*>|<w:tc/>'), ' ')
          .replaceAll(RegExp(r'<w:tr[ >][^>]*>|<w:tr/>'), '\n')
          // Strip remaining tags
          .replaceAll(RegExp(r'<[^>]+>'), '')
          // XML entities
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&apos;', "'")
          .replaceAll('&quot;', '"')
          .replaceAll('&#x2019;', "'")
          .replaceAll('&#x2018;', "'")
          .replaceAll('&#x201C;', '"')
          .replaceAll('&#x201D;', '"')
          .replaceAll('&#x2013;', '-')
          .replaceAll('&#x2014;', '-')
          // Collapse spaces (but preserve newlines)
          .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      
      debugPrint('[DocTextExtractor] Extracted text length: ${text.length}');
      debugPrint('[DocTextExtractor] First 200 chars: "${text.length > 200 ? text.substring(0, 200) : text}"');
      
      return text;
    } catch (e) {
      debugPrint('[DocTextExtractor] DOCX isolate error: $e');
      return '';
    }
  }
}
