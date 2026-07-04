import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sensor_data.dart';

class UnifiedFarmMap extends StatefulWidget {
  final List<SensorNode> envTemp;
  final List<SensorNode> envHumid;
  final List<SensorNode> envLight;
  final List<SensorNode> envCO2;

  final List<SensorNode> soilEC;
  final List<SensorNode> soilRH;

  final List<SensorNode> waterEC;
  final List<SensorNode> waterNPK;

  const UnifiedFarmMap({
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
  State<UnifiedFarmMap> createState() => _UnifiedFarmMapState();
}

class _UnifiedFarmMapState extends State<UnifiedFarmMap> with SingleTickerProviderStateMixin {
  late AnimationController _warningController;

  @override
  void initState() {
    super.initState();
    _warningController = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _warningController.dispose();
    super.dispose();
  }

  void _showNodeDetails(BuildContext context, String title, Color color, List<String> details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: details.map((d) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(d, style: GoogleFonts.inter(fontSize: 16, color: Colors.black87)),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ปิด', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: color)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double mapWidth = 900.0;
    const double mapHeight = 500.0;
    const int cols = 4;
    const int rows = 3;
    const double cellWidth = mapWidth / cols;
    const double cellHeight = mapHeight / rows;

    return Column(
      children: [
        _buildLegend(),
        Expanded(
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.1,
            maxScale: 2.0,
            boundaryMargin: const EdgeInsets.all(500),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(100.0),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Background Grid
                        CustomPaint(
                          size: const Size(mapWidth, mapHeight),
                          painter: MapGridPainter(cols: cols, rows: rows),
                        ),

                        // Soil Sensors (Green Dots) - Distributed among 12 cells
                        ..._buildSoilSensors(cellWidth, cellHeight),

                        // Environment Sensors (Red Dots) - At intersections
                        ..._buildEnvSensors(cellWidth, cellHeight),

                        // Water Pump (Big Blue Dot)
                        _buildWaterPump(mapWidth, mapHeight),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem('เซนเซอร์ในดิน', const Color(0xFF4CAF50)),
          const SizedBox(width: 24),
          _legendItem('เซนเซอร์อากาศ', const Color(0xFFF44336)),
          const SizedBox(width: 24),
          _legendItem('ระบบควบคุมน้ำ', const Color(0xFF2196F3)),
          const SizedBox(width: 24),
          _legendItem('สถานะแจ้งเตือน', Colors.orange, isWarning: true),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, {bool isWarning = false}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isWarning ? Border.all(color: Colors.white, width: 2) : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
      ],
    );
  }

  List<Widget> _buildSoilSensors(double cellWidth, double cellHeight) {
    List<Widget> sensors = [];
    int totalSensors = widget.soilEC.length; // 250
    int totalCells = 4 * 3;
    int basePerCell = totalSensors ~/ totalCells; // 250 / 12 = 20
    int remaining = totalSensors % totalCells; // 10

    int sensorIndex = 0;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 4; c++) {
        int cellId = r * 4 + c;
        int countInThisCell = basePerCell + (cellId < remaining ? 1 : 0);
        
        // Arrange dots in a sub-grid inside the cell
        int gridCols = 5;
        double padding = 20.0;
        double availableW = cellWidth - (padding * 2);
        double availableH = cellHeight - (padding * 2);
        double stepX = availableW / (gridCols - 1);
        double stepY = availableH / 4.0; // Assume 5 rows

        for (int i = 0; i < countInThisCell; i++) {
          if (sensorIndex >= totalSensors) break;

          int gx = i % gridCols;
          int gy = i ~/ gridCols;

          double posX = c * cellWidth + padding + gx * stepX;
          double posY = r * cellHeight + padding + gy * stepY;

          int idx = sensorIndex;
          bool hasWarning = widget.soilEC[idx].isWarning || widget.soilRH[idx].isWarning;
          
          sensors.add(
            Positioned(
              left: posX - 8,
              top: posY - 8,
              child: GestureDetector(
                onTap: () => _showNodeDetails(
                  context,
                  'จุดวัดที่ ${idx + 1}',
                  const Color(0xFF4CAF50),
                  [
                    'EC ในดิน: ${widget.soilEC[idx].valueDisplay} ${widget.soilEC[idx].unit}',
                    'ความชื้น: ${widget.soilRH[idx].valueDisplay} ${widget.soilRH[idx].unit}',
                  ],
                ),
                child: Tooltip(
                  message: 'Soil Node ${idx + 1}',
                  child: AnimatedBuilder(
                    animation: _warningController,
                    builder: (context, child) {
                      return Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: hasWarning 
                              ? Color.lerp(const Color(0xFF4CAF50), Colors.orange, _warningController.value)
                              : const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          boxShadow: hasWarning ? [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 4 * _warningController.value, spreadRadius: 2 * _warningController.value)] : null,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          sensorIndex++;
        }
      }
    }
    return sensors;
  }

  List<Widget> _buildEnvSensors(double cellWidth, double cellHeight) {
    List<Widget> sensors = [];
    List<Offset> positions = [
      Offset(1 * cellWidth, 1 * cellHeight),
      Offset(2 * cellWidth, 1 * cellHeight),
      Offset(3 * cellWidth, 1 * cellHeight),
      Offset(1 * cellWidth, 2 * cellHeight),
      Offset(2 * cellWidth, 2 * cellHeight),
      Offset(3 * cellWidth, 2 * cellHeight),
    ];

    for (int i = 0; i < positions.length; i++) {
      if (i >= widget.envTemp.length) break;

      bool hasWarning = widget.envTemp[i].isWarning || widget.envHumid[i].isWarning || widget.envLight[i].isWarning || widget.envCO2[i].isWarning;

      sensors.add(
        Positioned(
          left: positions[i].dx - 15,
          top: positions[i].dy - 15,
          child: GestureDetector(
            onTap: () => _showNodeDetails(
              context,
              'จุดควบคุมอากาศ ${i + 1}',
              const Color(0xFFF44336),
              [
                'อุณหภูมิ: ${widget.envTemp[i].valueDisplay} ${widget.envTemp[i].unit}',
                'ความชื้นสัมพัทธ์: ${widget.envHumid[i].valueDisplay} ${widget.envHumid[i].unit}',
                'ความเข้มแสง: ${widget.envLight[i].valueDisplay}',
                'ก๊าซ CO2: ${widget.envCO2[i].valueDisplay} ${widget.envCO2[i].unit}',
              ],
            ),
            child: Tooltip(
              message: 'Env Node ${i + 1}',
              child: AnimatedBuilder(
                animation: _warningController,
                builder: (context, child) {
                  return Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: hasWarning ? Colors.redAccent : const Color(0xFFF44336),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: (hasWarning ? Colors.red : Colors.black).withOpacity(0.2), 
                          blurRadius: 8, 
                          spreadRadius: hasWarning ? _warningController.value * 4 : 0
                        )
                      ],
                    ),
                    child: const Center(child: Icon(Icons.sensors, color: Colors.white, size: 16)),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }
    return sensors;
  }

  Widget _buildWaterPump(double mapWidth, double mapHeight) {
    if (widget.waterEC.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: -180, // Separated further from the grid table
      bottom: -60,
      child: GestureDetector(
        onTap: () => _showNodeDetails(
          context,
          'ระบบแม่ปุ๋ยและน้ำ',
          const Color(0xFF2196F3),
          [
            'ค่า EC น้ำ: ${widget.waterEC[0].valueDisplay} ${widget.waterEC[0].unit}',
            'สัดส่วน NPK: ${widget.waterNPK[0].valueDisplay}',
            'สถานะปั๊ม: พร้อมทำงาน',
          ],
        ),
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2196F3), width: 4),
            boxShadow: [
              BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop, color: Color(0xFF2196F3), size: 48),
              const SizedBox(height: 4),
              Text(
                'Water Sys',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2196F3)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class MapGridPainter extends CustomPainter {
  final int cols;
  final int rows;

  MapGridPainter({required this.cols, required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Offset.zero & size, paint);

    double cellWidth = size.width / cols;
    for (int i = 1; i < cols; i++) {
        canvas.drawLine(Offset(i * cellWidth, 0), Offset(i * cellWidth, size.height), paint);
    }

    double cellHeight = size.height / rows;
    for (int i = 1; i < rows; i++) {
        canvas.drawLine(Offset(0, i * cellHeight), Offset(size.width, i * cellHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
