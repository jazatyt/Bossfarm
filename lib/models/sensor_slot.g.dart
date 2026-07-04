// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sensor_slot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SensorSlotAdapter extends TypeAdapter<SensorSlot> {
  @override
  final int typeId = 0;

  @override
  SensorSlot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SensorSlot()
      ..id = fields[0] as String
      ..zoneId = fields[1] as String
      ..x = fields[2] as double
      ..y = fields[3] as double
      ..deviceId = fields[4] as String?
      ..order = fields[5] as int;
  }

  @override
  void write(BinaryWriter writer, SensorSlot obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.zoneId)
      ..writeByte(2)
      ..write(obj.x)
      ..writeByte(3)
      ..write(obj.y)
      ..writeByte(4)
      ..write(obj.deviceId)
      ..writeByte(5)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorSlotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
