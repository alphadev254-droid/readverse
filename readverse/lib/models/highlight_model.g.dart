// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'highlight_model.dart';

class HighlightModelAdapter extends TypeAdapter<HighlightModel> {
  @override
  final int typeId = 2;

  @override
  HighlightModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HighlightModel(
      id: fields[0] as String,
      docId: fields[1] as String,
      page: fields[2] as int,
      text: fields[3] as String,
      colorValue: fields[4] as int,
      note: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      bounds: (fields[7] as List?)?.cast<double>() ?? [0, 0, 0, 0],
      boundsCollectionFlat: (fields[8] as List?)?.cast<double>(),
    );
  }

  @override
  void write(BinaryWriter writer, HighlightModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.docId)
      ..writeByte(2)
      ..write(obj.page)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.bounds)
      ..writeByte(8)
      ..write(obj.boundsCollectionFlat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
