import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/sensor_data.dart';

class SensorDetailPage extends StatelessWidget {
  final String metricName;
  final String unit;
  final List<SensorNode> sensors;

  const SensorDetailPage({
    Key? key,
    required this.metricName,
    required this.sensors,
    required this.unit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine overall stats
    int warningCount = sensors.where((s) => s.isWarning).length;
    double averageVal = 0;
    if (sensors.isNotEmpty) {
      if (metricName != 'แสง' && !metricName.contains('NPK')) {
        averageVal = sensors.map((s) => s.numericValue).reduce((a, b) => a + b) / sensors.length;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'รายละเอียด $metricName',
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Status Summary Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatInfo('เซนเซอร์ทั้งหมด', '${sensors.length} ตัว', Colors.blue),
                if (averageVal > 0)
                  _buildStatInfo('ค่าเฉลี่ย', '${averageVal.toStringAsFixed(1)} $unit', Colors.orange),
                _buildStatInfo('แจ้งเตือน', '$warningCount ตัว', warningCount > 0 ? Colors.red : Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: sensors.length,
              itemBuilder: (context, index) {
                final node = sensors[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: node.isWarning ? Colors.red.shade100 : Colors.green.shade100,
                      child: Icon(
                        node.isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: node.isWarning ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(node.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    trailing: Text(
                      '${node.valueDisplay} ${node.unit}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: node.isWarning ? Colors.red : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
