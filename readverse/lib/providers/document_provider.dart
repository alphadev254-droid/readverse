import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../services/storage_service.dart';
import '../services/file_service.dart';

class DocumentProvider extends ChangeNotifier {
  List<DocumentModel> _allDocuments = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<DocumentModel> get allDocuments => _filteredDocuments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  List<DocumentModel> get _filteredDocuments {
    if (_searchQuery.isEmpty) return List.from(_allDocuments);
    return _allDocuments
        .where((d) => d.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> loadDocuments() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allDocuments = StorageService.getAllDocuments();
      _allDocuments.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DocumentModel?> addDocument(String filePath, String fileName) async {
    _isLoading = true;
    notifyListeners();
    try {
      final ext = FileService.getFileExtension(filePath);
      final id = const Uuid().v4();
      final size = await FileService.getFileSize(filePath);

      // Copy file to app documents directory
      final destPath = await FileService.copyToAppDirectory(filePath, '$id.$ext');

      final doc = DocumentModel(
        id: id,
        name: fileName.replaceAll('.$ext', ''),
        type: ext,
        filePath: destPath,
        uploadDate: DateTime.now(),
        fileSizeBytes: size,
      );

      await StorageService.saveDocument(doc);
      _allDocuments.insert(0, doc);
      notifyListeners();
      return doc;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDocument(String id) async {
    final doc = _allDocuments.firstWhere((d) => d.id == id);
    await FileService.deleteFile(doc.filePath);
    if (doc.thumbnailPath != null) {
      await FileService.deleteFile(doc.thumbnailPath!);
    }
    await StorageService.deleteDocument(id);
    _allDocuments.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  Future<void> updateProgress(String id, int page, int totalPages) async {
    final index = _allDocuments.indexWhere((d) => d.id == id);
    if (index == -1) return;
    final doc = _allDocuments[index];
    final progress = totalPages > 0 ? page / totalPages : 0.0;
    final updated = doc.copyWith(
      lastPage: page,
      totalPages: totalPages,
      readingProgress: progress,
      lastOpened: DateTime.now(),
    );
    _allDocuments[index] = updated;
    await StorageService.saveDocument(updated);
    notifyListeners();
    // TODO: Sync progress to backend
  }

  void searchDocuments(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  DocumentModel? getDocumentById(String id) {
    try {
      return _allDocuments.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
