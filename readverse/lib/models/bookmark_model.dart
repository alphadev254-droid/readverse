import 'package:hive_flutter/hive_flutter.dart';

part 'bookmark_model.g.dart';

@HiveType(typeId: 1)
class BookmarkModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String docId;

  @HiveField(2)
  int page;

  @HiveField(3)
  String title;

  @HiveField(4)
  String? note;

  @HiveField(5)
  int colorValue;

  @HiveField(6)
  DateTime createdAt;

  BookmarkModel({
    required this.id,
    required this.docId,
    required this.page,
    required this.title,
    this.note,
    required this.colorValue,
    required this.createdAt,
  });
}
