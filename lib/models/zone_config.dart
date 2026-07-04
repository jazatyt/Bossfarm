import 'package:hive/hive.dart';

part 'zone_config.g.dart';

@HiveType(typeId: 1)
class ZoneConfig extends HiveObject {
  @HiveField(0) late String id;       // "zone_a"
  @HiveField(1) late String name;     // "โซน A — ผัก"
  @HiveField(2) late int rows;        // จำนวนแถว
  @HiveField(3) late int cols;        // จำนวนคอลัมน์
  @HiveField(4) late double rectLeft;
  @HiveField(5) late double rectTop;
  @HiveField(6) late double rectWidth;
  @HiveField(7) late double rectHeight;
}
