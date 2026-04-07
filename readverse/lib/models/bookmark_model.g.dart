// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_model.dart';

class BookmarkModelAdapter extends TypeAdapter<BookmarkModel> {
  @override
  final int typeId = 1;

  @override
  BookmarkModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookmarkModel(
      id: fields[0] as String,
      docId: fields[1] as String,
      page: fields[2] as int,
      title: fields[3] as String,
      note: fields[4] as String?,
      colorValue: fields[5] as int,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BookmarkModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.docId)
      ..writeByte(2)
      ..write(obj.page)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.colorValue)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
