import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'notifications_page.dart';

import 'services/sensor_api_service.dart';
import 'widgets/farm_card.dart';
import 'widgets/multi_line_chart.dart';
import 'sensor_alert.dart';
import 'services/alarm_service.dart';
import 'widgets/alarm_banner_widget.dart';
import 'theme_manager.dart';
import 'services/auth_service.dart';
import 'login_page.dart';
import 'history_view_page.dart';
import 'farm_layout_builder_page.dart';
import 'services/sensor_data_manager.dart';
import 'services/layout_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'user_management_page.dart';
import 'widgets/top_bar.dart';

// ── Theme constants (Adaptive) ──────────────────────────────────────────────
const _kGreen900 = Color(0xFF1B5E20);
const _kGreen700 = Color(0xFF2E7D32);
const _kGreen400 = Color(0xFF66BB6A);

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Color get _kBgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _kSurface => Theme.of(context).cardColor;
  Color get _kTextDark => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFE0E0E0)
      : const Color(0xFF1A2E1A);
  Color get _kTextMuted => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA0A0A0)
      : const Color(0xFF6B8068);

  final SensorDataManager _manager = SensorDataManager();

  final AlarmService _alarmService = AlarmService();
  final LayoutApiService _layoutApi = LayoutApiService();
  final bool _isAdmin = AuthService().currentRole == 'admin';
  String? _logoUrl;
  Map<String, String> _deviceDisplayNames = {};


  @override
  void initState() {
    super.initState();
    _manager.initialize(); // Ensure data manager starts fetching data
    _alarmService.fetchAll();
    
    // Alarms keep their own slow refresh
    Timer.periodic(const Duration(seconds: 30), (_) async {
      await _alarmService.fetchAll();
      if (mounted) setState(() {});
    });

    _loadDisplayNames();
    _manager.addListener(_onManagerUpdate);
  }

  Future<void> _loadDisplayNames() async {
    try {
      final layout = await _layoutApi.fetchLayout();
      if (layout.containsKey('deviceDisplayNames')) {
        final Map<String, dynamic> rawNames =
            Map<String, dynamic>.from(layout['deviceDisplayNames']);
        if (mounted) {
          setState(() {
            _deviceDisplayNames =
                rawNames.map((k, v) => MapEntry(k, v.toString()));
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading display names in dashboard: $e');
    }
  }

  void _onManagerUpdate() {
    // Check if we need to reload display names (optional, if they change)
    if (_deviceDisplayNames.isEmpty) _loadDisplayNames();
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
      backgroundColor: _kBgColor,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: TopBar()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                _buildSectionHeader('Dashboard Overview'),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _manager,
                  builder: (context, _) => _buildSensorSummarySection(),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Environment Nodes', showAll: true, filterType: 'environment'),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _manager,
                  builder: (context, _) => _buildFarmsRow(),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _manager,
                  builder: (context, _) => _buildSoilChartsRow(),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }



  Widget _buildSectionHeader(String title, {bool showAll = false, String filterType = ''}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _kTextDark)),
      if (showAll)
        GestureDetector(
          onTap: () async {
            await context.push('/farms', extra: filterType);
            _loadDisplayNames();
          },
          child: Row(
            children: [
              Text('View All', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kGreen700)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _kGreen700),
            ],
          ),
        ),
    ],
  );
}

  Widget _buildTimeRangeSelector() {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final hours = _manager.currentHistoryHours;
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kGreen700.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              _timeButton('1D', 24, hours == 24),
              _timeButton('7D', 168, hours == 168),
              _timeButton('30D', 720, hours == 720),
              const Spacer(),
              if (_manager.isFetchingHistory)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen700)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _timeButton(String label, int hours, bool isActive) {
    return GestureDetector(
      onTap: () => _manager.fetchGlobalHistory(hours: hours),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _kGreen700 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isActive ? Colors.white : _kTextMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSensorSummarySection() {
    return Row(
      children: [
        _summaryCard('Soil', _manager.getOnlineCount(_manager.soilIds), _manager.soilIds.length, const Color(0xFF8D6E63), PhosphorIcons.plant()),
        const SizedBox(width: 10),
        _summaryCard('Environment', _manager.getOnlineCount(_manager.elementIds), _manager.elementIds.length, const Color(0xFF29B6F6), PhosphorIcons.cloudSun()),
        const SizedBox(width: 10),
        _summaryCard('Mineral', _manager.getOnlineCount(_manager.mineralIds), _manager.mineralIds.length, const Color(0xFF5C6BC0), PhosphorIcons.flask()),



      ],
    );
  }

  Widget _summaryCard(String title, int online, int total, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4))]),
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text('$online/$total', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _kTextDark)),
            Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _kTextMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmsRow() {
    if (_manager.isFetchingDevices && _manager.elementIds.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: CircularProgressIndicator(color: _kGreen700, strokeWidth: 2.5)),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 768;
    final List<Widget> cards = [];

    for (var dId in _manager.elementIds.take(3)) {
      final card = _buildRestApiFarmCard(
        title: 'Environment Node',
        subtitle: dId,
        ip: _manager.deviceIps[dId] ?? '',
        apiService: _manager.apiServices[dId]!,
        isFetching: _manager.fetchingMap[dId] ?? true,
        isError: _manager.errorMap[dId] ?? false,
        onRetry: () => _retrySingle(dId),
      );
      cards.add(isMobile ? card : Expanded(child: card));
    }

    if (cards.isEmpty) {
      return _buildPlaceholderCard('Environment Node', 'No sensors connected', Icons.thermostat_rounded);
    }

    if (isMobile) {
      return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cards.fold<List<Widget>>([], (list, card) {
          if (list.isNotEmpty) list.add(const SizedBox(width: 10));
          list.add(card);
          return list;
        }),
      ),
    );
  }

  Widget _buildSoilChartsRow() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    final soilId = _manager.soilIds.isNotEmpty ? _manager.soilIds.first : null;
    final mineralId = _manager.mineralIds.isNotEmpty ? _manager.mineralIds.first : null;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (soilId != null) ...[
            _buildSectionHeader('Soil Sensors', showAll: true, filterType: 'soil'),
            const SizedBox(height: 12),
            _buildCombinedSoilCard(soilId, _manager.apiServices[soilId]!, _manager.errorMap[soilId] ?? false),
            const SizedBox(height: 20),
          ] else ...[
            _buildSectionHeader('Soil Sensors', showAll: true, filterType: 'soil'),
            const SizedBox(height: 12),
            _buildPlaceholderCard('Soil Sensors', 'No soil nodes found', Icons.grass_rounded),
            const SizedBox(height: 20),
          ],
          if (mineralId != null) ...[
            _buildSectionHeader('Mineral Sensor', showAll: true, filterType: 'mineral'),
            const SizedBox(height: 12),
            _buildMineralCard(mineralId, _manager.apiServices[mineralId]!, _manager.errorMap[mineralId] ?? false),
          ] else ...[
            _buildSectionHeader('Mineral Sensor', showAll: true, filterType: 'mineral'),
            const SizedBox(height: 12),
            _buildPlaceholderCard('Mineral Sensor', 'No mineral nodes found', Icons.science_rounded),
          ],
        ],
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildSectionHeader('Soil Sensors', showAll: true, filterType: 'soil'),
                    const SizedBox(height: 12),
                    Expanded(
                      child: soilId != null 
                        ? _buildCombinedSoilCard(soilId, _manager.apiServices[soilId]!, _manager.errorMap[soilId] ?? false)
                        : _buildPlaceholderCard('Soil Sensors', 'No soil nodes connected', Icons.grass_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildSectionHeader('Mineral Sensor', showAll: true, filterType: 'mineral'),
                    const SizedBox(height: 12),
                    Expanded(
                      child: mineralId != null 
                        ? _buildMineralCard(mineralId, _manager.apiServices[mineralId]!, _manager.errorMap[mineralId] ?? false)
                        : _buildPlaceholderCard('Mineral Sensor', 'No mineral nodes connected', Icons.science_rounded, showChart: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedSoilCard(String dId, SensorApiService apiService, bool isError) {
    final snap = apiService.latest;
    final tempLatest = snap?.temperature.toStringAsFixed(1) ?? '--';
    final moistureLatest = snap?.soilMoisture.toStringAsFixed(1) ?? '--';
    final ecLatest = snap?.ec.toStringAsFixed(2) ?? '--';
    final phLatest = snap?.ph.toStringAsFixed(1) ?? '--';
    final n = snap?.nitrogen.round() ?? 0;
    final p = snap?.phosphorus.round() ?? 0;
    final k = snap?.potassium.round() ?? 0;
    final tempColor = const Color(0xFFFF7043);
    final moistureColor = const Color(0xFF29B6F6);
    final ecColor = const Color(0xFF8D6E63);
    final phColor = const Color(0xFF66BB6A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: _kGreen700.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(PhosphorIcons.plant(), color: _kGreen700, size: 14)),




              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_deviceDisplayNames[dId] ?? 'Soil Sensors', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _kTextDark)),
                  Text(dId, style: GoogleFonts.inter(fontSize: 9, color: _kTextMuted)),
                ],
              ),
              const Spacer(),
              _statusChip(isError),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _liveValue(PhosphorIcons.drop(), '$moistureLatest%', 'Moisture', moistureColor),
              const SizedBox(width: 6),
              _liveValue(PhosphorIcons.thermometer(), '$tempLatest°C', 'Temp', tempColor),
              const SizedBox(width: 6),
              _liveValue(Icons.science_outlined, phLatest, 'pH', phColor),
              const SizedBox(width: 6),
              _liveValue(PhosphorIcons.lightning(), ecLatest, 'EC', ecColor),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniNutrientValue(Icons.filter_vintage_rounded, '$n', 'mg/kg', 'Nitrogen', const Color(0xFF9CCC65)),
              const SizedBox(width: 6),
              _miniNutrientValue(Icons.filter_vintage_rounded, '$p', 'mg/kg', 'Phosphorus', const Color(0xFFFFB74D)),
              const SizedBox(width: 6),
              _miniNutrientValue(Icons.filter_vintage_rounded, '$k', 'mg/kg', 'Potassium', const Color(0xFFBA68C8)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: MultiLineChart(series: [
              ChartSeries(data: apiService.tempHistory, color: tempColor, label: 'Temp'),
              ChartSeries(data: apiService.moistureHistory, color: moistureColor, label: 'Moisture'),
              ChartSeries(data: apiService.ecHistory, color: ecColor, label: 'EC', normalize: 0.1),
              ChartSeries(data: apiService.phHistory, color: phColor, label: 'pH'),
              ChartSeries(data: apiService.nitrogenHistory, color: const Color(0xFF9CCC65), label: 'N', normalize: 10.0),
              ChartSeries(data: apiService.phosphorusHistory, color: const Color(0xFFFFB74D), label: 'P', normalize: 10.0),
              ChartSeries(data: apiService.potassiumHistory, color: const Color(0xFFBA68C8), label: 'K', normalize: 10.0),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMineralCard(String dId, SensorApiService apiService, bool isError) {
    final snap = apiService.latest;
    final ecLatest = snap?.ec.toStringAsFixed(2) ?? '--';
    final tempLatest = snap?.temperature.toStringAsFixed(1) ?? '--';
    final phLatest = snap?.ph.toStringAsFixed(1) ?? '--';
    final ecColor = const Color(0xFF8D6E63);
    final tempColor = const Color(0xFFFF7043);
    final phColor = const Color(0xFF66BB6A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: _kGreen700.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(PhosphorIcons.flask(), color: _kGreen700, size: 14)),




              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_deviceDisplayNames[dId] ?? 'Mineral Sensor', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _kTextDark)),
                  Text(dId, style: GoogleFonts.inter(fontSize: 9, color: _kTextMuted)),
                ],
              ),
              const Spacer(),
              _statusChip(isError),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _liveValue(PhosphorIcons.lightning(), ecLatest, 'EC', ecColor),
              const SizedBox(width: 6),
              _liveValue(Icons.science_outlined, phLatest, 'pH', phColor),
              const SizedBox(width: 6),
              _liveValue(PhosphorIcons.thermometer(), '$tempLatest°C', 'Temp', tempColor),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: MultiLineChart(expand: true, series: [ChartSeries(data: apiService.ecHistory, color: ecColor, label: 'EC', normalize: 0.1), ChartSeries(data: apiService.phHistory, color: phColor, label: 'pH'), ChartSeries(data: apiService.tempHistory, color: tempColor, label: 'Temp')])),
        ],
      ),
    );
  }

  Widget _npkLegend(Color color, String label, int value) {
    return Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text('$value $label', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _kTextDark))]);
  }

  Widget _miniNutrientValue(IconData icon, String value, String unit, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label,
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: _kTextMuted),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _kTextDark)),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit, style: GoogleFonts.inter(fontSize: 9, color: _kTextMuted, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _combinedValue(String label, String value, String unit, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Container(width: 8, height: 8, margin: const EdgeInsets.only(bottom: 4, right: 6), decoration: BoxDecoration(shape: BoxShape.circle, color: color)), Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: _kTextDark)), const SizedBox(width: 3), Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(unit, style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted, fontWeight: FontWeight.w600)))]);
  }

  Widget _statusChip(bool isError) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isError ? Colors.red.shade50 : const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: Text(isError ? 'OFFLINE' : 'LIVE', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: isError ? Colors.red : _kGreen700)));
  }

  Widget _buildPlaceholderCard(String title, String subtitle, IconData icon, {bool showChart = true}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: _kGreen700.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _kGreen700, size: 16)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _kTextDark)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 9, color: _kTextMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (showChart)
            SizedBox(
              height: 80,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors_off_rounded, color: Colors.grey.shade300, size: 24),
                    const SizedBox(height: 4),
                    Text('No data available', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRestApiFarmCard({required String title, required String subtitle, required String ip, required SensorApiService apiService, required bool isFetching, required bool isError, required VoidCallback onRetry}) {
    if (isFetching && apiService.count == 0) return Container(height: 180, decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(24)), child: const Center(child: CircularProgressIndicator(color: _kGreen700, strokeWidth: 2.5)));
    return _buildElementApiCard(title, subtitle, ip, apiService, isError);
  }

  Widget _buildElementApiCard(String title, String subtitle, String ip, SensorApiService apiService, bool isError) {
    final snap = apiService.latest;
    final lastUpdate = snap?.time;
    final isOffline = lastUpdate != null && DateTime.now().difference(lastUpdate).inSeconds > 60;
    final effectiveError = isError || isOffline;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: effectiveError 
            ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900.withOpacity(0.5) : Colors.grey.shade50) 
            : _kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: effectiveError ? Colors.black.withOpacity(0.04) : _kGreen700.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6)
          )
        ]
      ),
      child: Opacity(
        opacity: effectiveError ? 0.35 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(title, subtitle, ip, effectiveError, Icons.terrain_rounded),
            const SizedBox(height: 12),
            Row(
              children: [
                _liveValue(PhosphorIcons.thermometer(), '${snap?.temperature.toStringAsFixed(1) ?? '--'} °C', 'Temperature', const Color(0xFFFF7043)),
                const SizedBox(width: 8),
                _liveValue(PhosphorIcons.drop(), '${snap?.humidity.toStringAsFixed(1) ?? '--'} %', 'Humidity', const Color(0xFF29B6F6)),
                const SizedBox(width: 8),
                _liveValue(PhosphorIcons.cloud(), snap?.eco2 != null ? '${snap!.eco2} ppm' : '--', 'CO2', const Color(0xFF9575CD))




              ]
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: MultiLineChart(
                fixedMinY: 0,
                fixedMaxY: 100,
                series: [
                  ChartSeries(data: apiService.tempHistory, color: const Color(0xFFFF7043), label: 'Temp'),
                  ChartSeries(data: apiService.humidHistory, color: const Color(0xFF29B6F6), label: 'Humid'),
                  ChartSeries(data: apiService.eco2History, color: const Color(0xFF9575CD), label: 'CO2', normalize: 25.0)
                ]
              )
            ),
            _buildCardFooter(effectiveError, apiService.count)
          ]
        ),
      ),
    );
  }

  Widget _buildCardHeader(String title, String subtitle, String ip, bool isError, IconData icon) {
    final displayName = _deviceDisplayNames[subtitle] ?? title;
    return Row(children: [Container(width: 32, height: 32, decoration: BoxDecoration(color: _kGreen700.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _kGreen700, size: 16)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(displayName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _kTextDark)), Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted)), if (ip.isNotEmpty) Text(ip, style: GoogleFonts.inter(fontSize: 9, color: _kGreen700.withOpacity(0.7)))])), _statusChip(isError)]);
  }


  Widget _buildCardFooter(bool isError, int count) {
    return Padding(padding: const EdgeInsets.only(top: 8), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(isError ? 'OFFLINE' : '$count pts', style: GoogleFonts.inter(fontSize: 9, color: _kTextMuted))]));
  }

  Widget _liveValue(IconData icon, String value, String label, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(icon, color: color, size: 14), const SizedBox(height: 4), Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _kTextDark)), Text(label, style: GoogleFonts.inter(fontSize: 9, color: _kTextMuted))])));
  }
}