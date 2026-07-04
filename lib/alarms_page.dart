import 'package:go_router/go_router.dart';
import 'theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'services/alarm_service.dart';
import 'services/auth_service.dart';
import 'widgets/top_bar.dart';

// ── Theme constants ──────────────────────────────────────────────────────────
const _kGreen700      = Color(0xFF2E7D32);
const _kGreen400      = Color(0xFF66BB6A);

class AlarmsPage extends StatefulWidget {
  final int initialIndex;
  const AlarmsPage({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends State<AlarmsPage>
    with SingleTickerProviderStateMixin {
  Color get _kBg      => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF121212) : const Color(0xFFF0F4F0);
  Color get _kSurface => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  Color get _kTextDark => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE0E0E0) : const Color(0xFF1A2E1A);
  Color get _kMuted   => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA0A0A0) : const Color(0xFF6B8068);

  final AlarmService _service = AlarmService();
  late TabController _tab;
  bool _loading = true;
  String _selectedHistory = '24'; // in hours
  Timer? _timer;
  final ValueNotifier<int> _contentRefreshNotifier = ValueNotifier(0);

  // Threshold Controllers
  final _tempMinCtrl = TextEditingController(text: '5.0');
  final _tempMaxCtrl = TextEditingController(text: '50.0');
  final _humMinCtrl = TextEditingController(text: '5.0');
  final _humMaxCtrl = TextEditingController(text: '5.0');
  final _eco2MaxCtrl = TextEditingController(text: '5');

  // Soil Controllers
  final _soilEcMinCtrl = TextEditingController(text: '0.5');
  final _soilEcMaxCtrl = TextEditingController(text: '3.5');
  final _soilRhMinCtrl = TextEditingController(text: '20.0');
  final _soilRhMaxCtrl = TextEditingController(text: '80.0');

  // Mineral Controllers
  final _minEcMinCtrl = TextEditingController(text: '0.5');
  final _minEcMaxCtrl = TextEditingController(text: '3.5');
  final _nMinCtrl = TextEditingController(text: '10');
  final _nMaxCtrl = TextEditingController(text: '200');
  final _pMinCtrl = TextEditingController(text: '5');
  final _pMaxCtrl = TextEditingController(text: '100');
  final _kMinCtrl = TextEditingController(text: '10');
  final _kMaxCtrl = TextEditingController(text: '250');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _service.fetchAll(historyHours: int.parse(_selectedHistory));
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _timer?.cancel();
    _tempMinCtrl.dispose();
    _tempMaxCtrl.dispose();
    _humMinCtrl.dispose();
    _humMaxCtrl.dispose();
    _eco2MaxCtrl.dispose();
    _soilEcMinCtrl.dispose();
    _soilEcMaxCtrl.dispose();
    _soilRhMinCtrl.dispose();
    _soilRhMaxCtrl.dispose();
    _minEcMinCtrl.dispose();
    _minEcMaxCtrl.dispose();
    _nMinCtrl.dispose();
    _nMaxCtrl.dispose();
    _pMinCtrl.dispose();
    _pMaxCtrl.dispose();
    _kMinCtrl.dispose();
    _kMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _service.fetchAll(historyHours: int.parse(_selectedHistory));
    _loading = false;
    if (mounted) _contentRefreshNotifier.value++;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService().currentRole == 'admin';
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const TopBar(),
          // Sub-header for Alarms with TabBar
          Container(
            color: _kSurface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kGreen700, size: 20),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      Text('Alarms',
                          style: GoogleFonts.inter(
                            color: _kTextDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          )),
                      const Spacer(),
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(Icons.settings_rounded, color: _kGreen700),
                          tooltip: 'Manage Thresholds',
                          onPressed: _showManageAlarmsDialog,
                        ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: _kGreen700),
                        onPressed: () {
                          _loading = true;
                          _contentRefreshNotifier.value++;
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tab,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                  labelColor: _kGreen700,
                  unselectedLabelColor: _kMuted,
                  indicatorColor: _kGreen700,
                  indicatorWeight: 2.5,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Active '),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red.shade500, borderRadius: BorderRadius.circular(6)),
                            child: Text('${_service.activeAlarms.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ),
                    ),
                    Tab(text: 'History ${_getRangeLabel(_selectedHistory)} (${_service.historyAlarms.where((a) => a.hasValue).length})'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _contentRefreshNotifier,
              builder: (context, _, __) {
                return _loading
                    ? const Center(child: CircularProgressIndicator(color: _kGreen700))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: _kGreen700,
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            _buildActiveTab(),
                            _buildHistoryTab(),
                          ],
                        ),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Summary Cards ────────────────────────────────────────────────────────

  Widget _buildSummaryRow() {
    final byType = <String, int>{};
    for (final a in _service.activeAlarms) {
      byType[a.alertType] = (byType[a.alertType] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _summaryCard('Critical', _service.criticalCount,
              const Color(0xFFD32F2F), Icons.warning_amber_rounded),
          const SizedBox(width: 10),
          _summaryCard('Types', byType.length,
              const Color(0xFFF57C00), Icons.category_rounded),
          const SizedBox(width: 10),
          _summaryCard('Total', _service.totalActive,
              _kGreen700, Icons.notifications_active_rounded),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.10),
                blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: _kMuted)),
                Icon(Icons.open_in_new_rounded,
                    size: 13, color: _kMuted.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('$count',
                    style: GoogleFonts.inter(
                        fontSize: 26, fontWeight: FontWeight.w800,
                        color: _kTextDark, height: 1)),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Icon(icon, color: color, size: 18),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active Tab ───────────────────────────────────────────────────────────

  Widget _buildActiveTab() {
    final alarms = _service.activeAlarms;

    return CustomScrollView(
      slivers: [
        if (alarms.isEmpty)
          SliverFillRemaining(
            child: _buildEmpty('ไม่มี Alarm ที่ Active อยู่',
                Icons.check_circle_outline_rounded, Colors.green),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildAlarmCard(alarms[i], isActive: true),
                childCount: alarms.length,
              ),
            ),
          ),
      ],
    );
  }

  // ─── History Tab ──────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    // แสดงเฉพาะ record ที่มีค่า (ไม่ใช่ null entries)
    final items = _service.historyAlarms.where((a) => a.hasValue).toList();
    final byType = _service.historyByType;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHistoryRangeSelector(),
                const SizedBox(height: 16),
                _buildHistorySummary(byType),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            child: _buildEmpty('ไม่มีประวัติใน 24 ชั่วโมง',
                Icons.history_rounded, _kMuted),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildAlarmCard(items[i], isActive: false),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistorySummary(Map<String, int> byType) {
    if (byType.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('สรุปตามประเภท',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: byType.entries.map((e) {
              final dummy = AlarmItem(
                deviceId: '', alertType: e.key,
                triggeredAt: DateTime.now(), acknowledged: false);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: dummy.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(dummy.icon, color: dummy.color, size: 13),
                    const SizedBox(width: 5),
                    Text('${dummy.label}  ${e.value}x',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: dummy.color)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Alarm Card ───────────────────────────────────────────────────────────

  Widget _buildAlarmCard(AlarmItem alarm, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alarm.color.withOpacity(isActive ? 0.25 : 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(color: alarm.color.withOpacity(0.06),
              blurRadius: 10, offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: alarm.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(alarm.icon, color: alarm.color, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(alarm.label,
                            style: GoogleFonts.inter(
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: alarm.color)),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5, height: 5,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFD32F2F),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Text('ACTIVE',
                                  style: GoogleFonts.inter(
                                      fontSize: 9, fontWeight: FontWeight.w800,
                                      color: const Color(0xFFD32F2F))),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Device ID
                  Text(alarm.deviceId,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: _kMuted,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),

                  // Value / Threshold row
                  if (alarm.hasValue)
                    Row(
                      children: [
                        _valueChip('ค่าที่วัด',
                            '${alarm.value!.toStringAsFixed(2)} ${alarm.unit}',
                            alarm.color),
                        const SizedBox(width: 8),
                        _valueChip('Threshold',
                            '${alarm.threshold!.toStringAsFixed(1)} ${alarm.unit}',
                            _kMuted),
                      ],
                    ),
                  const SizedBox(height: 8),

                  // Time footer
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? alarm.color.withOpacity(0.05) : _kMuted.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_filled_rounded,
                                size: 13, color: alarm.color.withOpacity(0.8)),
                            const SizedBox(width: 6),
                            Text(alarm.timeFormatted,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _kTextDark,
                                    letterSpacing: -0.2)),
                          ],
                        ),
                        if (isActive && alarm.timeElapsed != null)
                          Text(alarm.timeElapsed!,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: alarm.color,
                                  fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 9, color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildHistoryRangeSelector() {
    final options = [
      {'label': '24H', 'val': '24'},
      {'label': '7D',  'val': '168'},
      {'label': '30D', 'val': '720'},
      {'label': '90D', 'val': '2160'},
    ];

    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        itemBuilder: (context, i) {
          final opt = options[i];
          final isSel = _selectedHistory == opt['val'];
          return GestureDetector(
            onTap: () {
              if (!isSel) {
                setState(() {
                  _selectedHistory = opt['val']!;
                  _loading = true;
                });
                _load();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSel ? _kGreen700 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSel ? _kGreen700 : _kMuted.withOpacity(0.2)),
              ),
              alignment: Alignment.center,
              child: Text(opt['label']!,
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: isSel ? Colors.white : _kMuted,
                  )),
            ),
          );
        },
      ),
    );
  }

  String _getRangeLabel(String hours) {
    if (hours == '24') return '24h';
    if (hours == '168') return '7d';
    if (hours == '720') return '30d';
    if (hours == '2160') return '90d';
    return '${hours}h';
  }

  Widget _buildEmpty(String msg, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.inter(fontSize: 15, color: _kMuted)),
        ],
      ),
    );
  }

  void _showManageAlarmsDialog() async {
  // Show loading indicator while fetching
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: _kGreen700)),
  );

  // Fetch all thresholds first
  final results = await Future.wait([
    _service.fetchTelemetryThresholds(),
    _service.fetchSoilThresholds(),
    _service.fetchMineralThresholds(),
  ]);

  final current = results[0];
  final soil    = results[1];
  final mineral = results[2];

  // Populate controllers with fetched values (or keep existing defaults)
  if (current != null && current is Map) {
    _tempMinCtrl.text = (current['temperature_min'] ?? current['temp_min'] ?? _tempMinCtrl.text).toString();
    _tempMaxCtrl.text = (current['temperature_max'] ?? current['temp_max'] ?? _tempMaxCtrl.text).toString();
    _humMinCtrl.text  = (current['humidity_min']    ?? current['hum_min']  ?? _humMinCtrl.text).toString();
    _humMaxCtrl.text  = (current['humidity_max']    ?? current['hum_max']  ?? _humMaxCtrl.text).toString();
    _eco2MaxCtrl.text = (current['eco2_max']        ?? current['eco2']     ?? _eco2MaxCtrl.text).toString();
  }

  if (soil != null && soil is Map) {
    _soilEcMinCtrl.text = (soil['ec_min'] ?? _soilEcMinCtrl.text).toString();
    _soilEcMaxCtrl.text = (soil['ec_max'] ?? _soilEcMaxCtrl.text).toString();
    _soilRhMinCtrl.text = (soil['rh_min'] ?? _soilRhMinCtrl.text).toString();
    _soilRhMaxCtrl.text = (soil['rh_max'] ?? _soilRhMaxCtrl.text).toString();
  }

  if (mineral != null && mineral is Map) {
    _minEcMinCtrl.text = (mineral['ec_min'] ?? _minEcMinCtrl.text).toString();
    _minEcMaxCtrl.text = (mineral['ec_max'] ?? _minEcMaxCtrl.text).toString();
    _nMinCtrl.text     = (mineral['n_min']  ?? _nMinCtrl.text).toString();
    _nMaxCtrl.text     = (mineral['n_max']  ?? _nMaxCtrl.text).toString();
    _pMinCtrl.text     = (mineral['p_min']  ?? _pMinCtrl.text).toString();
    _pMaxCtrl.text     = (mineral['p_max']  ?? _pMaxCtrl.text).toString();
    _kMinCtrl.text     = (mineral['k_min']  ?? _kMinCtrl.text).toString();
    _kMaxCtrl.text     = (mineral['k_max']  ?? _kMaxCtrl.text).toString();
  }

  if (!mounted) return;
  Navigator.pop(context); // Close loading indicator

  // Now show dialog with all values ready
  showDialog(
    context: context,
    builder: (context) {
      bool saving = false;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _kSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('จัดการการแจ้งเตือน (Manage Alarms)',
                style: GoogleFonts.inter(
                    color: _kTextDark, fontWeight: FontWeight.bold, fontSize: 18)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ข้อมูลที่รับเข้ามาและการตั้งค่าขีดจำกัด (Thresholds)',
                        style: GoogleFonts.inter(color: _kMuted, fontSize: 13)),
                    const SizedBox(height: 16),

                    _buildCategoryHeader('Environmental Sensors', Icons.wb_sunny_rounded),
                    _buildThresholdRow('Temperature (°C)', _tempMinCtrl, _tempMaxCtrl),
                    _buildThresholdRow('Humidity (%)', _humMinCtrl, _humMaxCtrl),
                    _buildSingleThresholdRow('CO2 (ppm)', _eco2MaxCtrl, 'Max'),

                    const SizedBox(height: 12),
                    Text('',
                        style: GoogleFonts.inter(
                            color: Colors.orange.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),

                    const SizedBox(height: 24),
                    _buildCategoryHeader('Soil Sensors', Icons.grass_rounded),
                    _buildThresholdRow('Soil EC (mS/cm)', _soilEcMinCtrl, _soilEcMaxCtrl),
                    _buildThresholdRow('Soil Moisture / RH (%)', _soilRhMinCtrl, _soilRhMaxCtrl),

                    const SizedBox(height: 24),
                    _buildCategoryHeader('Mineral Sensors (NPK)', Icons.science_rounded),
                    _buildThresholdRow('Mineral EC (mS/cm)', _minEcMinCtrl, _minEcMaxCtrl),
                    _buildThresholdRow('Nitrogen (N) (ppm)', _nMinCtrl, _nMaxCtrl),
                    _buildThresholdRow('Phosphorus (P) (ppm)', _pMinCtrl, _pMaxCtrl),
                    _buildThresholdRow('Potassium (K) (ppm)', _kMinCtrl, _kMaxCtrl),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: Text('ยกเลิก', style: TextStyle(color: _kMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen700,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        //Snapshot ค่าทันทีที่กดปุ่ม ก่อน async ใดๆ
                        final tempMin = double.tryParse(_tempMinCtrl.text.trim()) ?? 5.0;
                        final tempMax = double.tryParse(_tempMaxCtrl.text.trim()) ?? 50.0;
                        final humMin  = double.tryParse(_humMinCtrl.text.trim())  ?? 5.0;
                        final humMax  = double.tryParse(_humMaxCtrl.text.trim())  ?? 5.0;
                        final eco2Max = int.tryParse(_eco2MaxCtrl.text.trim())    ?? 5;

                        final soilEcMin = double.tryParse(_soilEcMinCtrl.text.trim()) ?? 0.5;
                        final soilEcMax = double.tryParse(_soilEcMaxCtrl.text.trim()) ?? 3.5;
                        final soilRhMin = double.tryParse(_soilRhMinCtrl.text.trim()) ?? 20.0;
                        final soilRhMax = double.tryParse(_soilRhMaxCtrl.text.trim()) ?? 80.0;

                        final minEcMin = double.tryParse(_minEcMinCtrl.text.trim()) ?? 0.5;
                        final minEcMax = double.tryParse(_minEcMaxCtrl.text.trim()) ?? 3.5;
                        final nMin = double.tryParse(_nMinCtrl.text.trim()) ?? 10;
                        final nMax = double.tryParse(_nMaxCtrl.text.trim()) ?? 200;
                        final pMin = double.tryParse(_pMinCtrl.text.trim()) ?? 5;
                        final pMax = double.tryParse(_pMaxCtrl.text.trim()) ?? 100;
                        final kMin = double.tryParse(_kMinCtrl.text.trim()) ?? 10;
                        final kMax = double.tryParse(_kMaxCtrl.text.trim()) ?? 250;

                        // Log เพื่อ verify ค่าก่อนส่ง
                        debugPrint('[SAVE] temp=$tempMin~$tempMax hum=$humMin~$humMax eco2=$eco2Max');
                        debugPrint('[SAVE] soil ec=$soilEcMin~$soilEcMax rh=$soilRhMin~$soilRhMax');
                        debugPrint('[SAVE] mineral ec=$minEcMin~$minEcMax N=$nMin~$nMax P=$pMin~$pMax K=$kMin~$kMax');

                        setDialogState(() => saving = true);

                        final results = await _service.updateAllThresholds(
                          tempMin: tempMin, tempMax: tempMax,
                          humMin: humMin,   humMax: humMax,
                          eco2Max: eco2Max,
                          soilEcMin: soilEcMin, soilEcMax: soilEcMax,
                          soilRhMin: soilRhMin, soilRhMax: soilRhMax,
                          minEcMin: minEcMin,   minEcMax: minEcMax,
                          nMin: nMin, nMax: nMax,
                          pMin: pMin, pMax: pMax,
                          kMin: kMin, kMax: kMax,
                        );

                        final allSuccess = results.values.every((v) => v);
                        final failedGroups = results.entries
                            .where((e) => !e.value)
                            .map((e) => e.key)
                            .join(', ');

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                allSuccess
                                    ? 'บันทึกการตั้งค่าทั้งหมดสำเร็จ ✓'
                                    : 'บันทึกไม่สำเร็จ: $failedGroups',
                              ),
                              backgroundColor: allSuccess ? _kGreen700 : Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('บันทึก',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

  Widget _buildCategoryHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: _kGreen700, size: 18),
          const SizedBox(width: 8),
          Text(title, 
            style: GoogleFonts.inter(color: _kGreen700, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.2)
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: _kGreen700.withOpacity(0.2), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildSingleThresholdRow(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: GoogleFonts.inter(color: _kTextDark, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: '$hint',
                labelStyle: TextStyle(fontSize: 10, color: _kMuted),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 12, color: _kTextDark),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildThresholdRow(String label, TextEditingController minCtrl, TextEditingController maxCtrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: GoogleFonts.inter(color: _kTextDark, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: minCtrl,
              decoration: InputDecoration(
                labelText: 'Min',
                labelStyle: TextStyle(fontSize: 10, color: _kMuted),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 12, color: _kTextDark),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: maxCtrl,
              decoration: InputDecoration(
                labelText: 'Max',
                labelStyle: TextStyle(fontSize: 10, color: _kMuted),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 12, color: _kTextDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdRowPlaceholder(String label, String defaultLow, String defaultHigh) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: GoogleFonts.inter(color: _kTextDark, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'ต่ำสุด (Min)',
                labelStyle: TextStyle(fontSize: 10, color: _kMuted),
                hintText: defaultLow,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 12, color: _kTextDark),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'สูงสุด (Max)',
                labelStyle: TextStyle(fontSize: 10, color: _kMuted),
                hintText: defaultHigh,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 12, color: _kTextDark),
            ),
          ),
        ],
      ),
    );
  }
}
