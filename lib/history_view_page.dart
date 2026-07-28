import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // สำหรับ compute
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'services/sensor_api_service.dart';
import 'services/layout_api_service.dart';
import 'services/export_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'widgets/multi_line_chart.dart';
import 'widgets/top_bar.dart';
import 'services/sensor_data_manager.dart'; // ✅ Added missing import

class HistoryViewPage extends StatefulWidget {
  final String? initialDeviceId;
  const HistoryViewPage({Key? key, this.initialDeviceId}) : super(key: key);

  @override
  State<HistoryViewPage> createState() => _HistoryViewPageState();
}

class _HistoryViewPageState extends State<HistoryViewPage> {
  Color get _kBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _kSurface => Theme.of(context).cardColor;
  Color get _kTextDark => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFE0E0E0)
      : const Color(0xFF1A2E1A);
  Color get _kTextMuted => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA0A0A0)
      : const Color(0xFF6B8068);
  Color get _kPrimary => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF81C784)
      : const Color(0xFF1B5E20);

  bool _isLoading = true;
  String? _errorMessage;
  String? _errorRawData;

  List<String> _deviceIds = [];
  String? _selectedDeviceId;

  String _selectedInterval = '10m';
  bool _useRangeMode = false;

  List<SensorSnapshot> _historyData = [];
  List<SensorSnapshot> _filteredData = [];
  DateTimeRange? _selectedDateRange;
  Timer? _timer;
  final LayoutApiService _layoutApi = LayoutApiService();
  final SensorDataManager _manager = SensorDataManager(); // ✅ Added missing manager
  Map<String, String> _deviceDisplayNames = {};
  final ValueNotifier<int> _contentRefreshNotifier = ValueNotifier(0);

  String get _deviceType {
    if (_historyData.isNotEmpty) {
      final label = _historyData.first.sensorTypeLabel?.toLowerCase() ?? '';
      if (label == 'environmental' || label == 'environment') return 'environmental';
      if (label == 'soil') return 'soil';
      if (label == 'mineral') return 'mineral';
    }
    final id = _selectedDeviceId?.toLowerCase() ?? '';
    if (id.contains('soil')) return 'soil';
    if (id.contains('min') || id.contains('npk') || id.contains('nitro'))
      return 'mineral';
    return 'environmental';
  }

  @override
  void initState() {
    super.initState();
    _selectedDeviceId = widget.initialDeviceId;
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day, 0, 0, 0),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    _fetchHistoryByRange(_selectedDateRange!);
    _loadDisplayNames();
    _fetchDeviceListSilently();

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_useRangeMode && mounted) {
        _fetchHistoryByRange(_selectedDateRange!, background: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadDisplayNames() async {
    try {
      final Map<String, dynamic> layout = await _layoutApi.fetchLayout();

      List<String> layoutDeviceIds = [];
      if (layout.containsKey('boards') && layout['boards'] is List) {
        final boards = layout['boards'] as List;
        for (var b in boards) {
          if (b is Map && b.containsKey('deviceId')) {
            layoutDeviceIds.add(b['deviceId'].toString());
          }
        }
      }

      if (layout.containsKey('deviceDisplayNames')) {
        final Map<String, dynamic> rawNames =
            Map<String, dynamic>.from(layout['deviceDisplayNames']);
        if (mounted) {
          setState(() {
            _deviceDisplayNames =
                rawNames.map((k, v) => MapEntry(k, v.toString()));
            
            // ✅ Sync with Manager and Layout (with explicit type casting)
            final merged = <String>{
              ..._deviceIds, 
              ...layoutDeviceIds, 
              ..._manager.deviceIds
            }.toList()..sort();
            _deviceIds = merged;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading display names: $e');
    }
  }

  Future<void> _fetchDeviceListSilently() async {
    try {
      final res = await http
          .get(Uri.parse('http://100.70.171.1:5000/api/devices'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<String> ids = [];
        if (decoded is Map) {
          ids = decoded.keys.map((e) => e.toString()).toList();
        } else if (decoded is List) {
          for (var item in decoded) {
            if (item is String)
              ids.add(item);
            else if (item is Map && item.containsKey('id')) {
              ids.add(item['id'].toString());
            }
          }
        }
        ids.sort();
        if (mounted) {
          setState(() {
            // ✅ Sync with Manager's master list (with explicit type casting)
            _deviceIds = <String>{
              ..._deviceIds, 
              ...ids, 
              ..._manager.deviceIds
            }.toList()..sort();
            
            if (_selectedDeviceId == null && _deviceIds.isNotEmpty) {
              _selectedDeviceId = _deviceIds.first;
              _fetchHistoryByRange(_selectedDateRange!);
            } else if (_selectedDeviceId != null && !_deviceIds
                .map((e) => e.toLowerCase())
                .contains(_selectedDeviceId!.toLowerCase())) {
              // Only reset if current selection is totally missing (unlikely now)
              _selectedDeviceId = _deviceIds.first;
              _fetchHistoryByRange(_selectedDateRange!);
            }
          });
        }
      }
    } catch (_) {
      debugPrint('DeviceList fetch failed (non-fatal) — using initialDeviceId only');
    }
  }

  Future<void> _fetchHistory({bool background = false}) async {
    final targetRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 1)),
          end: DateTime.now(),
        );
    await _fetchHistoryByRange(targetRange, background: background);
  }

  Future<void> _fetchHistoryByRange(DateTimeRange range,
      {bool background = false}) async {
    if (_selectedDeviceId == null) {
      if (!background) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'กรุณาเลือกบอร์ดที่ต้องการดูข้อมูล';
        });
      }
      return;
    }

    if (!background) {
      _isLoading = true;
      _historyData = [];
      _filteredData = [];
      _errorMessage = null;
      _errorRawData = null;
      _contentRefreshNotifier.value++;
    }

    try {
      DateTime startLocal = range.start;
      DateTime endLocal = DateTime(
          range.end.year, range.end.month, range.end.day, 23, 59, 59);
      String startStr =
          "${startLocal.toUtc().toIso8601String().split('.')[0]}Z";
      String endStr = "${endLocal.toUtc().toIso8601String().split('.')[0]}Z";
      startStr = Uri.encodeComponent(startStr);
      endStr = Uri.encodeComponent(endStr);

      String every = _selectedInterval;
      if (every == 'all') every = '1h';
      if (every == '60m') every = '1h';

      final deviceParam =
          _selectedDeviceId != null ? '&device_id=$_selectedDeviceId' : '';
      final url =
          'http://100.70.171.1:5000/api/sensors/range'
          '?start=$startStr&end=$endStr&every=$every$deviceParam';

      debugPrint('Fetching History: $url');
      _errorRawData = 'Requesting: $url';

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 90));

      if (res.statusCode == 200) {
        final Map<String, dynamic> parseParams = {
          'body': res.body,
          'selectedDeviceId': _selectedDeviceId,
        };

        final Map<String, dynamic> result =
            await compute(_parseHistoryInBackground, parseParams);

        final List<SensorSnapshot> parsed =
            result['parsed'] as List<SensorSnapshot>;
        final Set<String> foundDeviceIds =
            result['foundDeviceIds'] as Set<String>;

        if (foundDeviceIds.isNotEmpty && mounted) {
          final merged = {..._deviceIds, ...foundDeviceIds}.toList()..sort();
          setState(() => _deviceIds = merged);
        }

        if (!background) {
          _historyData = parsed;
          _errorMessage = parsed.isEmpty ? 'ไม่พบข้อมูลในช่วงวันที่เลือก' : null;
          _filteredData = parsed;
        } else if (mounted) {
          _historyData = parsed;
          _filteredData = parsed;
        }
      } else {
        if (!background) {
          _errorMessage = 'HTTP Error ${res.statusCode}';
          _errorRawData = res.body;
        }
      }
    } on TimeoutException {
      if (!background) {
        _errorMessage = 'การเชื่อมต่อหมดเวลา กรุณาลองใหม่';
        _errorRawData =
            'Timeout 90s — ลองเลือก Interval ที่หยาบกว่า เช่น 10m หรือ 60m';
      }
    } catch (e) {
      debugPrint('History Fetch Error: $e');
      if (!background) {
        _errorMessage = 'Fetch failed: $e';
        _errorRawData = e.toString();
      }
    }

    if (mounted && !background) {
      _isLoading = false;
      _contentRefreshNotifier.value++;
    }
  }

  // ─── FIXED: fetch ตรงๆ ต่อ device ไม่ขึ้นกับ online status ──────────────
  Future<List<SensorSnapshot>> _fetchDataIndependently(
      String? deviceId, DateTimeRange range, String interval) async {
    DateTime startLocal = range.start;
    DateTime endLocal = DateTime(
        range.end.year, range.end.month, range.end.day, 23, 59, 59);
    String startStr = Uri.encodeComponent(
        "${startLocal.toUtc().toIso8601String().split('.')[0]}Z");
    String endStr = Uri.encodeComponent(
        "${endLocal.toUtc().toIso8601String().split('.')[0]}Z");

    String every = interval;
    if (every == 'all') every = '1h';
    if (every == '60m') every = '1h';

    // ระบุ device_id ตรงๆ → API return history จาก DB ไม่ว่า device จะ online หรือไม่
    final deviceParam = deviceId != null ? '&device_id=$deviceId' : '';
    final url =
        'http://100.70.171.1:5000/api/sensors/range'
        '?start=$startStr&end=$endStr&every=$every$deviceParam';

    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 90));
      if (res.statusCode == 200) {
        final result = await compute(_parseHistoryInBackground, {
          'body': res.body,
          'selectedDeviceId': deviceId,
        });
        return result['parsed'] as List<SensorSnapshot>;
      }
    } catch (e) {
      debugPrint('_fetchDataIndependently error for $deviceId: $e');
    }
    return [];
  }

  Future<void> _exportToExcel() async {
    final List<String> availableDevices = _deviceIds.isNotEmpty
        ? _deviceIds
        : (_selectedDeviceId != null ? [_selectedDeviceId!] : []);

    if (availableDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลบอร์ดที่จะทำการ Export')),
      );
      return;
    }

    List<String> selectedForExport =
        _selectedDeviceId != null ? [_selectedDeviceId!] : [];

    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        List<String> tempSelected = List.from(selectedForExport);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isAllSelected = tempSelected.length == availableDevices.length;

            return AlertDialog(
              title: Text('เลือกบอร์ดที่ต้องการ Export',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('เลือกทั้งหมด',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      activeColor: _kPrimary,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            tempSelected = List.from(availableDevices);
                          } else {
                            tempSelected.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: availableDevices.map((id) {
                            return CheckboxListTile(
                              title: Text(_deviceDisplayNames[id] ?? id),
                              value: tempSelected.contains(id),
                              activeColor: _kPrimary,
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    tempSelected.add(id);
                                  } else {
                                    tempSelected.remove(id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ยกเลิก',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: tempSelected.isEmpty
                      ? null
                      : () => Navigator.pop(context, tempSelected),
                  style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                  child: const Text('Export',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<SensorSnapshot> exportData = [];
      String exportDeviceId;

      if (result.length == availableDevices.length) {
        // Export ทุก device → fetch โดยไม่ระบุ device_id เดียว
        exportDeviceId = 'All';
        exportData = await _fetchDataIndependently(
            null, _selectedDateRange!, _selectedInterval);
      } else {
        exportDeviceId = result.join(',');
        // ✅ FIXED: fetch แต่ละ device โดยตรงด้วย device_id
        // ทำให้ได้ historical data จาก DB แม้ device จะ offline
        final futures = result.map((deviceId) =>
            _fetchDataIndependently(deviceId, _selectedDateRange!, _selectedInterval));
        final results = await Future.wait(futures);
        exportData = results.expand((list) => list).toList();
        exportData.sort((a, b) => a.time.compareTo(b.time));
      }

      if (mounted) Navigator.pop(context); // Hide loading

      if (exportData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลในช่วงเวลาที่เลือก')),
          );
        }
        return;
      }

      await ExportService.exportToExcel(
        data: exportData,
        deviceId: exportDeviceId,
        context: context,
        deviceDisplayNames: _deviceDisplayNames,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการ Export: $e')),
        );
      }
    }
  }

  Future<void> _pickSpecificDate() async {
    final DateTimeRange? range = await showDialog<DateTimeRange>(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _kPrimary,
              primary: _kPrimary,
              onPrimary: Colors.white,
              surface: _kSurface,
              onSurface: _kTextDark,
            ),
          ),
          child: Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
              child: DateRangePickerDialog(
                initialDateRange: _selectedDateRange,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              ),
            ),
          ),
        );
      },
    );
    if (range == null) return;

    setState(() {
      _selectedDateRange = range;
      _useRangeMode = true;
    });

    await _fetchHistoryByRange(range);
  }

  void _openMobileSidebar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return _buildSidebarContent(scrollController: scrollController);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 950;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const TopBar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _kSurface,
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
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1B5E20), size: 18),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                Text(
                  'Sensor History',
                  style: GoogleFonts.inter(
                      color: _kTextDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
                const Spacer(),
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.tune_rounded,
                        color: Color(0xFF1B5E20)),
                    onPressed: _openMobileSidebar,
                    tooltip: 'Filters & Device',
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Color(0xFF1B5E20)),
                  onPressed: () => _fetchHistory(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _contentRefreshNotifier,
              builder: (context, _, __) {
                if (isMobile) {
                  return (_isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF2E7D32)))
                      : _buildMobileLayout());
                } else {
                  return _buildHistoryContent();
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: _openMobileSidebar,
              backgroundColor: _kPrimary,
              icon: const Icon(Icons.tune_rounded, color: Colors.white),
              label: Text(
                _deviceDisplayNames[_selectedDeviceId] ??
                    _selectedDeviceId ??
                    'Select Device',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            )
          : null,
    );
  }

  Widget _buildHistoryContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSidebar(),
        VerticalDivider(width: 1, color: Colors.grey.withOpacity(0.1)),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
              : _buildMainDataArea(),
        ),
      ],
    );
  }

  Widget _buildMainDataArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 4, child: _buildTableBody()),
          const SizedBox(width: 20),
          Expanded(flex: 5, child: _buildChartSection()),
        ],
      ),
    );
  }

  int _mobileTabIndex = 0;

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildMobileInfoBar(),
        Container(
          color: _kSurface,
          child: Row(
            children: [
              Expanded(child: _tabButton('Chart', Icons.show_chart_rounded, 0)),
              Expanded(child: _tabButton('Table', Icons.table_rows_rounded, 1)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _mobileTabIndex == 0
              ? _buildChartSection()
              : _buildTableBody(),
        ),
      ],
    );
  }

  Widget _tabButton(String label, IconData icon, int idx) {
    final bool active = _mobileTabIndex == idx;
    return InkWell(
      onTap: () => setState(() => _mobileTabIndex = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? _kPrimary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? _kPrimary : _kTextMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? _kPrimary : _kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileInfoBar() {
    final deviceName =
        _deviceDisplayNames[_selectedDeviceId] ?? _selectedDeviceId ?? 'No device';
    final now = DateTime.now();
    final isToday = _selectedDateRange != null &&
        _selectedDateRange!.start.day == now.day &&
        _selectedDateRange!.start.month == now.month;
    final dateStr = _selectedDateRange == null
        ? 'No date'
        : isToday
            ? 'Today'
            : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} – '
                '${DateFormat('dd/MM').format(_selectedDateRange!.end)}';

    return Container(
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.memory_rounded, size: 16, color: _kPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              deviceName,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.date_range_rounded, size: 16, color: _kTextMuted),
          const SizedBox(width: 4),
          Text(dateStr,
              style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
          const SizedBox(width: 8),
          Text('· $_selectedInterval',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _kPrimary,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    if (_filteredData.isEmpty) {
      return Center(
        child: Text('No history data to display graph',
            style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
      );
    }

    final type = _deviceType;
    List<ChartSeries> series = [];

    if (type == 'soil') {
      series = [
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.temperature
                    })
                .toList(),
            color: const Color(0xFFFF7043),
            label: 'Temp'),
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.soilMoisture
                    })
                .toList(),
            color: const Color(0xFF29B6F6),
            label: 'Moisture'),
        ChartSeries(
            data: _filteredData
                .map((s) =>
                    {'_time': s.time.toIso8601String(), '_value': s.ec})
                .toList(),
            color: const Color(0xFF66BB6A),
            label: 'EC',
            normalize: 0.1),
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.nitrogen
                    })
                .toList(),
            color: const Color(0xFF9CCC65),
            label: 'N',
            normalize: 10.0),
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.phosphorus
                    })
                .toList(),
            color: const Color(0xFFFFB74D),
            label: 'P',
            normalize: 10.0),
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.potassium
                    })
                .toList(),
            color: const Color(0xFFBA68C8),
            label: 'K',
            normalize: 10.0),
      ];
    } else if (type == 'mineral') {
      series = [
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.nitrogen
                    })
                .toList(),
            color: const Color(0xFF9CCC65),
            label: 'N',
            normalize: 10.0),
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.phosphorus
                    })
                .toList(),
            color: const Color(0xFFFFB74D),
            label: 'P',
            normalize: 10.0),
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.potassium
                    })
                .toList(),
            color: const Color(0xFFBA68C8),
            label: 'K',
            normalize: 10.0),
      ];
    } else {
      series = [
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.temperature
                    })
                .toList(),
            color: const Color(0xFFFF7043),
            label: 'Temp'),
        ChartSeries(
            data: _filteredData
                .map((s) => {
                      '_time': s.time.toIso8601String(),
                      '_value': s.humidity
                    })
                .toList(),
            color: const Color(0xFF29B6F6),
            label: 'Humid'),
        ChartSeries(
            data: _filteredData
                .map((s) =>
                    {'_time': s.time.toIso8601String(), '_value': s.eco2})
                .toList(),
            color: const Color(0xFF9575CD),
            label: 'CO2',
            normalize: 25.0),
      ];
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      color: _kSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_outlined, size: 18, color: _kPrimary),
                  const SizedBox(width: 8),
                  Text('Data Visualization',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary)),
                ],
              ),
              _buildChartLegend(type),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: MultiLineChart(
              series: series,
              height: 300,
              fixedMinY: type == 'environmental' ? 0 : null,
              fixedMaxY: type == 'environmental' ? 100 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String type) {
    if (type == 'soil') {
      return Wrap(spacing: 12, runSpacing: 4, children: [
        _legendItem(const Color(0xFFFF7043), 'Temp'),
        _legendItem(const Color(0xFF29B6F6), 'Moisture'),
        _legendItem(const Color(0xFF66BB6A), 'EC'),
        _legendItem(const Color(0xFF9CCC65), 'N'),
        _legendItem(const Color(0xFFFFB74D), 'P'),
        _legendItem(const Color(0xFFBA68C8), 'K'),
      ]);
    } else if (type == 'mineral') {
      return Wrap(spacing: 12, runSpacing: 4, children: [
        _legendItem(const Color(0xFF9CCC65), 'N'),
        _legendItem(const Color(0xFFFFB74D), 'P'),
        _legendItem(const Color(0xFFBA68C8), 'K'),
      ]);
    } else {
      return Wrap(spacing: 12, runSpacing: 4, children: [
        _legendItem(const Color(0xFFFF7043), 'Temp (°C)'),
        _legendItem(const Color(0xFF29B6F6), '(%) RH'),
        _legendItem(const Color(0xFF9575CD), 'CO2 (ppm)'),
      ]);
    }
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: _kTextMuted,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: _buildSidebarContent(),
    );
  }

  Widget _buildSidebarContent({ScrollController? scrollController}) {
    final dropdownItems = _deviceIds.isNotEmpty
        ? _deviceIds
        : (widget.initialDeviceId != null
            ? [widget.initialDeviceId!]
            : <String>[]);

    return SingleChildScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scrollController != null)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            if (scrollController != null) ...[
              Row(
                children: [
                  Icon(Icons.tune_rounded, color: _kPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text('Filters & Selection',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _kPrimary)),
                ],
              ),
              const Divider(height: 20),
            ],

            Text('Board Selection',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _kTextMuted)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kPrimary.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: dropdownItems.contains(_selectedDeviceId)
                      ? _selectedDeviceId
                      : (dropdownItems.isNotEmpty ? dropdownItems.first : null),
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: _kPrimary),
                  style: GoogleFonts.inter(
                      color: _kPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  items: dropdownItems
                      .map((id) => DropdownMenuItem(
                            value: id,
                            child: Text(_deviceDisplayNames[id] ?? id,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedDeviceId = v);
                    _fetchHistoryByRange(_selectedDateRange!);
                    if (scrollController != null && Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text('Period',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _kTextMuted)),
            const SizedBox(height: 8),
            _buildPeriodDropdown(closeSheet: scrollController != null),
            const SizedBox(height: 8),
            if (_selectedDateRange != null) _buildActiveRangeInfo(),

            const SizedBox(height: 24),

            Text('Interval',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _kTextMuted)),
            const SizedBox(height: 8),
            _buildIntervalChipVertical('1m',
                closeSheet: scrollController != null),
            _buildIntervalChipVertical('5m',
                closeSheet: scrollController != null),
            _buildIntervalChipVertical('10m',
                closeSheet: scrollController != null),
            _buildIntervalChipVertical('25m',
                closeSheet: scrollController != null),
            _buildIntervalChipVertical('60m',
                closeSheet: scrollController != null),

            const Divider(height: 32),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  _exportToExcel();
                  if (scrollController != null && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.file_download_rounded,
                    color: Colors.white),
                label: const Text('Export Excel',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalChipVertical(String interval,
      {bool closeSheet = false}) {
    final bool isSelected = _selectedInterval == interval;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() => _selectedInterval = interval);
          _fetchHistoryByRange(_selectedDateRange!);
          if (closeSheet && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? _kPrimary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected ? _kPrimary : Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: isSelected ? _kPrimary : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(interval,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? _kPrimary : _kTextDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodDropdown({bool closeSheet = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7 = today.subtract(const Duration(days: 7));
    final last30 = today.subtract(const Duration(days: 30));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: null,
          hint: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 20, color: _kPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Select Date Range',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _kTextDark,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
          items: const [
            DropdownMenuItem(value: 'today', child: Text('today')),
            DropdownMenuItem(value: 'yesterday', child: Text('1 day')),
            DropdownMenuItem(value: 'last7', child: Text('7 day')),
            DropdownMenuItem(value: 'last30', child: Text('30 day')),
            DropdownMenuItem(
              value: 'custom',
              child: Row(
                children: [
                  Icon(Icons.edit_calendar_rounded,
                      size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Custom Range...',
                      style: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          onChanged: (val) async {
            if (val == null) return;

            if (val == 'custom') {
              if (closeSheet && Navigator.canPop(context)) Navigator.pop(context);
              await _pickSpecificDate();
              return;
            }

            DateTimeRange? target;
            if (val == 'today') {
              target = DateTimeRange(
                  start: today,
                  end: DateTime(today.year, today.month, today.day, 23, 59, 59));
            } else if (val == 'yesterday') {
              target = DateTimeRange(
                  start: yesterday,
                  end: DateTime(
                      yesterday.year, yesterday.month, yesterday.day, 23, 59, 59));
            } else if (val == 'last7') {
              target = DateTimeRange(
                  start: last7,
                  end: DateTime(today.year, today.month, today.day, 23, 59, 59));
            } else if (val == 'last30') {
              target = DateTimeRange(
                  start: last30,
                  end: DateTime(today.year, today.month, today.day, 23, 59, 59));
            }

            if (target != null) {
              setState(() {
                _selectedDateRange = target;
                _useRangeMode = val != 'today';
              });
              _fetchHistoryByRange(target);
            }

            if (closeSheet && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildActiveRangeInfo() {
    final isToday =
        _selectedDateRange!.start.year == DateTime.now().year &&
            _selectedDateRange!.start.month == DateTime.now().month &&
            _selectedDateRange!.start.day == DateTime.now().day &&
            _selectedDateRange!.end.day == DateTime.now().day;

    final String dateStr = isToday
        ? 'Today: ${DateFormat('dd MMMM yyyy').format(_selectedDateRange!.start)}'
        : 'Range: ${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - '
            '${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isToday ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isToday ? Colors.green.shade100 : Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Icon(
            isToday ? Icons.today_rounded : Icons.date_range_rounded,
            size: 16,
            color: isToday ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dateStr,
              style: TextStyle(
                fontSize: 11,
                color: isToday ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!isToday)
            InkWell(
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _selectedDateRange = DateTimeRange(
                    start: DateTime(now.year, now.month, now.day),
                    end: DateTime(now.year, now.month, now.day, 23, 59, 59),
                  );
                  _useRangeMode = false;
                });
                _fetchHistoryByRange(_selectedDateRange!);
              },
              child: const Icon(Icons.close, size: 18, color: Colors.orange),
            ),
        ],
      ),
    );
  }

  int _currentPage = 0;
  static const int _rowsPerPage = 15;

  Widget _buildTableBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
              if (_errorRawData != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8)),
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: SelectableText(_errorRawData!,
                        style: GoogleFonts.robotoMono(
                            fontSize: 11, color: Colors.blueGrey)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _fetchHistory(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredData.isEmpty) {
      return Center(
          child: Text('No history found',
              style: TextStyle(color: _kTextDark)));
    }

    final reversed = _filteredData.reversed.toList();
    final totalPages = (reversed.length / _rowsPerPage).ceil();
    final page = _currentPage.clamp(0, totalPages - 1);
    final start = page * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, reversed.length);
    final pageData = reversed.sublist(start, end);

    final type = _deviceType;
    final headers = _tableHeaders(type);

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.table_rows_rounded, size: 16, color: _kPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'History Data (${_selectedDeviceId ?? "All"})',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _kTextDark),
                  ),
                ),
                Text('${reversed.length} rows',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _kTextMuted)),
              ],
            ),
          ),
          const Divider(height: 1),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildHeaderRow(headers),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: _tableMinWidth(type),
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: pageData.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.withOpacity(0.08)),
                  itemBuilder: (_, i) {
                    final s = pageData[i];
                    final cells = _buildCells(s, type);
                    final bool odd = i.isOdd;
                    return Container(
                      color: odd
                          ? Colors.transparent
                          : _kPrimary.withOpacity(0.03),
                      child: Row(
                        children: List.generate(cells.length, (ci) {
                          return SizedBox(
                            width: _colWidth(ci, headers.length),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              child: Text(cells[ci],
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: _kTextDark)),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${page + 1} / $totalPages  (${start + 1}–$end of ${reversed.length})',
                  style:
                      GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page_rounded),
                      iconSize: 20,
                      color: page > 0 ? _kPrimary : Colors.grey,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: page > 0
                          ? () => setState(() => _currentPage = 0)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      iconSize: 20,
                      color: page > 0 ? _kPrimary : Colors.grey,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: page > 0
                          ? () => setState(() => _currentPage = page - 1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      iconSize: 20,
                      color:
                          page < totalPages - 1 ? _kPrimary : Colors.grey,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: page < totalPages - 1
                          ? () => setState(() => _currentPage = page + 1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page_rounded),
                      iconSize: 20,
                      color:
                          page < totalPages - 1 ? _kPrimary : Colors.grey,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: page < totalPages - 1
                          ? () =>
                              setState(() => _currentPage = totalPages - 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _tableHeaders(String type) {
    if (type == 'soil') return ['Time', 'RH (%)', 'EC'];
    if (type == 'mineral') return ['Time', 'N', 'P', 'K', 'EC'];
    return ['Time', 'Temp', 'Humid', 'CO2 (ppm)', 'Lights'];
  }

  double _tableMinWidth(String type) {
    if (type == 'soil') return 320;
    if (type == 'mineral') return 420;
    return 460;
  }

  double _colWidth(int colIndex, int totalCols) {
    if (colIndex == 0) return 100;
    return 80;
  }

  Widget _buildHeaderRow(List<String> headers) {
    return Container(
      color: _kPrimary.withOpacity(0.06),
      child: Row(
        children: List.generate(headers.length, (i) {
          return SizedBox(
            width: _colWidth(i, headers.length),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Text(headers[i],
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _kPrimary)),
            ),
          );
        }),
      ),
    );
  }

  List<String> _buildCells(SensorSnapshot s, String type) {
    final time = '${DateFormat('dd/MM HH:mm').format(s.time)} (UTC+7)';
    if (type == 'soil') {
      return [
        time,
        '${(s.humidity != 0.0 ? s.humidity : s.soilMoisture).toStringAsFixed(1)}%',
        s.ec.toStringAsFixed(2),
      ];
    } else if (type == 'mineral') {
      return [
        time,
        s.nitrogen.toStringAsFixed(1),
        s.phosphorus.toStringAsFixed(1),
        s.potassium.toStringAsFixed(1),
        s.ec.toStringAsFixed(2),
      ];
    } else {
      return [
        time,
        '${s.temperature.toStringAsFixed(1)}°C',
        '${s.humidity.toStringAsFixed(1)}%',
        '${s.eco2} ppm',
        s.lightOn ? 'ON' : 'OFF',
      ];
    }
  }
} // end of _HistoryViewPageState

// ─── Background isolate parser ────────────────────────────────────────────────
Map<String, dynamic> _parseHistoryInBackground(
    Map<String, dynamic> params) {
  final String body = params['body'];
  final String? selectedDeviceId = params['selectedDeviceId'];

  final decoded = jsonDecode(body);
  final List<SensorSnapshot> parsed = [];
  final Set<String> foundDeviceIds = {};

  dynamic payload = (decoded is Map)
      ? (decoded['data'] ??
          decoded['readings'] ??
          decoded['history'] ??
          decoded)
      : decoded;

  if (payload is List) {
    for (final item in payload) {
      if (item is Map) {
        final dId =
            item['device_id']?.toString() ?? item['id']?.toString();
        if (dId != null && dId.isNotEmpty) foundDeviceIds.add(dId);

        final targetKey = selectedDeviceId?.toLowerCase();
        if (targetKey == null ||
            (dId != null && dId.toLowerCase() == targetKey)) {
          parsed.add(SensorSnapshot.fromJson(
              Map<String, dynamic>.from(item)));
        }
      }
    }
  } else if (payload is Map) {
    payload.forEach((key, value) {
      final dId = key.toString();
      if (dId == 'status' || dId == 'message' || dId == 'count') return;

      final dynamic readings = value is Map
          ? (value['data'] ?? value['readings'] ?? value['history'])
          : value;

      if (readings is List) {
        foundDeviceIds.add(dId);
        final targetKey = selectedDeviceId?.toLowerCase();
        if (targetKey == null || dId.toLowerCase() == targetKey) {
          for (final r in readings) {
            if (r is Map) {
              parsed.add(SensorSnapshot.fromJson(
                  Map<String, dynamic>.from(r)));
            }
          }
        }
      }
    });
  }

  parsed.sort((a, b) => a.time.compareTo(b.time));

  return {
    'parsed': parsed,
    'foundDeviceIds': foundDeviceIds,
  };
}