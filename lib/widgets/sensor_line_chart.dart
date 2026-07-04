import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SensorLineChart extends StatelessWidget {
  final List<dynamic> data;
  final Color themeColor;

  final String? label;
  final String? unit;

  const SensorLineChart({
    Key? key,
    required this.data,
    this.themeColor = Colors.teal,
    this.label,
    this.unit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data points available'));
    }

    // Process data into FlSpot
    List<FlSpot> spots = [];
    DateTime? minTime;
    DateTime? maxTime;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    // We take the last 20-30 points if the list is too long for better performance/visibility
    // or just show all if it's reasonable. For sensors, 20-50 is usually fine.
    // Use data as is (assuming chronological order: oldest to newest)
    final displayData = List.from(data);

    for (var i = 0; i < displayData.length; i++) {
      final item = displayData[i];
      final timeStr = item['_time']?.toString() ?? '';
      final valueObj = item['_value'];
      
      double value = 0.0;
      if (valueObj is num) {
        value = valueObj.toDouble();
      } else if (valueObj is String) {
        value = double.tryParse(valueObj) ?? 0.0;
      }

      DateTime time;
      try {
        time = DateTime.parse(timeStr).toLocal();
      } catch (_) {
        time = DateTime.now();
      }

      if (minTime == null || time.isBefore(minTime)) minTime = time;
      if (maxTime == null || time.isAfter(maxTime)) maxTime = time;
      if (value < minY) minY = value;
      if (value > maxY) maxY = value;

      // Use index i as X axis (moving from 0 to length-1)
      spots.add(FlSpot(i.toDouble(), value));
    }

    if (spots.isEmpty) {
      return const Center(child: Text('Waiting for data...'));
    }

    // Add some padding to Y axis
    double yPadding = (maxY - minY) * 0.2;
    if (yPadding == 0) yPadding = 5.0;
    minY = (minY - yPadding).clamp(0, double.infinity);
    maxY = maxY + yPadding;

    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 20, top: 10, bottom: 10),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (displayData.length / 5).clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= displayData.length) return const SizedBox.shrink();
                  
                  final timeStr = displayData[index]['_time']?.toString() ?? '';
                  try {
                    final dt = DateTime.parse(timeStr).toLocal();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: ((maxY - minY) / 4).clamp(0.1, double.infinity),
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (displayData.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: themeColor,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: themeColor,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    themeColor.withOpacity(0.3),
                    themeColor.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  
                  String displayLabel = label ?? '';
                  String displayUnit = unit ?? '';
                  
                  // Auto-prefix/unit mapping if not provided but we have clues from metric names in caller
                  // However, for consistency we'll rely on what's passed in.
                  
                  return LineTooltipItem(
                    '${displayLabel.isNotEmpty ? "$displayLabel " : ""}${flSpot.y.toStringAsFixed(1)}${displayUnit.isNotEmpty ? " $displayUnit" : ""}'.trim(),
                    GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
