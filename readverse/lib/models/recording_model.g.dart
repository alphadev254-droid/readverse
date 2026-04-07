
part of 'recording_model.dart';

class RecordingModelAdapter extends TypeAdapter<RecordingModel> {
  @override
  final int typeId = 3;

  @override
  RecordingModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecordingModel(
      id: fields[0] as String,
      name: fields[1] as String,
      filePath: fields[2] as String,
      createdAt: fields[3] as DateTime,
      durationSeconds: fields[4] as int,
      fileSizeBytes: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RecordingModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.durationSeconds)
      ..writeByte(5)
      ..write(obj.fileSizeBytes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
