import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/highlight_model.dart';
import '../services/storage_service.dart';

class HighlightProvider extends ChangeNotifier {
  List<HighlightModel> _highlights = [];
  bool _isLoading = false;

  List<HighlightModel> get highlights => _highlights;
  bool get isLoading => _isLoading;

  Future<void> loadHighlights(String docId) async {
    _isLoading = true;
    notifyListeners();
    _highlights = StorageService.getHighlightsForDoc(docId);
    _highlights.sort((a, b) => a.page.compareTo(b.page));
    _isLoading = false;
    notifyListeners();
  }

  Future<String> addHighlight({
    required String docId,
    required int page,
    required String text,
    required int colorValue,
    String? note,
    List<double> bounds = const [0, 0, 0, 0],
    List<double>? boundsCollectionFlat,
  }) async {
    final highlight = HighlightModel(
      id: const Uuid().v4(),
      docId: docId,
      page: page,
      text: text,
      colorValue: colorValue,
      note: note,
      createdAt: DateTime.now(),
      bounds: bounds,
      boundsCollectionFlat: boundsCollectionFlat,
    );
    await StorageService.saveHighlight(highlight);
    _highlights.add(highlight);
    notifyListeners();
    return highlight.id;
  }

  Future<void> editHighlight(String id, {String? note}) async {
    final index = _highlights.indexWhere((h) => h.id == id);
    if (index == -1) return;
    final h = _highlights[index];
    final updated = HighlightModel(
      id: h.id,
      docId: h.docId,
      page: h.page,
      text: h.text,
      colorValue: h.colorValue,
      note: note ?? h.note,
      createdAt: h.createdAt,
      bounds: h.bounds,
      boundsCollectionFlat: h.boundsCollectionFlat,
    );
    await StorageService.saveHighlight(updated);
    _highlights[index] = updated;
    notifyListeners();
  }

  Future<void> deleteHighlight(String id) async {
    await StorageService.deleteHighlight(id);
    _highlights.removeWhere((h) => h.id == id);
    notifyListeners();
  }

  // Alias used by PdfReader.deleteHighlight
  Future<void> removeHighlight(String id) => deleteHighlight(id);

  List<HighlightModel> getByPage(int page) =>
      _highlights.where((h) => h.page == page).toList();

  String exportAsText(String docName) {
    final buffer = StringBuffer();
    buffer.writeln('Highlights from: $docName');
    buffer.writeln('Exported: ${DateTime.now()}');
    buffer.writeln('---');
    for (final h in _highlights) {
      buffer.writeln('Page ${h.page + 1}: "${h.text}"');
      if (h.note != null) buffer.writeln('Note: ${h.note}');
      buffer.writeln();
    }
    return buffer.toString();
  }
}
