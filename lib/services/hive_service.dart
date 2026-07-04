import 'package:hive_flutter/hive_flutter.dart';
import '../models/registered_sensor.dart';

class HiveService {
  static const _sensorBox   = 'registered_sensors';

  // ── Init ──────────────────────────────────────
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(RegisteredSensorAdapter());
    await Hive.openBox<RegisteredSensor>(_sensorBox);
  }

  // ── Register sensor ───────────────────────────
  static Future<RegisteredSensor?> registerSensor({
    required String deviceId,
    required String label,
  }) async {
    final sensorBox = Hive.box<RegisteredSensor>(_sensorBox);

    // ตรวจว่า device นี้ลงทะเบียนแล้วหรือยัง
    if (sensorBox.containsKey(deviceId)) return sensorBox.get(deviceId);

    final sensor = RegisteredSensor()
      ..deviceId     = deviceId
      ..label        = label
      ..registeredAt = DateTime.now();

    await sensorBox.put(deviceId, sensor);
    return sensor;
  }

  // ── Getters ───────────────────────────────────
  static List<RegisteredSensor> getAllSensors() =>
      Hive.box<RegisteredSensor>(_sensorBox).values.toList();

  static RegisteredSensor? getSensorByDeviceId(String deviceId) =>
      Hive.box<RegisteredSensor>(_sensorBox).get(deviceId);
}
