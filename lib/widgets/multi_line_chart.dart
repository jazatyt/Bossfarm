import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChartSeries {
  final List<dynamic> data;
  final Color color;
  final String label;
  final double normalize;

  ChartSeries({
    required this.data,
    required this.color,
    required this.label,
    this.normalize = 1.0,
  });
}

class MultiLineChart extends StatelessWidget {
  final List<ChartSeries> series;
  final double height;
  final double? fixedMinY;
  final double? fixedMaxY;
  final bool expand;
  final bool independentScale;
  final bool fitTooltipInside;

  const MultiLineChart({
    Key? key,
    required this.series,
    this.height = 80,
    this.fixedMinY,
    this.fixedMaxY,
    this.expand = false,
    this.independentScale = false,
    this.fitTooltipInside = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty || series.every((s) => s.data.isEmpty)) {
      return _noData();
    }

    final List<LineChartBarData> bars = [];
    final List<FlSpot> allSpots = [];
    int maxPoints = 0;
    // Only used when independentScale is true: real (un-normalized) min/max
    // per series color, so the tooltip can reverse the 0-100 display value
    // back to the actual reading.
    final Map<Color, List<double>> seriesRealRange = {};

    for (var s in series) {
      if (s.data.isEmpty) continue;
      List<FlSpot> spots;
      if (independentScale) {
        final rawVals = <double>[];
        final rawSpots = <FlSpot>[];
        for (int i = 0; i < s.data.length; i++) {
          final v = s.data[i]['_value'];
          double? val;
          if (v is num) val = v.toDouble();
          else if (v is String) val = double.tryParse(v);
          if (val != null) {
            rawVals.add(val);
            rawSpots.add(FlSpot(i.toDouble(), val));
          }
        }
        if (rawVals.isEmpty) continue;
        final seriesMin = rawVals.reduce((a, b) => a < b ? a : b);
        final seriesMax = rawVals.reduce((a, b) => a > b ? a : b);
        final range = seriesMax - seriesMin;
        seriesRealRange[s.color] = [seriesMin, seriesMax];
        // Map into an 8-92 band (not the full 0-100) so peaks/troughs that
        // hit a series' own min/max never touch the chart's clip boundary.
        spots = rawSpots
            .map((p) => FlSpot(
                p.x,
                range == 0 ? 50 : 8 + ((p.y - seriesMin) / range) * 84))
            .toList();
      } else {
        spots = _toSpots(s.data, normalize: s.normalize);
      }
      allSpots.addAll(spots);
      bars.add(_bar(spots, s.color));
      if (s.data.length > maxPoints) maxPoints = s.data.length;
    }

    if (allSpots.isEmpty) return _noData();

    final double maxX = maxPoints > 0 ? (maxPoints - 1).toDouble() : 1.0;

    double minY = fixedMinY ?? 0;
    double maxY = fixedMaxY ?? 100;

    if (independentScale) {
      minY = 0;
      maxY = 100;
    } else if (fixedMinY == null || fixedMaxY == null) {
      final allY = allSpots.map((s) => s.y).toList();
      if (fixedMinY == null) {
        minY = (allY.reduce((a, b) => a < b ? a : b) - 2).clamp(0, double.infinity);
      }
      if (fixedMaxY == null) {
        maxY = allY.reduce((a, b) => a > b ? a : b) + 2;
        if (maxY <= minY) maxY = minY + 10;
      }
    }

    return SizedBox(
      height: expand ? double.infinity : height,
      child: LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.08),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: !independentScale && series.any((s) => s.normalize != 1.0),
                reservedSize: 40,
                interval: ((maxY - minY) / 3).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, _) {
                  final normSeries = series.firstWhere((s) => s.normalize != 1.0, orElse: () => series.first);
                  return Text(
                    (value * normSeries.normalize).toInt().toString(),
                    style: GoogleFonts.inter(
                      fontSize: 8.5, 
                      color: normSeries.color, 
                      fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.left,
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: (maxX / 4).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= maxPoints) return const SizedBox.shrink();
                  // ใช้เวลาจาก series แรกที่มีข้อมูล
                  final firstValidSeries = series.firstWhere((s) => s.data.isNotEmpty);
                  try {
                    final firstTime = DateTime.parse(firstValidSeries.data.first['_time']?.toString() ?? DateTime.now().toIso8601String());
                    final lastTime = DateTime.parse(firstValidSeries.data.last['_time']?.toString() ?? DateTime.now().toIso8601String());
                    final diff = lastTime.difference(firstTime);
                    
                    final dt = DateTime.parse(firstValidSeries.data[idx]['_time'].toString()).toLocal();
                    
                    if (diff.inHours > 26) {
                      return Text(
                        '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(fontSize: 8, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      );
                    }
                    
                    return Text(
                      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(fontSize: 8, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
                reservedSize: 50,
                interval: ((maxY - minY) / 3).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, _) {
                  final mainSeries = series.where((s) => s.normalize == 1.0).toList();
                  if (mainSeries.isEmpty) return const SizedBox.shrink();
                  
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < mainSeries.length; i++) ...[
                        Text(
                          value.toInt().toString(),
                          style: GoogleFonts.inter(
                            fontSize: 8.5, 
                            color: mainSeries[i].color,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        if (i < mainSeries.length - 1) 
                          Text(' ', style: TextStyle(fontSize: 6, color: Colors.grey.withOpacity(0.5))),
                      ]
                    ],
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: maxX,
          minY: minY, maxY: maxY,
          lineBarsData: bars,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.black87,
              fitInsideVertically: fitTooltipInside,
              fitInsideHorizontally: fitTooltipInside,
              getTooltipItems: (touched) {
                if (touched.isEmpty) return [];
                
                // Get timestamp from the first valid series at the touched spotIndex
                final spotIndex = touched.first.spotIndex;
                final firstValidSeries = series.firstWhere((s) => s.data.isNotEmpty);
                String timeStr = '';
                try {
                  final dtValue = firstValidSeries.data[spotIndex]['_time'];
                  if (dtValue != null) {
                    final dt = DateTime.parse(dtValue.toString()).toLocal();
                    timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')} (UTC+7)';
                  }
                } catch (_) {}

                return touched.map((s) {
                  final match = series.firstWhere((ser) => ser.color == s.bar.color, orElse: () => series.first);
                  double displayVal;
                  if (independentScale && seriesRealRange.containsKey(s.bar.color)) {
                    final range = seriesRealRange[s.bar.color]!;
                    final realMin = range[0];
                    final realMax = range[1];
                    displayVal = realMin + ((s.y - 8) / 84) * (realMax - realMin);
                  } else {
                    displayVal = s.y * match.normalize;
                  }
                  
                  String label = match.label;
                  String unit = '';
                  
                  final lowerLabel = label.toLowerCase();
                  if (lowerLabel.contains('temp')) {
                    label = 'temp.';
                    unit = '°C';
                  } else if (lowerLabel.contains('humid') || lowerLabel == 'rh') {
                    label = 'Humid.';
                    unit = '%Rh';
                  } else if (lowerLabel.contains('co2')) {
                    label = 'CO2';
                    unit = 'ppm';
                  } else if (lowerLabel == 'n') {
                    label = 'N';
                    unit = 'mg/kg';
                  } else if (lowerLabel == 'p') {
                    label = 'P';
                    unit = 'mg/kg';
                  } else if (lowerLabel == 'k') {
                    label = 'K';
                    unit = 'mg/kg';
                  }

                  final bool isFirst = s == touched.first;
                  
                  return LineTooltipItem(
                    isFirst ? '$timeStr\n' : '',
                    GoogleFonts.inter(
                      color: Colors.white, 
                      fontWeight: FontWeight.w800, 
                      fontSize: 12
                    ),
                    children: [
                      TextSpan(
                        text: '${isFirst ? "\n" : ""}$label ${displayVal.toStringAsFixed(1)} $unit'.trim(),
                        style: GoogleFonts.inter(
                          color: s.bar.color ?? Colors.white, 
                          fontWeight: FontWeight.w700, 
                          fontSize: 11
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),

        ),
        duration: const Duration(milliseconds: 200),
      ),
    );
  }

  List<FlSpot> _toSpots(List<dynamic> data, {double normalize = 1.0}) {
    final List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final v = data[i]['_value'];
      double? val;
      if (v is num) val = v.toDouble();
      else if (v is String) val = double.tryParse(v);
      if (val != null) {
        spots.add(FlSpot(i.toDouble(), val / normalize));
      }
    }
    return spots;
  }

  LineChartBarData _bar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: spots.length > 2,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: spots.length <= 3,
        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 3, color: color, strokeWidth: 1.5, strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _noData() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart_rounded, color: Colors.grey.shade300, size: 28),
          const SizedBox(height: 6),
          Text('No data available', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
