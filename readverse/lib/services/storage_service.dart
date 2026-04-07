import 'package:hive_flutter/hive_flutter.dart';
import '../models/document_model.dart';
import '../models/bookmark_model.dart';
import '../models/highlight_model.dart';
import '../config/constants.dart';

class StorageService {
  static late Box<DocumentModel> _documentsBox;
  static late Box<BookmarkModel> _bookmarksBox;
  static late Box<HighlightModel> _highlightsBox;
  static late Box<dynamic> _libraryBox;
  static late Box<dynamic> _favoritesBox;
  static late Box<dynamic> _settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DocumentModelAdapter());
    Hive.registerAdapter(BookmarkModelAdapter());
    Hive.registerAdapter(HighlightModelAdapter());

    _documentsBox = await Hive.openBox<DocumentModel>(AppConstants.documentsBox);
    _bookmarksBox = await Hive.openBox<BookmarkModel>(AppConstants.bookmarksBox);
    _highlightsBox = await Hive.openBox<HighlightModel>(AppConstants.highlightsBox);
    _libraryBox = await Hive.openBox<dynamic>(AppConstants.libraryBox);
    _favoritesBox = await Hive.openBox<dynamic>(AppConstants.favoritesBox);
    _settingsBox = await Hive.openBox<dynamic>(AppConstants.settingsBox);
  }

  // Documents
  static Future<void> saveDocument(DocumentModel doc) async =>
      await _documentsBox.put(doc.id, doc);

  static Future<void> deleteDocument(String id) async {
    await _documentsBox.delete(id);
    // Clean up related bookmarks and highlights
    final bookmarkKeys = _bookmarksBox.keys
        .where((k) => _bookmarksBox.get(k)?.docId == id)
        .toList();
    await _bookmarksBox.deleteAll(bookmarkKeys);
    final highlightKeys = _highlightsBox.keys
        .where((k) => _highlightsBox.get(k)?.docId == id)
        .toList();
    await _highlightsBox.deleteAll(highlightKeys);
    // Remove from library and favorites lists
    final libIds = getLibraryIds()..remove(id);
    await saveLibraryIds(libIds);
    final favIds = getFavoriteIds()..remove(id);
    await saveFavoriteIds(favIds);
  }

  static List<DocumentModel> getAllDocuments() =>
      _documentsBox.values.toList();

  // Library
  static List<String> getLibraryIds() {
    final raw = _libraryBox.get('ids');
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  static Future<void> saveLibraryIds(List<String> ids) async =>
      await _libraryBox.put('ids', ids);

  // Favorites
  static List<String> getFavoriteIds() {
    final raw = _favoritesBox.get('ids');
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  static Future<void> saveFavoriteIds(List<String> ids) async =>
      await _favoritesBox.put('ids', ids);

  // Bookmarks
  static List<BookmarkModel> getBookmarksForDoc(String docId) =>
      _bookmarksBox.values.where((b) => b.docId == docId).toList();

  static Future<void> saveBookmark(BookmarkModel bookmark) async =>
      await _bookmarksBox.put(bookmark.id, bookmark);

  static Future<void> deleteBookmark(String id) async =>
      await _bookmarksBox.delete(id);

  // Highlights
  static List<HighlightModel> getHighlightsForDoc(String docId) =>
      _highlightsBox.values.where((h) => h.docId == docId).toList();

  static Future<void> saveHighlight(HighlightModel highlight) async =>
      await _highlightsBox.put(highlight.id, highlight);

  static Future<void> deleteHighlight(String id) async =>
      await _highlightsBox.delete(id);

  // Settings
  static T? getSetting<T>(String key) => _settingsBox.get(key) as T?;
  static Future<void> saveSetting(String key, dynamic value) async =>
      await _settingsBox.put(key, value);

  static Future<int> calculateStorageBytes() async {
    return _documentsBox.values.fold<int>(0, (sum, doc) => sum + doc.fileSizeBytes);
  }

  static Future<void> clearCache() async {
    // Placeholder — clears no actual user data
  }
}
