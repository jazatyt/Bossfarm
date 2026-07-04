// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ZoneConfigAdapter extends TypeAdapter<ZoneConfig> {
  @override
  final int typeId = 1;

  @override
  ZoneConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ZoneConfig()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..rows = fields[2] as int
      ..cols = fields[3] as int
      ..rectLeft = fields[4] as double
      ..rectTop = fields[5] as double
      ..rectWidth = fields[6] as double
      ..rectHeight = fields[7] as double;
  }

  @override
  void write(BinaryWriter writer, ZoneConfig obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.rows)
      ..writeByte(3)
      ..write(obj.cols)
      ..writeByte(4)
      ..write(obj.rectLeft)
      ..writeByte(5)
      ..write(obj.rectTop)
      ..writeByte(6)
      ..write(obj.rectWidth)
      ..writeByte(7)
      ..write(obj.rectHeight);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoneConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
