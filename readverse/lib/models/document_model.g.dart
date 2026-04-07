// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = 0;

  @override
  DocumentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DocumentModel(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      filePath: fields[3] as String,
      uploadDate: fields[4] as DateTime,
      lastPage: fields[5] as int,
      totalPages: fields[6] as int,
      readingProgress: fields[7] as double,
      thumbnailPath: fields[8] as String?,
      fileSizeBytes: fields[9] as int,
      lastOpened: fields[10] as DateTime?,
      totalReadingSeconds: fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.filePath)
      ..writeByte(4)
      ..write(obj.uploadDate)
      ..writeByte(5)
      ..write(obj.lastPage)
      ..writeByte(6)
      ..write(obj.totalPages)
      ..writeByte(7)
      ..write(obj.readingProgress)
      ..writeByte(8)
      ..write(obj.thumbnailPath)
      ..writeByte(9)
      ..write(obj.fileSizeBytes)
      ..writeByte(10)
      ..write(obj.lastOpened)
      ..writeByte(11)
      ..write(obj.totalReadingSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
