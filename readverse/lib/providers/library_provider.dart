import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../services/storage_service.dart';

class LibraryProvider extends ChangeNotifier {
  List<String> _libraryIds = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<String> get libraryIds => _libraryIds;

  Future<void> loadLibrary() async {
    _libraryIds = StorageService.getLibraryIds();
    notifyListeners();
  }

  bool isInLibrary(String docId) => _libraryIds.contains(docId);

  Future<void> addToLibrary(String docId) async {
    if (!_libraryIds.contains(docId)) {
      _libraryIds.add(docId);
      await StorageService.saveLibraryIds(_libraryIds);
      notifyListeners();
      // TODO: POST /library { documentId }
    }
  }

  Future<void> removeFromLibrary(String docId) async {
    _libraryIds.remove(docId);
    await StorageService.saveLibraryIds(_libraryIds);
    notifyListeners();
    // TODO: DELETE /library/:documentId
  }

  Future<void> toggleLibrary(String docId) async {
    if (isInLibrary(docId)) {
      await removeFromLibrary(docId);
    } else {
      await addToLibrary(docId);
    }
  }

  List<DocumentModel> getLibraryDocuments(List<DocumentModel> allDocs) =>
      allDocs.where((d) => _libraryIds.contains(d.id)).toList();
}
