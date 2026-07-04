import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/sensor_data.dart';
import 'widgets/unified_farm_map.dart';

class MapScreen extends StatelessWidget {
  final List<SensorNode> envTemp;
  final List<SensorNode> envHumid;
  final List<SensorNode> envLight;
  final List<SensorNode> envCO2;

  final List<SensorNode> soilEC;
  final List<SensorNode> soilRH;

  final List<SensorNode> waterEC;
  final List<SensorNode> waterNPK;

  const MapScreen({
    Key? key,
    required this.envTemp,
    required this.envHumid,
    required this.envLight,
    required this.envCO2,
    required this.soilEC,
    required this.soilRH,
    required this.waterEC,
    required this.waterNPK,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text('Sensor Map', style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 1,
      ),
      body: UnifiedFarmMap(
        envTemp: envTemp,
        envHumid: envHumid,
        envLight: envLight,
        envCO2: envCO2,
        soilEC: soilEC,
        soilRH: soilRH,
        waterEC: waterEC,
        waterNPK: waterNPK,
      ),
    );
  }
}
