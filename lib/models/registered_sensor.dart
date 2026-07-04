import 'package:hive/hive.dart';

part 'registered_sensor.g.dart';

@HiveType(typeId: 2)
class RegisteredSensor extends HiveObject {
  @HiveField(0) late String deviceId;     // "IESWIC3A_61:D4" จาก QR / InfluxDB
  @HiveField(1) late String label;        // ชื่อที่ตั้งเอง
  @HiveField(2) late DateTime registeredAt;
}
