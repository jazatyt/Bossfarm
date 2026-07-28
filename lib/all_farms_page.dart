import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services/sensor_api_service.dart';
import 'widgets/multi_line_chart.dart';
import 'services/layout_api_service.dart';
import 'services/sensor_data_manager.dart';
import 'widgets/top_bar.dart';

const _kGreen700 = Color(0xFF2E7D32);
const _kGreen400 = Color(0xFF66BB6A);

class AllFarmsPage extends StatefulWidget {
  final String filterType;
  const AllFarmsPage({Key? key, this.filterType = ''}) : super(key: key);

  @override
  State<AllFarmsPage> createState() => _AllFarmsPageState();
}

enum SensorType { element, soil, mineral }

class _AllFarmsPageState extends State<AllFarmsPage> {
  Color get _kBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _kSurface => Theme.of(context).cardColor;
  Color get _kTextDark => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFE0E0E0)
      : const Color(0xFF1A2E1A);
  Color get _kTextMuted => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA0A0A0)
      : const Color(0xFF6B8068);

  final LayoutApiService _layoutApi = LayoutApiService();
  Map<String, String> _deviceDisplayNames = {};
  final SensorDataManager _manager = SensorDataManager();
  String _selectedFilter = 'All';
  bool get isMobile => MediaQuery.of(context).size.width < 1000;

  @override
  void initState() {
    super.initState();
    if (widget.filterType == 'environment') _selectedFilter = 'Environmental';
    else if (widget.filterType == 'soil') _selectedFilter = 'Soil';
    else if (widget.filterType == 'mineral') _selectedFilter = 'Mineral';
    else _selectedFilter = 'All';

    _loadDisplayNames();
    _manager.initialize();
    _manager.addListener(_onManagerUpdate);
  }

  void _onManagerUpdate() {}

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    super.dispose();
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
      debugPrint('Error loading names: $e');
    }
  }

  void _onCategoryChanged(String dId, SensorType newType) {
    setState(() {
      _manager.elementIds.remove(dId);
      _manager.soilIds.remove(dId);
      _manager.mineralIds.remove(dId);
      if (newType == SensorType.element) _manager.elementIds.add(dId);
      else if (newType == SensorType.soil) _manager.soilIds.add(dId);
      else _manager.mineralIds.add(dId);
    });
  }

  Future<void> _renameDevice(String dId, String currentTitle) async {
    final TextEditingController nameCtrl =
        TextEditingController(text: _deviceDisplayNames[dId] ?? currentTitle);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: Text('Edit Device Name',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: _kTextDark)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter new name...',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      setState(() {
        _deviceDisplayNames[dId] = newName.trim();
      });
      try {
        final layout = await _layoutApi.fetchLayout();
        layout['deviceDisplayNames'] = _deviceDisplayNames;
        await _layoutApi.saveLayout(layout);
      } catch (e) {
        debugPrint('Error saving name: $e');
      }
    }
  }



  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_manager.isFetchingDevices) {
      body = const Center(
          child: CircularProgressIndicator(color: _kGreen700));
    } else {
      body = RefreshIndicator(
        onRefresh: _manager.refreshAll,
        color: _kGreen700,
        child: AnimatedBuilder(
          animation: _manager,
          builder: (__, _) {
            final elementIds = _manager.elementIds;
            final soilIds = _manager.soilIds;
            final mineralIds = _manager.mineralIds;

            bool hasData = false;
            if (_selectedFilter == 'All' ||
                _selectedFilter == 'Environmental') {
              if (elementIds.isNotEmpty) hasData = true;
            }
            if (_selectedFilter == 'All' || _selectedFilter == 'Soil') {
              if (soilIds.isNotEmpty) hasData = true;
            }
            if (_selectedFilter == 'All' ||
                _selectedFilter == 'Mineral') {
              if (mineralIds.isNotEmpty) hasData = true;
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [

                if (!hasData && !_manager.isFetchingDevices)
                  _buildEmptyState('No sensor data found in this category')
                else ...[
                  if (_selectedFilter == 'All' ||
                      _selectedFilter == 'Environmental') ...[
                    if (elementIds.isNotEmpty) ...[
                      _buildSectionHeader(
                          'Environmental Nodes', PhosphorIcons.cloudSun()),



                      _buildSensorGrid(elementIds, SensorType.element),
                    ],
                  ],
                  if (_selectedFilter == 'All' ||
                      _selectedFilter == 'Soil') ...[
                    if (soilIds.isNotEmpty) ...[
                      _buildSectionHeader(
                          'Soil Sensors', PhosphorIcons.plant()),



                      _buildSensorGrid(soilIds, SensorType.soil),
                    ],
                  ],
                  if (_selectedFilter == 'All' ||
                      _selectedFilter == 'Mineral') ...[
                    if (mineralIds.isNotEmpty) ...[
                      _buildSectionHeader(
                          'Mineral Sensors', PhosphorIcons.flask()),



                      _buildSensorGrid(mineralIds, SensorType.mineral),
                    ],
                  ],
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      );
    }



    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const TopBar(),
          // Sub-header for Page Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _kSurface,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: _kGreen700, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'Farms Overview',
                  style: GoogleFonts.inter(
                      color: _kTextDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
                const Spacer(),
                if (isMobile) _buildFilterDropdown(),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: isMobile
                ? body
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSidebar(),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: _openMobileSidebar,
              backgroundColor: _kGreen700,
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            )
          : null,
    );
  }

  void _openMobileSidebar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(child: _buildSidebar()),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Category Filter ───────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Category',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _kTextMuted)),
            ),
            const SizedBox(height: 12),
            _buildSidebarFilterItem('All', PhosphorIcons.squaresFour()),
            _buildSidebarFilterItem('Environmental', PhosphorIcons.cloudSun()),
            _buildSidebarFilterItem('Soil', PhosphorIcons.plant()),
            _buildSidebarFilterItem('Mineral', PhosphorIcons.flask()),




            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),

            // ── Inline Calendar ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Period',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _kTextMuted)),
            ),
            const SizedBox(height: 12),
            _SidebarCalendar(
              manager: _manager,
              accentColor: _kGreen700,
              surfaceColor: _kSurface,
              textDark: _kTextDark,
              textMuted: _kTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarFilterItem(String value, IconData icon) {
    final bool isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _kGreen700.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? _kGreen700 : Colors.grey.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: isSelected ? _kGreen700 : _kTextMuted, size: 18),
              const SizedBox(width: 12),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? _kGreen700 : _kTextDark)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _fmtFull(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}';

  // ─────────────────────────────────────────────────────────────

  Widget _buildFilterDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen700.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          icon: const Icon(Icons.filter_list_rounded,
              color: _kGreen700, size: 18),
          elevation: 16,
          style: GoogleFonts.inter(
              color: _kGreen700,
              fontWeight: FontWeight.bold,
              fontSize: 12),
          onChanged: (String? newValue) {
            if (newValue != null)
              setState(() => _selectedFilter = newValue);
          },
          items: <String>['All', 'Environmental', 'Soil', 'Mineral']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
                value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.sensors_off_rounded,
                color: _kTextMuted.withOpacity(0.3), size: 40),
            const SizedBox(height: 12),
            Text(message,
                style:
                    GoogleFonts.inter(color: _kTextMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _kGreen700.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: _kGreen700, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                  letterSpacing: -0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorGrid(List<String> ids, SensorType type) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          int crossAxisCount = 1;
          double extent = 300;

          if (width > 1200) {
            crossAxisCount = 4;
          } else if (width > 800) {
            crossAxisCount = 2;
          } else {
            crossAxisCount = 1;
            extent = 340;
          }

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: extent,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final dId = ids[index];
                final ip = _manager.deviceIps[dId] ?? '';
                final apiService = _manager.apiServices[dId]!;
                final isFetching =
                    _manager.fetchingMap[dId] ?? true;
                final isError = _manager.errorMap[dId] ?? false;

                if (type == SensorType.soil) {
                  return _buildSoilFarmCard(
                    title: 'Soil Unit ${index + 1}',
                    subtitle: dId,
                    ip: ip,
                    apiService: apiService,
                    isFetching: isFetching,
                    isError: isError,
                    onRetry: () => _manager.retrySingle(dId),
                    onTypeChange: (t) =>
                        _onCategoryChanged(dId, t),
                    onRename: () =>
                        _renameDevice(dId, 'Soil Unit ${index + 1}'),
                    onDelete: () => _manager.removeDevice(dId),
                  );
                } else if (type == SensorType.mineral) {
                  return _buildMineralFarmCard(
                    title: 'NPK Unit ${index + 1}',
                    subtitle: dId,
                    ip: ip,
                    apiService: apiService,
                    isFetching: isFetching,
                    isError: isError,
                    onRetry: () => _manager.retrySingle(dId),
                    onTypeChange: (t) =>
                        _onCategoryChanged(dId, t),
                    onRename: () =>
                        _renameDevice(dId, 'NPK Unit ${index + 1}'),
                    onDelete: () => _manager.removeDevice(dId),
                  );
                }

                return _buildRestApiFarmCard(
                  title: 'Farm Unit ${index + 1}',
                  subtitle: dId,
                  ip: ip,
                  apiService: apiService,
                  isFetching: isFetching,
                  isError: isError,
                  onRetry: () => _manager.retrySingle(dId),
                  onTypeChange: (t) => _onCategoryChanged(dId, t),
                  onRename: () =>
                      _renameDevice(dId, 'Farm Unit ${index + 1}'),
                  onDelete: () => _manager.removeDevice(dId),
                );
              },
              childCount: ids.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRestApiFarmCard({
    required String title,
    required String subtitle,
    required String ip,
    required SensorApiService apiService,
    required bool isFetching,
    required bool isError,
    required VoidCallback onRetry,
    required Function(SensorType) onTypeChange,
    required VoidCallback onRename,
    required VoidCallback onDelete,
  }) {
    if (isFetching && apiService.count == 0) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 180,
        decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(24)),
        child: const Center(
            child: CircularProgressIndicator(
                color: _kGreen700, strokeWidth: 2.5)),
      );
    }

    // Removed old error card logic to always show graph with opacity if offline

    final snap = apiService.latest;
    final lastTime = snap?.time;
    final isOffline = lastTime != null && DateTime.now().difference(lastTime).inSeconds > 60;
    final effectiveError = isError || isOffline;

    final temp = snap?.temperature.toStringAsFixed(1) ?? '--';
    final humid = snap?.humidity.toStringAsFixed(1) ?? '--';
    final eco2 = snap?.eco2 != null ? '${snap!.eco2} ppm' : '--';
    final lightOn = snap?.lightOn ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: effectiveError 
            ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900.withOpacity(0.5) : Colors.grey.shade50) 
            : _kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: effectiveError ? Colors.black.withOpacity(0.04) : _kGreen700.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: Opacity(
        opacity: effectiveError ? 0.35 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
                _deviceDisplayNames[subtitle] ?? title,
                subtitle,
                ip,
                effectiveError,
                PhosphorIcons.cloudSun(),



                onTypeChange,
                onRename,
                onDelete),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                Expanded(child: _liveValue(PhosphorIcons.thermometer(), '$temp °C',
                    'Temperature', const Color(0xFFFF7043))),
                const SizedBox(width: 6),
                Expanded(child: _liveValue(PhosphorIcons.drop(), '$humid %',
                    'Humidity', const Color(0xFF29B6F6))),
                const SizedBox(width: 6),
                Expanded(child: _liveValue(
                    lightOn
                        ? PhosphorIcons.sun()
                        : PhosphorIcons.sunDim(),
                    lightOn ? 'ON' : 'OFF',
                    'Light',
                    lightOn
                        ? const Color(0xFFFFCA28)
                        : Colors.grey.shade400)),
                const SizedBox(width: 6),
                Expanded(child: _liveValue(PhosphorIcons.cloud(), '$eco2', 'CO2',
                    const Color(0xFF9575CD))),




              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: RepaintBoundary(
                child: MultiLineChart(
                  height: 100,
                  fixedMinY: 0,
                  fixedMaxY: 100,
                  series: [
                    ChartSeries(
                        data: apiService.tempHistory,
                        color: const Color(0xFFFF7043),
                        label: 'Temp'),
                    ChartSeries(
                        data: apiService.humidHistory,
                        color: const Color(0xFF29B6F6),
                        label: 'Humid'),
                    ChartSeries(
                        data: apiService.eco2History,
                        color: const Color(0xFF9575CD),
                        label: 'CO2',
                        normalize: 25.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _legendDot(const Color(0xFFFF7043), 'Temp (°C)'),
                const SizedBox(width: 8),
                _legendDot(const Color(0xFF29B6F6), '(%) RH'),

                const SizedBox(width: 8),
                _legendDot(const Color(0xFF9575CD), 'CO2 (ppm)'),
                const Spacer(),
                Text(
                    effectiveError
                        ? 'OFFLINE'
                        : '${apiService.count} pts',
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _liveValue(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark),
              overflow: TextOverflow.ellipsis),
          Text(label,
              style:
                  GoogleFonts.inter(fontSize: 9, color: _kTextMuted)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 9,
                  color: _kTextMuted,
                  fontWeight: FontWeight.w600)),
        ],
      );

  Widget _buildSoilFarmCard({
    required String title,
    required String subtitle,
    required String ip,
    required SensorApiService apiService,
    required bool isFetching,
    required bool isError,
    required VoidCallback onRetry,
    required Function(SensorType) onTypeChange,
    required VoidCallback onRename,
    required VoidCallback onDelete,
  }) {
    if (isFetching && apiService.count == 0) {
      return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(24)),
          child: const Center(
              child: CircularProgressIndicator(
                  color: _kGreen700, strokeWidth: 2.5)));
    }

    final snap = apiService.latest;
    final lastTime = snap?.time;
    final isOffline = lastTime != null && DateTime.now().difference(lastTime).inSeconds > 60;
    final effectiveError = isError || isOffline;

    final temp = snap?.temperature.toStringAsFixed(1) ?? '--';
    final moisture = snap?.soilMoisture.toStringAsFixed(1) ?? '--';
    final ec = snap?.ec.toStringAsFixed(2) ?? '--';
    final ph = snap?.ph.toStringAsFixed(1) ?? '--';
    final n = snap?.nitrogen.toStringAsFixed(0) ?? '--';
    final p = snap?.phosphorus.toStringAsFixed(0) ?? '--';
    final k = snap?.potassium.toStringAsFixed(0) ?? '--';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: effectiveError 
            ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900.withOpacity(0.5) : Colors.grey.shade50) 
            : _kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: effectiveError ? Colors.black.withOpacity(0.04) : _kGreen700.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: Opacity(
        opacity: effectiveError ? 0.35 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
                _deviceDisplayNames[subtitle] ?? title,
                subtitle,
                ip,
                effectiveError,
                PhosphorIcons.plant(),



                onTypeChange,
                onRename,
                onDelete),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                Expanded(flex: 3, child: _liveValue(PhosphorIcons.thermometer(), '$temp °C', 'Temp',
                    const Color(0xFFFF7043))),
                const SizedBox(width: 6),
                Expanded(flex: 3, child: _liveValue(PhosphorIcons.drop(), '$moisture %',
                    'Moisture', const Color(0xFF29B6F6))),
                const SizedBox(width: 6),
                Expanded(flex: 3, child: _liveValue(PhosphorIcons.lightning(), ec, 'EC',
                    const Color(0xFF8D6E63))),
                const SizedBox(width: 6),
                Expanded(flex: 3, child: _liveValue(Icons.science_outlined, ph, 'pH',
                    const Color(0xFF66BB6A))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: _liveValue(Icons.filter_vintage_rounded, '$n', 'N',
                    const Color(0xFF9CCC65))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: _liveValue(Icons.filter_vintage_rounded, '$p', 'P',
                    const Color(0xFFFFB74D))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: _liveValue(Icons.filter_vintage_rounded, '$k', 'K',
                    const Color(0xFFBA68C8))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: RepaintBoundary(
                child: MultiLineChart(
                  expand: true,
                  series: [
                    ChartSeries(
                        data: apiService.tempHistory,
                        color: const Color(0xFFFF7043),
                        label: 'Temp'),
                    ChartSeries(
                        data: apiService.moistureHistory,
                        color: const Color(0xFF29B6F6),
                        label: 'Moisture'),
                    ChartSeries(
                        data: apiService.ecHistory,
                        color: const Color(0xFF8D6E63),
                        label: 'EC',
                        normalize: 0.1),
                    ChartSeries(
                        data: apiService.phHistory,
                        color: const Color(0xFF66BB6A),
                        label: 'pH'),
                    ChartSeries(
                        data: apiService.nitrogenHistory,
                        color: const Color(0xFF9CCC65),
                        label: 'N',
                        normalize: 10.0),
                    ChartSeries(
                        data: apiService.phosphorusHistory,
                        color: const Color(0xFFFFB74D),
                        label: 'P',
                        normalize: 10.0),
                    ChartSeries(
                        data: apiService.potassiumHistory,
                        color: const Color(0xFFBA68C8),
                        label: 'K',
                        normalize: 10.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _legendDot(const Color(0xFFFF7043), 'Temp'),
                _legendDot(const Color(0xFF29B6F6), 'Moisture'),
                _legendDot(const Color(0xFF8D6E63), 'EC'),
                _legendDot(const Color(0xFF66BB6A), 'pH'),
                _legendDot(const Color(0xFF9CCC65), 'N'),
                _legendDot(const Color(0xFFFFB74D), 'P'),
                _legendDot(const Color(0xFFBA68C8), 'K'),
                Text(
                    effectiveError ? 'OFFLINE' : 'SOIL SENSOR',
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        color: effectiveError ? Colors.red : _kGreen700,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildMineralFarmCard({
    required String title,
    required String subtitle,
    required String ip,
    required SensorApiService apiService,
    required bool isFetching,
    required bool isError,
    required VoidCallback onRetry,
    required Function(SensorType) onTypeChange,
    required VoidCallback onRename,
    required VoidCallback onDelete,
  }) {
    if (isFetching && apiService.count == 0) {
      return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(24)),
          child: const Center(
              child: CircularProgressIndicator(
                  color: _kGreen700, strokeWidth: 2.5)));
    }

    final snap = apiService.latest;
    final lastTime = snap?.time;
    final isOffline = lastTime != null && DateTime.now().difference(lastTime).inSeconds > 60;
    final effectiveError = isError || isOffline;

    final ec = snap?.ec.toStringAsFixed(2) ?? '--';
    final temp = snap?.temperature.toStringAsFixed(1) ?? '--';
    final ph = snap?.ph.toStringAsFixed(1) ?? '--';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: effectiveError
            ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900.withOpacity(0.5) : Colors.grey.shade50)
            : _kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: effectiveError ? Colors.black.withOpacity(0.04) : _kGreen700.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: Opacity(
        opacity: effectiveError ? 0.35 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
                _deviceDisplayNames[subtitle] ?? title,
                subtitle,
                ip,
                effectiveError,
                Icons.science_rounded,
                onTypeChange,
                onRename,
                onDelete),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                Expanded(child: _liveValue(PhosphorIcons.lightning(), ec, 'EC',
                    const Color(0xFF8D6E63))),
                const SizedBox(width: 6),
                Expanded(child: _liveValue(Icons.science_outlined, ph, 'pH',
                    const Color(0xFF66BB6A))),
                const SizedBox(width: 6),
                Expanded(child: _liveValue(PhosphorIcons.thermometer(), '$temp °C', 'Temp',
                    const Color(0xFFFF7043))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: RepaintBoundary(
                child: MultiLineChart(
                  expand: true,
                  series: [
                    ChartSeries(
                        data: apiService.ecHistory,
                        color: const Color(0xFF8D6E63),
                        label: 'EC',
                        normalize: 0.1),
                    ChartSeries(
                        data: apiService.phHistory,
                        color: const Color(0xFF66BB6A),
                        label: 'pH'),
                    ChartSeries(
                        data: apiService.tempHistory,
                        color: const Color(0xFFFF7043),
                        label: 'Temp'),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                _legendDot(const Color(0xFF8D6E63), 'EC'),
                const SizedBox(width: 8),
                _legendDot(const Color(0xFF66BB6A), 'pH'),
                const SizedBox(width: 8),
                _legendDot(const Color(0xFFFF7043), 'Temp'),
                const Spacer(),
                Text(
                    effectiveError ? 'OFFLINE' : 'MINERAL SENSOR',
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        color: effectiveError ? Colors.red : _kGreen700,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCardHeader(
      String title,
      String subtitle,
      String ip,
      bool isError,
      IconData icon,
      Function(SensorType) onTypeChange,
      VoidCallback onRename,
      VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: _kGreen700.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _kGreen700, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                        letterSpacing: -0.4)),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _kTextMuted)),
                if (ip.isNotEmpty)
                  Text(ip,
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          color: isError
                              ? Colors.red.shade300
                              : _kGreen700.withOpacity(0.7),
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: isError
                        ? Colors.red.shade50
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isError
                                ? Colors.red.shade400
                                : _kGreen400)),
                    const SizedBox(width: 4),
                    Text(
                        isError ? 'OFFLINE' : 'ONLINE',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isError
                                ? Colors.red.shade400
                                : _kGreen700)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              PopupMenuButton<dynamic>(
                icon: Icon(Icons.more_horiz,
                    color: _kTextMuted, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val is SensorType) onTypeChange(val);
                  if (val == 'rename') onRename();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 10),
                        Text('Rename', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Delete Device', style: TextStyle(fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('Move Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const PopupMenuItem(
                    value: SensorType.element,
                    child: Text('Environmental', style: TextStyle(fontSize: 12)),
                  ),
                  const PopupMenuItem(
                    value: SensorType.soil,
                    child: Text('Soil Sensor', style: TextStyle(fontSize: 12)),
                  ),
                  const PopupMenuItem(
                    value: SensorType.mineral,
                    child: Text('Mineral Sensor', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Inline Sidebar Calendar
// ══════════════════════════════════════════════════════════════════

class _SidebarCalendar extends StatefulWidget {
  final SensorDataManager manager;
  final Color accentColor;
  final Color surfaceColor;
  final Color textDark;
  final Color textMuted;

  const _SidebarCalendar({
    Key? key,
    required this.manager,
    required this.accentColor,
    required this.surfaceColor,
    required this.textDark,
    required this.textMuted,
  }) : super(key: key);

  @override
  State<_SidebarCalendar> createState() => _SidebarCalendarState();
}

class _SidebarCalendarState extends State<_SidebarCalendar> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _viewMonth;

  static const _enMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _enDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    if (widget.manager.selectedStart != null && widget.manager.selectedEnd != null) {
      _start = _stripTime(widget.manager.selectedStart!);
      _end = _stripTime(widget.manager.selectedEnd!);
    } else {
      _start = null;
      _end = null;
    }
    _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  void _onDayTap(DateTime day) {
    final now = _stripTime(DateTime.now());
    if (day.isAfter(now)) return;

    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day;
        _end = null;
      } else {
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
        if (_end!.difference(_start!).inDays >= 30) {
          _end = _start!.add(const Duration(days: 29));
        }
      }
    });
  }

  void _resetSelection() async {
    setState(() {
      _start = null;
      _end = null;
    });
    await widget.manager.resetToDefaultHistory();
  }

  bool _isSelected(DateTime day) {
    if (_start == null) return false;
    if (_end == null) return day == _start;
    return !day.isBefore(_start!) && !day.isAfter(_end!);
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildCalendarDays();
    final now = _stripTime(DateTime.now());
    final minDate = now.subtract(const Duration(days: 30));
    final canConfirm = _start != null && _end != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.accentColor.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          // Nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn(Icons.chevron_left_rounded, () {
                setState(() => _viewMonth =
                    DateTime(_viewMonth.year, _viewMonth.month - 1));
              }),
              Text(
                '${_enMonths[_viewMonth.month - 1]} ${_viewMonth.year}',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.textDark),
              ),
              _navBtn(
                  Icons.chevron_right_rounded,
                  _viewMonth.year == now.year && _viewMonth.month == now.month
                      ? null
                      : () {
                          setState(() => _viewMonth =
                              DateTime(_viewMonth.year, _viewMonth.month + 1));
                        }),
            ],
          ),
          const SizedBox(height: 12),
          // Day Headers
          Row(
            children: _enDays
                .map((d) => Expanded(
                      child: Center(
                          child: Text(d,
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.textMuted))),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 1.1),
            itemCount: cells.length,
            itemBuilder: (ctx, i) {
              final day = cells[i];
              if (day == null) return const SizedBox();
              final disabled = day.isAfter(now) || day.isBefore(minDate);
              final selected = _isSelected(day);
              final isEdge = (_start != null && day == _start) ||
                  (_end != null && day == _end);

              return GestureDetector(
                onTap: disabled ? null : () => _onDayTap(day),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isEdge
                        ? widget.accentColor
                        : (selected
                            ? widget.accentColor.withOpacity(0.12)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(6),
                    border: day == now && !isEdge
                        ? Border.all(color: widget.accentColor.withOpacity(0.5))
                        : null,
                  ),
                  child: Center(
                    child: Text('${day.day}',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isEdge
                                ? Colors.white
                                : (disabled
                                    ? widget.textMuted.withOpacity(0.3)
                                    : widget.textDark),
                            fontWeight:
                                isEdge ? FontWeight.bold : FontWeight.w400)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // ActionButton - แยก AnimatedBuilder เพื่อให้ตอบสนองเร็วขึ้นเฉพาะจุด
          AnimatedBuilder(
            animation: widget.manager,
            builder: (context, _) {
              final isFetching = widget.manager.isFetchingHistory;
              
              return Column(
                children: [
                  if (_start != null && _end != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_fmtShort(_start!)} – ${_fmtShort(_end!)}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.accentColor),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canConfirm && !isFetching
                          ? () async {
                              final hours =
                                  _end!.difference(_start!).inHours.clamp(1, 720);
                              await widget.manager.fetchGlobalHistoryByRange(
                                  start: _start!,
                                  end: DateTime(_end!.year, _end!.month,
                                      _end!.day, 23, 59, 59),
                                  hours: hours);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: isFetching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('View Data',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: isFetching ? null : () => _resetSelection(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: widget.accentColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reset to Standard',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<DateTime?> _buildCalendarDays() {
    final firstOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final firstWeekday = firstOfMonth.weekday % 7;
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final List<DateTime?> cells = [];
    for (int i = 0; i < firstWeekday; i++) cells.add(null);
    for (int d = 1; d <= daysInMonth; d++)
      cells.add(DateTime(_viewMonth.year, _viewMonth.month, d));
    return cells;
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: onTap != null
                ? widget.accentColor.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6)),
        child: Icon(icon,
            color: onTap != null
                ? widget.accentColor
                : widget.accentColor.withOpacity(0.2),
            size: 18),
      ),
    );
  }

  String _fmtShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

String _fmtFull(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';