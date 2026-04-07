import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'highlight_model.g.dart';

@HiveType(typeId: 2)
class HighlightModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String docId;

  @HiveField(2)
  int page; // 0-based page index

  @HiveField(3)
  String text;

  @HiveField(4)
  int colorValue;

  @HiveField(5)
  String? note;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  List<double> bounds; // [left, top, width, height]

  @HiveField(8)
  List<double>? boundsCollectionFlat; // flattened: [l,t,w,h, l,t,w,h, ...]

  HighlightModel({
    required this.id,
    required this.docId,
    required this.page,
    required this.text,
    required this.colorValue,
    this.note,
    required this.createdAt,
    required this.bounds,
    this.boundsCollectionFlat,
  });

  Rect get boundsRect =>
      Rect.fromLTWH(bounds[0], bounds[1], bounds[2], bounds[3]);

  List<Rect>? get boundsRectCollection {
    final flat = boundsCollectionFlat;
    if (flat == null || flat.length < 4) return null;
    final rects = <Rect>[];
    for (int i = 0; i + 3 < flat.length; i += 4) {
      rects.add(Rect.fromLTWH(flat[i], flat[i + 1], flat[i + 2], flat[i + 3]));
    }
    return rects;
  }
}
