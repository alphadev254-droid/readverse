import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/bookmark_model.dart';
import '../services/storage_service.dart';
// ignore_for_file: unused_field

class BookmarkProvider extends ChangeNotifier {
  List<BookmarkModel> _bookmarks = [];
  bool _isLoading = false;
  String? _currentDocId; // used for future API sync

  List<BookmarkModel> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;

  Future<void> loadBookmarks(String docId) async {
    _currentDocId = docId;
    _isLoading = true;
    notifyListeners();
    _bookmarks = StorageService.getBookmarksForDoc(docId);
    _bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _isLoading = false;
    notifyListeners();
    // TODO: GET /bookmarks/:docId
  }

  Future<void> addBookmark({
    required String docId,
    required int page,
    required String title,
    String? note,
    int colorValue = 0xFFF44336,
  }) async {
    final bookmark = BookmarkModel(
      id: const Uuid().v4(),
      docId: docId,
      page: page,
      title: title,
      note: note,
      colorValue: colorValue,
      createdAt: DateTime.now(),
    );
    await StorageService.saveBookmark(bookmark);
    _bookmarks.insert(0, bookmark);
    notifyListeners();
    // TODO: POST /bookmarks
  }

  Future<void> editBookmark(String id, {String? title, String? note}) async {
    final index = _bookmarks.indexWhere((b) => b.id == id);
    if (index == -1) return;
    final b = _bookmarks[index];
    final updated = BookmarkModel(
      id: b.id,
      docId: b.docId,
      page: b.page,
      title: title ?? b.title,
      note: note ?? b.note,
      colorValue: b.colorValue,
      createdAt: b.createdAt,
    );
    await StorageService.saveBookmark(updated);
    _bookmarks[index] = updated;
    notifyListeners();
  }

  Future<void> deleteBookmark(String id) async {
    await StorageService.deleteBookmark(id);
    _bookmarks.removeWhere((b) => b.id == id);
    notifyListeners();
    // TODO: DELETE /bookmarks/:id
  }

  void sortByPage() {
    _bookmarks.sort((a, b) => a.page.compareTo(b.page));
    notifyListeners();
  }

  void sortByRecent() {
    _bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  void sortByTitle() {
    _bookmarks.sort((a, b) => a.title.compareTo(b.title));
    notifyListeners();
  }
}
