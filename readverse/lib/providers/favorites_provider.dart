import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../services/storage_service.dart';

class FavoritesProvider extends ChangeNotifier {
  List<String> _favoriteIds = [];

  List<String> get favoriteIds => _favoriteIds;

  Future<void> loadFavorites() async {
    _favoriteIds = StorageService.getFavoriteIds();
    notifyListeners();
  }

  bool isFavorite(String docId) => _favoriteIds.contains(docId);

  Future<void> addToFavorites(String docId) async {
    if (!_favoriteIds.contains(docId)) {
      _favoriteIds.add(docId);
      await StorageService.saveFavoriteIds(_favoriteIds);
      notifyListeners();
      // TODO: POST /favorites { documentId }
    }
  }

  Future<void> removeFromFavorites(String docId) async {
    _favoriteIds.remove(docId);
    await StorageService.saveFavoriteIds(_favoriteIds);
    notifyListeners();
    // TODO: DELETE /favorites/:documentId
  }

  Future<void> toggleFavorite(String docId) async {
    if (isFavorite(docId)) {
      await removeFromFavorites(docId);
    } else {
      await addToFavorites(docId);
    }
  }

  List<DocumentModel> getFavoriteDocuments(List<DocumentModel> allDocs) =>
      allDocs.where((d) => _favoriteIds.contains(d.id)).toList();
}
