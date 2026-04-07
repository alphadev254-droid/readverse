import 'package:hive_flutter/hive_flutter.dart';

part 'recording_model.g.dart';

@HiveType(typeId: 3)
class RecordingModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String filePath;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  int durationSeconds;

  @HiveField(5)
  int fileSizeBytes;

  RecordingModel({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
    this.durationSeconds = 0,
    this.fileSizeBytes = 0,
  });

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
