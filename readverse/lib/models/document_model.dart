import 'package:hive_flutter/hive_flutter.dart';

part 'document_model.g.dart';

@HiveType(typeId: 0)
class DocumentModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type; // 'pdf', 'epub', 'docx', 'txt', 'md'

  @HiveField(3)
  String filePath;

  @HiveField(4)
  DateTime uploadDate;

  @HiveField(5)
  int lastPage;

  @HiveField(6)
  int totalPages;

  @HiveField(7)
  double readingProgress; // 0.0 to 1.0

  @HiveField(8)
  String? thumbnailPath;

  @HiveField(9)
  int fileSizeBytes;

  @HiveField(10)
  DateTime? lastOpened;

  @HiveField(11)
  int totalReadingSeconds;

  DocumentModel({
    required this.id,
    required this.name,
    required this.type,
    required this.filePath,
    required this.uploadDate,
    this.lastPage = 0,
    this.totalPages = 0,
    this.readingProgress = 0.0,
    this.thumbnailPath,
    this.fileSizeBytes = 0,
    this.lastOpened,
    this.totalReadingSeconds = 0,
  });

  bool get isPdf => type.toLowerCase() == 'pdf';
  bool get isEpub => type.toLowerCase() == 'epub';
  bool get isTxt => type.toLowerCase() == 'txt';
  bool get isMd => type.toLowerCase() == 'md';
  bool get isDocx => type.toLowerCase() == 'docx';
  bool get isTextBased => isTxt || isMd;

  String get formattedSize {
    if (fileSizeBytes < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  int get progressPercent => (readingProgress * 100).round();

  DocumentModel copyWith({
    int? lastPage,
    int? totalPages,
    double? readingProgress,
    String? thumbnailPath,
    DateTime? lastOpened,
    int? totalReadingSeconds,
  }) {
    return DocumentModel(
      id: id,
      name: name,
      type: type,
      filePath: filePath,
      uploadDate: uploadDate,
      lastPage: lastPage ?? this.lastPage,
      totalPages: totalPages ?? this.totalPages,
      readingProgress: readingProgress ?? this.readingProgress,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSizeBytes: fileSizeBytes,
      lastOpened: lastOpened ?? this.lastOpened,
      totalReadingSeconds: totalReadingSeconds ?? this.totalReadingSeconds,
    );
  }
}
