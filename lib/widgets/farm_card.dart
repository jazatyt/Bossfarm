import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'multi_line_chart.dart';

const _kGreen700  = Color(0xFF2E7D32);
const _kGreen400  = Color(0xFF66BB6A);
const _kTextDark  = Color(0xFF1A2E1A);
const _kTextMuted = Color(0xFF6B8068);

/// FarmCard ขนาดเต็มสำหรับ InfluxDB data (Farm 2, 3 ...)
/// ใช้ layout แนวตั้ง เหมาะสำหรับแสดงรายการด้านล่างหน้า Dashboard
class FarmCard extends StatelessWidget {
  final String title;
  final List<dynamic> tempData;
  final List<dynamic> humidData;
  final List<dynamic> sensors;

  const FarmCard({
    Key? key,
    required this.title,
    required this.tempData,
    required this.humidData,
    required this.sensors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasData = sensors.isNotEmpty;

    // ค่าล่าสุด
    String lastTemp  = '--';
    String lastHumid = '--';
    if (tempData.isNotEmpty) {
      final v = tempData.last['_value'];
      if (v is num) lastTemp = v.toStringAsFixed(1);
    }
    if (humidData.isNotEmpty) {
      final v = humidData.last['_value'];
      if (v is num) lastHumid = v.toStringAsFixed(1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kGreen700.withOpacity(0.05),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _kGreen700.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.terrain_rounded, color: _kGreen700, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w800,
                            color: _kTextDark, letterSpacing: -0.3,
                          )),
                      Text(hasData ? '${sensors.length} units · InfluxDB' : 'No data available',
                          style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted)),
                    ],
                  ),
                ),

                // Temp / Humid badges
                if (lastTemp != '--') ...[
                  _valueBadge('$lastTemp°', const Color(0xFFFF7043)),
                  const SizedBox(width: 6),
                ],
                if (lastHumid != '--')
                  _valueBadge('$lastHumid%', const Color(0xFF29B6F6)),

                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasData ? _kGreen400 : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),

          // ── Chart ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SizedBox(
              height: 80,
              child: MultiLineChart(
                series: [
                  ChartSeries(data: tempData, color: const Color(0xFFFF7043), label: 'Temp'),
                  ChartSeries(data: humidData, color: const Color(0xFF29B6F6), label: 'Humid'),
                ],
              ),
            ),
          ),

          // ── Legend + Sensor rows ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _legendDot(const Color(0xFFFF7043), 'Temp'),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFF29B6F6), 'Humid'),
              ],
            ),
          ),

          if (sensors.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: Color(0xFFF0F4F0)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: _buildSensorRows(),
            ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _valueBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: color,
      )),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted, fontWeight: FontWeight.w600)),
    ],
  );

  Widget _buildSensorRows() {
    return Column(
      children: [
        // Header
        Row(
          children: [
            Expanded(flex: 2, child: _cell('Unit', isHeader: true)),
            Expanded(child: _cell('Temp', isHeader: true, center: true)),
            Expanded(child: _cell('Humid', isHeader: true, center: true)),
            Expanded(child: _cell('Light', isHeader: true, right: true)),
          ],
        ),
        const SizedBox(height: 6),
        ...sensors.asMap().entries.map((e) {
          final idx    = e.key;
          final sensor = e.value;

          String t = '--', h = '--';
          bool lightOn = false;

          final tTrend = sensor['temp_trend']  as List<dynamic>;
          final hTrend = sensor['humid_trend'] as List<dynamic>;
          final lv     = sensor['last_light'];

          if (tTrend.isNotEmpty) {
            final v = tTrend.last['_value'];
            if (v is num) t = v.toStringAsFixed(1);
          }
          if (hTrend.isNotEmpty) {
            final v = hTrend.last['_value'];
            if (v is num) h = v.toStringAsFixed(1);
          }
          if (lv is num)    lightOn = lv > 0;
          else if (lv is String) lightOn = lv.toLowerCase() == 'on' || lv == '1';

          return Container(
            margin: const EdgeInsets.only(top: 5),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBF8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('S-${idx + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen700,
                      )),
                ),
                Expanded(
                  child: Text('$t°',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _kTextDark,
                      ),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Text('$h%',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _kTextDark,
                      ),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: lightOn ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lightOn ? 'ON' : 'OFF',
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: lightOn ? _kGreen700 : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _cell(String text, {bool isHeader = false, bool center = false, bool right = false}) {
    return Text(
      text,
      textAlign: right ? TextAlign.right : (center ? TextAlign.center : TextAlign.left),
      style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: isHeader ? Colors.grey.shade400 : _kTextDark,
      ),
    );
  }
}
