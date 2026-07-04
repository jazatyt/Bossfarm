import 'package:hive/hive.dart';

part 'sensor_slot.g.dart';

@HiveType(typeId: 0)
class SensorSlot extends HiveObject {
  @HiveField(0) late String id;           // "slot_ZoneA_0"
  @HiveField(1) late String zoneId;       // "zone_a"
  @HiveField(2) late double x;            // 0.0–1.0 relative position
  @HiveField(3) late double y;
  @HiveField(4) String? deviceId;         // null = ว่าง
  @HiveField(5) late int order;           // ลำดับเติม
}
