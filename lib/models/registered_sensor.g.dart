// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registered_sensor.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RegisteredSensorAdapter extends TypeAdapter<RegisteredSensor> {
  @override
  final int typeId = 2;

  @override
  RegisteredSensor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RegisteredSensor()
      ..deviceId = fields[0] as String
      ..label = fields[1] as String
      ..registeredAt = fields[2] as DateTime;
  }

  @override
  void write(BinaryWriter writer, RegisteredSensor obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.registeredAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisteredSensorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
