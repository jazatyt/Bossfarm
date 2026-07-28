import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services/sensor_api_service.dart';
import 'widgets/multi_line_chart.dart';
import 'services/sensor_data_manager.dart';
import 'widgets/top_bar.dart';

const _kGreen700  = Color(0xFF2E7D32);
const _kGreen400  = Color(0xFF66BB6A);
const _kSurface   = Color(0xFFFFFFFF);
const _kTextDark  = Color(0xFF1A2E1A);
const _kTextMuted = Color(0xFF6B8068);

class AllDevicesPage extends StatefulWidget {
  const AllDevicesPage({Key? key}) : super(key: key);

  @override
  State<AllDevicesPage> createState() => _AllDevicesPageState();
}

class _AllDevicesPageState extends State<AllDevicesPage> {
  final SensorDataManager _manager = SensorDataManager();

  @override
  void initState() {
    super.initState();
    _manager.initialize();
    _manager.addListener(_onManagerUpdate);
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _retrySingle(String dId) => _manager.retrySingle(dId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: Column(
        children: [
          const TopBar(),
          // Sub-header for All Devices
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  'All API Devices',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1B5E20),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _manager.isFetchingDevices
                ? const Center(child: CircularProgressIndicator(color: _kGreen700))
                : RefreshIndicator(
                    onRefresh: _manager.refreshAll,
                    color: _kGreen700,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      itemCount: _manager.allDeviceIds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final dId = _manager.allDeviceIds[index];
                        return _buildRestApiFarmCard(
                          title: 'Device',
                          subtitle: dId,
                          apiService: _manager.apiServices[dId]!,
                          isFetching: _manager.fetchingMap[dId] ?? true,
                          isError: _manager.errorMap[dId] ?? false,
                          onRetry: () => _retrySingle(dId),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestApiFarmCard({
    required String title,
    required String subtitle,
    required SensorApiService apiService,
    required bool isFetching,
    required bool isError,
    required VoidCallback onRetry,
  }) {
    if (isFetching && apiService.count == 0) {
      return Container(
        height: 180,
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: CircularProgressIndicator(color: _kGreen700, strokeWidth: 2.5)),
      );
    }

    if (isError && apiService.count == 0) {
      return Container(
        height: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.wifi_off_rounded, color: Colors.red.shade400, size: 20),
            ),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _kTextDark)),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.refresh_rounded, color: _kGreen700, size: 16),
              ),
            ),
          ],
        ),
      );
    }

    final snap      = apiService.latest;
    final tempData  = apiService.tempHistory;
    final humidData = apiService.humidHistory;
    final temp      = snap?.temperature.toStringAsFixed(1) ?? '--';
    final humid     = snap?.humidity.toStringAsFixed(1) ?? '--';
    final lightOn   = snap?.lightOn ?? false;

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _kGreen700.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _kGreen700.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.terrain_rounded, color: _kGreen700, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _kTextDark, letterSpacing: -0.4)),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: isError ? Colors.red.shade50 : const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: isError ? Colors.red.shade400 : _kGreen400)),
                      const SizedBox(width: 4),
                      Text(isError ? 'OFFLINE' : 'LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: isError ? Colors.red.shade400 : _kGreen700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                _liveValue(Icons.thermostat_rounded, '$temp °C', 'Temperature', const Color(0xFFFF7043)),
                const SizedBox(width: 6),
                _liveValue(Icons.water_drop_rounded, '$humid %', 'Humidity', const Color(0xFF29B6F6)),
                const SizedBox(width: 6),
                _liveValue(lightOn ? Icons.wb_sunny_rounded : Icons.wb_sunny_outlined, lightOn ? 'ON' : 'OFF', 'Light', lightOn ? const Color(0xFFFFCA28) : Colors.grey.shade400),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
            child: SizedBox(
              height: 90, 
              child: MultiLineChart(
                series: [
                  ChartSeries(data: tempData, color: const Color(0xFFFF7043), label: 'Temp'),
                  ChartSeries(data: humidData, color: const Color(0xFF29B6F6), label: 'Humid'),
                ],
              )
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                _legendDot(const Color(0xFFFF7043), 'Temp'),
                const SizedBox(width: 10),
                _legendDot(const Color(0xFF29B6F6), 'Humid'),
                const Spacer(),
                Text(isError ? 'Retrying...' : '${apiService.count} pts', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveValue(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _kTextDark), overflow: TextOverflow.ellipsis),
            Text(label, style: GoogleFonts.inter(fontSize: 9, color: _kTextMuted)),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 9, color: _kTextMuted, fontWeight: FontWeight.w600)),
    ],
  );
}
