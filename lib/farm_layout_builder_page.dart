import 'dashboard_page.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'services/layout_api_service.dart';
import 'services/auth_service.dart';
import 'widgets/top_bar.dart';

enum BoardStatus { online, offline, alert }

const String _kDeviceBaseUrl = 'http://100.70.171.1:5000';

enum EditMode { none, zones, boards }

// ---------------------------------------------------------------------------
// ZoneData — เพิ่ม width, height สำหรับกำหนดขนาดโซน
// ---------------------------------------------------------------------------
class ZoneData {
  String id;
  String name;
  int row;
  int col;
  String? imagePath; // base64 string หรือ URL
  double width;
  double height;

  ZoneData({
    required this.id,
    required this.name,
    required this.row,
    required this.col,
    this.imagePath,
    this.width = 350.0,
    this.height = 350.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'row': row,
        'col': col,
        'image_path': imagePath,
        'width': width,
        'height': height,
      };

  factory ZoneData.fromJson(Map<String, dynamic> json) => ZoneData(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        row: json['row'] ?? 0,
        col: json['col'] ?? 0,
        imagePath: json['image_path'],
        width: (json['width'] as num?)?.toDouble() ?? 350.0,
        height: (json['height'] as num?)?.toDouble() ?? 350.0,
      );
}

// ---------------------------------------------------------------------------
// BoardData
// ---------------------------------------------------------------------------
class BoardData {
  String id;
  String deviceId;
  String zoneId;
  String displayName;
  double x;
  double y;

  BoardData({
    required this.id,
    required this.deviceId,
    required this.zoneId,
    this.displayName = '',
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'zone_id': zoneId,
        'display_name': displayName,
        'x': x,
        'y': y,
      };

  factory BoardData.fromJson(Map<String, dynamic> json) => BoardData(
        id: json['id'] ?? '',
        deviceId: json['device_id'] ?? '',
        zoneId: json['zone_id'] ?? '',
        displayName: json['display_name'] ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 50.0,
        y: (json['y'] as num?)?.toDouble() ?? 50.0,
      );
}

// ---------------------------------------------------------------------------
// FarmLayoutBuilderPage
// ---------------------------------------------------------------------------
class FarmLayoutBuilderPage extends StatefulWidget {
  const FarmLayoutBuilderPage({Key? key}) : super(key: key);

  @override
  State<FarmLayoutBuilderPage> createState() => _FarmLayoutBuilderPageState();
}

class _FarmLayoutBuilderPageState extends State<FarmLayoutBuilderPage> {
  final LayoutApiService _layoutApi = LayoutApiService();
  final bool _isAdmin = AuthService().currentRole == 'admin';

  // Theme helpers
  Color get _kBgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _kSurface => Theme.of(context).cardColor;
  Color get _kTextDark => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFE0E0E0)
      : const Color(0xFF1A2E1A);
  Color get _kTextMuted => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA0A0A0)
      : const Color(0xFF6B8068);
  Color get _kGreen700 => const Color(0xFF2E7D32);

  List<ZoneData> _zones = [];
  List<BoardData> _boards = [];
  List<String> _availableDevices = [];
  bool _isLoading = true;
  EditMode _editMode = EditMode.none;
  String _searchQuery = '';
  final ValueNotifier<int> _contentRefreshNotifier = ValueNotifier(0);

  Timer? _statusTimer;
  final Map<String, BoardStatus> _deviceStatus = {};
  final Map<String, String> _deviceStatusDetail = {};
  final Map<String, String> _deviceDisplayNames = {};
  final Set<String> _alarmedDevices = {};
  final Map<String, List<String>> _alarmDetails = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _statusTimer = Timer.periodic(
        const Duration(seconds: 45), (_) => _fetchAllDeviceStatuses());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Data fetching
  // -------------------------------------------------------------------------
  Future<void> _fetchInitialData() async {
    _isLoading = true;
    _contentRefreshNotifier.value++;
    
    // 1. Fetch registered devices from api/devices
    try {
      final response = await http.get(Uri.parse('$_kDeviceBaseUrl/api/devices')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<String> registry = [];
        if (decoded is Map) {
          registry = decoded.keys.map((k) => k.toString()).toList();
        } else if (decoded is List) {
          for (var item in decoded) {
            if (item is String) {
              registry.add(item);
            } else if (item is Map && item.containsKey('id')) {
              registry.add(item['id'].toString());
            } else if (item is Map && item.containsKey('device_id')) {
              registry.add(item['device_id'].toString());
            }
          }
        }
        _availableDevices = registry;
      }
    } catch (e) {
      debugPrint('[FetchAvailableDevices] Error: $e');
    }

    // 2. Fetch Layout
    final layout = await _layoutApi.fetchLayout();

    List<ZoneData> fetchedZones = [];
    List<BoardData> fetchedBoards = [];

    if (layout.isNotEmpty) {
      if (layout['zones'] is List) {
        fetchedZones = (layout['zones'] as List)
            .map((e) => ZoneData.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (layout['boards'] is List) {
        fetchedBoards = (layout['boards'] as List)
            .map((e) => BoardData.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (layout['deviceDisplayNames'] != null) {
        final raw = Map<String, dynamic>.from(layout['deviceDisplayNames']);
        raw.forEach((k, v) => _deviceDisplayNames[k] = v.toString());
      }
    }

    if (fetchedZones.isEmpty) {
      fetchedZones = [ZoneData(id: 'z1', name: 'Zone 1', row: 0, col: 0)];
    }

    _zones = fetchedZones;
    _boards = fetchedBoards;
    _isLoading = false;
    _contentRefreshNotifier.value++;
    _fetchAllDeviceStatuses();
  }

  Future<void> _fetchAllDeviceStatuses() async {
    await _fetchActiveAlarms();
    if (_boards.isNotEmpty) {
      await Future.wait(_boards.map((b) => _fetchDeviceStatus(b.deviceId)));
    }
  }

  Future<void> _fetchActiveAlarms() async {
    try {
      final res = await http
          .get(Uri.parse('$_kDeviceBaseUrl/api/alarms/active'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List decoded = jsonDecode(res.body);
        final newAlarmed = <String>{};
        final newDetails = <String, List<String>>{};
        for (final item in decoded) {
          final dId = (item['device_id'] ?? '').toString();
          if (dId.isEmpty) continue;
          newAlarmed.add(dId);
          final detail =
              '${_formatAlertType(item['alert_type'] ?? '')}: ${item['value']} (เกิน ${item['threshold']}) · ${item['time_elapsed'] ?? ''}';
          newDetails.putIfAbsent(dId, () => []).add(detail);
        }
        if (mounted) {
          setState(() {
            _alarmedDevices..clear()..addAll(newAlarmed);
            _alarmDetails..clear()..addAll(newDetails);
          });
        }
      }
    } catch (e) {
      debugPrint('[ActiveAlarms] Error: $e');
    }
  }

  String _formatAlertType(String type) {
    const map = {
      'tvoc_high': '🌫️ TVOC สูง',
      'eco2_high': '💨 eCO2 สูง',
      'temperature_high': '🌡️ อุณหภูมิสูง',
      'temperature_low': '🌡️ อุณหภูมิต่ำ',
      'humidity_high': '💧 ความชื้นสูง',
      'humidity_low': '💧 ความชื้นต่ำ',
      'co2_high': '💨 CO2 สูง',
      'ec_high': '⚡ ค่า EC สูง',
      'moisture_low': '🌱 ความชื้นดินต่ำ',
      'nitrogen_low': '🔬 N ต่ำ',
      'phosphorus_low': '🔬 P ต่ำ',
      'potassium_low': '🔬 K ต่ำ',
    };
    return map[type] ?? '⚠️ $type';
  }

  Future<void> _fetchDeviceStatus(String deviceId) async {
    final regId = _availableDevices.firstWhere(
        (id) => id.toLowerCase() == deviceId.toLowerCase(),
        orElse: () => '');
    if (regId.isEmpty) {
      if (mounted) setState(() {
        _deviceStatus[deviceId] = BoardStatus.offline;
        _deviceStatusDetail[deviceId] = 'ออฟไลน์ (ไม่พบรหัสในสารบบ)';
      });
      return;
    }
    try {
      final res = await http
          .get(Uri.parse('$_kDeviceBaseUrl/api/devices/$deviceId/latest'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        if (mounted) setState(() {
          _deviceStatus[deviceId] = BoardStatus.offline;
          _deviceStatusDetail[deviceId] = 'ออฟไลน์ (${res.statusCode})';
        });
        return;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json.containsKey('reading')
          ? (json['reading'] as Map<String, dynamic>? ?? {})
          : json;
      final temp = (data['temperature'] as num?)?.toDouble() ?? 0.0;
      final ec = (data['ec'] as num?)?.toDouble() ?? 0.0;
      final moist = (data['moisture'] as num?)?.toDouble() ?? 0.0;
      final n = (data['nitrogen'] as num?)?.toDouble() ?? 0.0;

      DateTime? timestamp;
      final rawTs = (json['timestamp'] ?? json['time'] ?? '').toString();
      if (rawTs.isNotEmpty) {
        timestamp = DateTime.tryParse(rawTs);
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toLocal()).inMinutes;
          if (diff > 30) {
            if (mounted) setState(() {
              _deviceStatus[deviceId] = BoardStatus.offline;
              _deviceStatusDetail[deviceId] =
                  'ออฟไลน์ (ไม่อัปเดต $diff นาที)';
            });
            return;
          }
        }
      }

      List<String> alerts = [];
      final idLower = deviceId.toLowerCase();
      if (idLower.contains('soil')) {
        if (ec > 3.0) alerts.add('EC สูง ($ec)');
        if (moist < 10) alerts.add('ความชื้นดินต่ำ ($moist%)');
      } else if (idLower.contains('min') || idLower.contains('nitro')) {
        if (n < 5) alerts.add('ไนโตรเจนต่ำ ($n)');
      } else {
        if (temp > 42) alerts.add('อุณหภูมิสูง ($temp°C)');
        if (temp < 10 && temp > 0) alerts.add('อุณหภูมิต่ำ ($temp°C)');
      }

      if (mounted) setState(() {
        final timeStr = timestamp != null
            ? '${timestamp.toLocal().hour.toString().padLeft(2, '0')}:${timestamp.toLocal().minute.toString().padLeft(2, '0')}'
            : 'เมื่อสักครู่';
        _deviceStatus[deviceId] = BoardStatus.online;
        _deviceStatusDetail[deviceId] = '✅ เชื่อมต่อปกติ\nอัปเดต: $timeStr';
      });
    } catch (e) {
      if (mounted) setState(() {
        _deviceStatus[deviceId] = BoardStatus.offline;
        _deviceStatusDetail[deviceId] = 'ออฟไลน์ (เชื่อมต่อไม่สำเร็จ)';
      });
    }
  }

  // -------------------------------------------------------------------------
  // Save
  // -------------------------------------------------------------------------
  Future<void> _saveLayout() async {
    setState(() => _isLoading = true);
    final payload = {
      'zones': _zones.map((z) => z.toJson()).toList(),
      'boards': _boards.map((b) => b.toJson()).toList(),
      'deviceDisplayNames': _deviceDisplayNames,
    };
    debugPrint('[SaveLayout] zones: ${_zones.length}');
    final success = await _layoutApi.saveLayout(payload);
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'บันทึก Layout เรียบร้อยแล้ว' : 'เกิดข้อผิดพลาดในการบันทึก'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  // -------------------------------------------------------------------------
  // Zone management
  // -------------------------------------------------------------------------
  void _addZone(int r, int c) {
    final ctrl = TextEditingController(text: 'Zone ${_zones.length + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ตั้งชื่อโซนใหม่'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ชื่อโซน...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _zones.add(ZoneData(
                  id: 'z_${DateTime.now().millisecondsSinceEpoch}',
                  name: ctrl.text.trim().isEmpty
                      ? 'Zone ${_zones.length + 1}'
                      : ctrl.text.trim(),
                  row: r,
                  col: c,
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('เพิ่มโซน'),
          ),
        ],
      ),
    );
  }

  void _deleteZone(ZoneData zone) {
    if (_zones.length <= 1) return;
    _boards.removeWhere((b) => b.zoneId == zone.id);
    setState(() => _zones.removeWhere((z) => z.id == zone.id));
  }

  /// Dialog แก้ชื่อ + รูปพื้นหลัง + ขนาดโซน
  void _editZoneName(ZoneData zone) {
    final nameCtrl = TextEditingController(text: zone.name);
    final widthCtrl = TextEditingController(text: zone.width.toInt().toString());
    final heightCtrl = TextEditingController(text: zone.height.toInt().toString());
    String? currentImagePath = zone.imagePath;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: _kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('จัดการโซน',
              style: GoogleFonts.inter(color: _kTextDark, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ชื่อโซน ──────────────────────────────────────────
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: TextStyle(color: _kTextDark),
                  decoration: InputDecoration(
                    labelText: 'ชื่อโซน',
                    labelStyle: TextStyle(color: _kTextMuted),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _kGreen700)),
                    filled: true,
                    fillColor: _kBgColor,
                  ),
                ),
                const SizedBox(height: 16),

                // ── ขนาดโซน ──────────────────────────────────────────
                Text('ขนาดโซน',
                    style: GoogleFonts.inter(
                        color: _kTextMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widthCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: _kTextDark),
                        decoration: InputDecoration(
                          labelText: 'กว้าง (px)',
                          labelStyle: TextStyle(color: _kTextMuted),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black12)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _kGreen700)),
                          filled: true,
                          fillColor: _kBgColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: heightCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: _kTextDark),
                        decoration: InputDecoration(
                          labelText: 'สูง (px)',
                          labelStyle: TextStyle(color: _kTextMuted),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black12)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _kGreen700)),
                          filled: true,
                          fillColor: _kBgColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── รูปพื้นหลัง ───────────────────────────────────────
                Text('รูปภาพพื้นหลังโซน',
                    style: GoogleFonts.inter(
                        color: _kTextMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _kTextMuted.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kTextMuted.withOpacity(0.1)),
                    ),
                    child: currentImagePath != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildImageWidget(currentImagePath!, fit: BoxFit.cover),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setModalState(() => currentImagePath = null),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                        color: Colors.red, shape: BoxShape.circle),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Icon(Icons.image_outlined,
                                color: _kTextMuted.withOpacity(0.3), size: 48)),
                  ),
                ),
                const SizedBox(height: 12),
                if (isUploading)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true, // ต้องการ bytes สำหรับ base64
                        );
                        if (result != null &&
                            result.files.single.bytes != null) {
                          setModalState(() => isUploading = true);
                          final bytes = result.files.single.bytes!;
                          
                          // ดึงขนาดกว้าง/สูงของรูปมาใส่ในช่องกรอกอัตโนมัติ
                          final image = await decodeImageFromList(bytes);
                          widthCtrl.text = image.width.toString();
                          heightCtrl.text = image.height.toString();

                          // อัปโหลดไฟล์ไปยัง Server แทนการเก็บ base64
                          final fileName = result.files.single.name;
                          final uploadedPath = await _layoutApi.uploadImage(bytes, fileName);

                          setModalState(() {
                            isUploading = false;
                            if (uploadedPath != null) {
                              currentImagePath = uploadedPath;
                            } else {
                              // ถ้าอัปโหลดไม่สำเร็จ แจ้งเตือนผู้ใช้
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('อัปโหลดรูปภาพไม่สำเร็จ')),
                              );
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('เลือกรูปภาพจากเครื่อง'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGreen700,
                        side: BorderSide(color: _kGreen700.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('ยกเลิก', style: TextStyle(color: _kTextMuted)),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () {
                      final w = (double.tryParse(widthCtrl.text) ?? zone.width)
                          .clamp(200.0, 3000.0);
                      final h = (double.tryParse(heightCtrl.text) ?? zone.height)
                          .clamp(200.0, 3000.0);
                      setState(() {
                        zone.name = nameCtrl.text.trim().isEmpty
                            ? zone.name
                            : nameCtrl.text.trim();
                        zone.imagePath = currentImagePath;
                        zone.width = w;
                        zone.height = h;
                      });
                      Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('ตกลง',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Board management
  // -------------------------------------------------------------------------
  void _showAddBoardDialog(String dId) {
    if (_zones.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('เพิ่ม $dId ไปยังโซนไหน?'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _zones
                  .map((z) => ListTile(
                        leading: const Icon(Icons.grid_view_rounded,
                            color: Color(0xFF2E7D32)),
                        title: Text(z.name),
                        subtitle: Text('Row: ${z.row}, Col: ${z.col}'),
                        onTap: () {
                          setState(() {
                            _boards.add(BoardData(
                              id: 'b_${DateTime.now().millisecondsSinceEpoch}',
                              deviceId: dId,
                              zoneId: z.id,
                              x: z.width / 2 - 24,
                              y: z.height / 2 - 24,
                            ));
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('เพิ่ม $dId ไปยัง ${z.name} เรียบร้อยแล้ว'),
                            behavior: SnackBarBehavior.floating,
                            width: 300,
                          ));
                        },
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก')),
        ],
      ),
    );
  }

  void _showFullBoardPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (sCtx, setModalState) {
          final filtered = _availableDevices
              .where((dId) => !_boards.any((b) => b.deviceId == dId))
              .where((dId) =>
                  dId.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('เลือกบอร์ดที่ต้องการเพิ่ม',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15)),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาชื่อบอร์ด...',
                      hintStyle: TextStyle(color: Colors.white24),
                      prefixIcon: Icon(Icons.search, color: Colors.white24),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                      setModalState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('ไม่พบบอร์ด...',
                              style: TextStyle(color: Colors.white24)))
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final dId = filtered[i];
                            return InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                _showAddBoardDialog(dId);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _statusDot(dId),
                                    const SizedBox(width: 8),
                                    Flexible(
                                        child: Text(dId,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _editBoardName(BoardData b) {
    final ctrl = TextEditingController(text: b.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ตั้งชื่อเล่นอุปกรณ์'),
            Text('รหัสเดิม: ${b.deviceId}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'กรอกชื่อเรียกที่ต้องการ...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () {
                setState(() => b.displayName = ctrl.text);
                Navigator.pop(ctx);
              },
              child: const Text('ตกลง')),
        ],
      ),
    );
  }

  void _removeBoard(BoardData b) =>
      setState(() => _boards.removeWhere((board) => board.id == b.id));

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: _kBgColor,
      body: Column(
        children: [
          TopBar(
            actions: [
              IconButton(
                onPressed: _fetchInitialData,
                icon: Icon(Icons.refresh_rounded, color: _kGreen700, size: 24),
                tooltip: 'รีเฟรชข้อมูล',
              ),
            ],
          ),
          // Sub-header for Layout Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _kSurface,
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const DashboardPage()),
                        (route) => false,
                      );
                    }
                  },
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: _kGreen700, size: 18),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                Text(
                  'Farm Layout Builder',
                  style: GoogleFonts.inter(
                    color: _kTextDark,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
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
                  return Column(
                    children: [
                      Expanded(child: _buildCanvasWithLoading()),
                      if (_isAdmin) _buildMobileToolbox(),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isAdmin) _buildToolbox(),
                      Expanded(child: _buildCanvasWithLoading()),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasWithLoading() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
    }
    return _buildCanvas();
  }

  // -------------------------------------------------------------------------
  // Canvas — ใช้ zone.width / zone.height แทน _zoneSize fixed
  // -------------------------------------------------------------------------
  Widget _buildCanvas() {
    if (_zones.isEmpty) return const SizedBox();

    int rMin = _zones.map((z) => z.row).reduce(min);
    int rMax = _zones.map((z) => z.row).reduce(max);
    int cMin = _zones.map((z) => z.col).reduce(min);
    int cMax = _zones.map((z) => z.col).reduce(max);

    // Ghost zones (ปรากฏเฉพาะ EditMode.zones)
    List<Map<String, int>> ghostZones = [];
    if (_editMode == EditMode.zones) {
      for (var z in _zones) {
        for (var n in [
          {'r': z.row - 1, 'c': z.col},
          {'r': z.row + 1, 'c': z.col},
          {'r': z.row, 'c': z.col - 1},
          {'r': z.row, 'c': z.col + 1},
        ]) {
          final exists = _zones.any((oz) => oz.row == n['r'] && oz.col == n['c']);
          if (!exists && !ghostZones.any((g) => g['r'] == n['r'] && g['c'] == n['c'])) {
            ghostZones.add(n);
          }
        }
      }
      for (var g in ghostZones) {
        rMin = min(rMin, g['r']!);
        rMax = max(rMax, g['r']!);
        cMin = min(cMin, g['c']!);
        cMax = max(cMax, g['c']!);
      }
    }

    // คำนวณขนาด canvas จากขนาดโซนจริง (ใช้ขนาดสูงสุดต่อแถว/คอลัมน์)
    // สร้าง map row→maxHeight, col→maxWidth
    final Map<int, double> rowHeight = {};
    final Map<int, double> colWidth = {};
    for (var z in _zones) {
      rowHeight[z.row] = max(rowHeight[z.row] ?? 0, z.height);
      colWidth[z.col] = max(colWidth[z.col] ?? 0, z.width);
    }
    // default สำหรับ ghost
    for (var g in ghostZones) {
      rowHeight[g['r']!] ??= 350.0;
      colWidth[g['c']!] ??= 350.0;
    }

    // offset สะสม
    double totalWidth = 0;
    double totalHeight = 0;
    final Map<int, double> colOffset = {};
    final Map<int, double> rowOffset = {};

    double xAcc = 0;
    for (int c = cMin; c <= cMax; c++) {
      colOffset[c] = xAcc;
      xAcc += colWidth[c] ?? 350.0;
    }
    totalWidth = xAcc;

    double yAcc = 0;
    for (int r = rMin; r <= rMax; r++) {
      rowOffset[r] = yAcc;
      yAcc += rowHeight[r] ?? 350.0;
    }
    totalHeight = yAcc;

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(3000),
      minScale: 0.1,
      maxScale: 2.5,
      panEnabled: _editMode != EditMode.boards,
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(
          children: [
            // Actual zones
            ..._zones.map((zone) {
              final double left = colOffset[zone.col] ?? 0;
              final double top = rowOffset[zone.row] ?? 0;
              final zoneBoards =
                  _boards.where((b) => b.zoneId == zone.id).toList();

              return Positioned(
                left: left,
                top: top,
                width: zone.width,
                height: zone.height,
                child: Builder(
                  builder: (zoneCtx) => DragTarget<Object>(
                    onAcceptWithDetails: (details) {
                      final data = details.data;
                      final RenderBox box =
                          zoneCtx.findRenderObject() as RenderBox;
                      final localPos = box.globalToLocal(details.offset);
                      final dropX = localPos.dx - 24;
                      final dropY = localPos.dy - 24;
                      setState(() {
                        if (data is String) {
                          _boards.add(BoardData(
                            id: 'b_${DateTime.now().millisecondsSinceEpoch}',
                            deviceId: data,
                            zoneId: zone.id,
                            x: dropX,
                            y: dropY,
                          ));
                        } else if (data is BoardData) {
                          data.zoneId = zone.id;
                          data.x = dropX;
                          data.y = dropY;
                        }
                      });
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        decoration: BoxDecoration(
                          color: zone.imagePath != null
                              ? Colors.transparent
                              : _kSurface.withOpacity(0.95),
                          border: Border.all(
                              color: _kTextMuted.withOpacity(0.2)),
                        ),
                        child: Stack(
                          children: [
                            // Background image (base64 หรือ URL)
                            if (zone.imagePath != null)
                              Positioned.fill(
                                child: _buildImageWidget(zone.imagePath!,
                                    fit: BoxFit.cover),
                              ),
                            // Grid overlay
                            Positioned.fill(
                                child: CustomPaint(
                                    painter: GridPainter(context))),
                            // Zone name watermark
                            Center(
                              child: Text(
                                zone.name,
                                style: GoogleFonts.inter(
                                  color: _kTextMuted.withOpacity(0.25),
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Edit/Delete buttons
                            if (_editMode == EditMode.zones) ...[
                              Positioned(
                                top: 10,
                                right: 10,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_forever,
                                      color: Colors.redAccent),
                                  onPressed: () => _deleteZone(zone),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _kGreen700.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit_note,
                                        color: Colors.white, size: 20),
                                    onPressed: () => _editZoneName(zone),
                                  ),
                                ),
                              ),
                              // แสดงขนาดปัจจุบัน
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${zone.width.toInt()} × ${zone.height.toInt()} px',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                            // Boards
                            ...zoneBoards.map((b) => Positioned(
                                  left: b.x - 8,
                                  top: b.y - 8,
                                  child: _buildDraggableBoard(b),
                                )),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            }),

            // Ghost zones
            ...ghostZones.map((g) {
              final double left = colOffset[g['c']!] ?? 0;
              final double top = rowOffset[g['r']!] ?? 0;
              final double w = colWidth[g['c']!] ?? 350.0;
              final double h = rowHeight[g['r']!] ?? 350.0;
              return Positioned(
                left: left,
                top: top,
                width: w,
                height: h,
                child: GestureDetector(
                  onTap: () => _addZone(g['r']!, g['c']!),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.add, color: Colors.green),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Toolbox (desktop)
  // -------------------------------------------------------------------------
  Widget _buildToolbox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141614) : const Color(0xFFE8EAE8),
        border: Border(
            right: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12, width: 1.5)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _modeButton(EditMode.zones, 'จัดการโซน', Icons.grid_view),
                  const SizedBox(height: 10),
                  _modeButton(EditMode.boards, 'จัดการเซนเซอร์', Icons.sensors),
                  const Divider(color: Colors.white10, height: 32),
                  if (_editMode == EditMode.boards) ...[
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          color: _kTextMuted.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        style: TextStyle(color: _kTextDark, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาชื่อบอร์ด...',
                          hintStyle: TextStyle(
                              color: _kTextMuted.withOpacity(0.5), fontSize: 13),
                          prefixIcon: Icon(Icons.search,
                              color: _kTextMuted.withOpacity(0.5), size: 18),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('ลากบอร์ดไปวางในโซน',
                        style: GoogleFonts.inter(
                            color: _kTextMuted, fontSize: 13)),
                    const SizedBox(height: 12),
                    Builder(builder: (ctx) {
                      final filtered = _availableDevices
                          .where((dId) =>
                              !_boards.any((b) => b.deviceId == dId))
                          .where((dId) => dId
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                          .toList();
                      if (filtered.isEmpty) {
                        return Center(
                            child: Text('ไม่พบอุปกรณ์',
                                style: TextStyle(
                                    color: _kTextMuted.withOpacity(0.5))));
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final dId = filtered[i];
                          return Draggable<String>(
                            data: dId,
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            feedback: Material(
                                color: Colors.transparent,
                                child:
                                    _buildBoardMarker(dId, isDragging: true)),
                            child: InkWell(
                              onTap: () => _showAddBoardDialog(dId),
                              borderRadius: BorderRadius.circular(12),
                              child: _buildBoardListTile(dId),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveLayout,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text('บันทึก LAYOUT',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen700,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shadowColor: _kGreen700.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Toolbox (mobile)
  // -------------------------------------------------------------------------
  Widget _buildMobileToolbox() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editMode == EditMode.boards) _buildMobileBoardSelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                    child: _modeButton(
                        EditMode.zones, 'จัดการโซน', Icons.grid_view)),
                const SizedBox(width: 12),
                Expanded(
                    child: _modeButton(
                        EditMode.boards, 'เพิ่มบอร์ด', Icons.sensors)),
              ],
            ),
          ),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveLayout,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text('บันทึก LAYOUT',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileBoardSelector() {
    final filteredIds = _availableDevices
        .where((dId) => !_boards.any((b) => b.deviceId == dId))
        .where(
            (dId) => dId.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาชื่อบอร์ด...',
                      hintStyle:
                          TextStyle(color: Colors.white24, fontSize: 13),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.white24, size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _showFullBoardPicker,
                icon: const Icon(Icons.apps_rounded,
                    color: Color(0xFF43A047)),
              ),
            ],
          ),
        ),
        if (filteredIds.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('ไม่พบบอร์ดที่ต้องการ...',
                style: TextStyle(color: Colors.white24, fontSize: 12)),
          )
        else
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredIds.length,
              itemBuilder: (ctx, i) {
                final dId = filteredIds[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Draggable<String>(
                    data: dId,
                    feedback: Material(
                        color: Colors.transparent,
                        child: _buildBoardMarker(dId, isDragging: true)),
                    child: InkWell(
                      onTap: () => _showAddBoardDialog(dId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF2E7D32).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF2E7D32).withOpacity(0.3)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(children: [
                              _statusDot(dId),
                              const SizedBox(width: 8),
                              Text(dId,
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 4),
                            const Text('แตะเพื่อวาง',
                                style: TextStyle(
                                    color: Colors.white30, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white10, height: 1),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Shared widgets
  // -------------------------------------------------------------------------
  Widget _modeButton(EditMode mode, String label, IconData icon) {
    final active = _editMode == mode;
    final isMobile = MediaQuery.of(context).size.width < 768;
    return InkWell(
      onTap: () =>
          setState(() => _editMode = active ? EditMode.none : mode),
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: isMobile ? 10 : 12, horizontal: 16),
        decoration: BoxDecoration(
          color: active ? _kGreen700 : _kTextMuted.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: isMobile
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(icon,
                color: active ? Colors.white : _kTextMuted,
                size: isMobile ? 18 : 20),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    color: active ? Colors.white : _kTextMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardListTile(String dId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kTextMuted.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _statusDot(dId),
          const SizedBox(width: 10),
          Expanded(
              child: Text(dId,
                  style: GoogleFonts.inter(
                      color: _kTextDark,
                      fontSize: 13,
                      fontWeight: FontWeight.bold))),
          Icon(Icons.drag_indicator,
              color: _kTextMuted.withOpacity(0.3), size: 18),
        ],
      ),
    );
  }

  Widget _statusDot(String dId) {
    return Container(
        width: 8,
        height: 8,
        decoration:
            BoxDecoration(color: _statusColor(dId), shape: BoxShape.circle));
  }

  Widget _buildDraggableBoard(BoardData b) {
    final boardContent = SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: GestureDetector(
              onTap: () => _editBoardName(b),
              child: _buildBoardMarker(b.deviceId, displayName: b.displayName),
            ),
          ),
          if (_editMode == EditMode.boards)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _removeBoard(b),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );

    if (_editMode != EditMode.boards) return boardContent;

    return Draggable<BoardData>(
      data: b,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Opacity(
        opacity: 0.7,
        child: Transform.scale(
          scale: 0.8,
          child: Material(
            color: Colors.transparent,
            child: _buildBoardMarker(b.deviceId,
                displayName: b.displayName, isDragging: true),
          ),
        ),
      ),
      childWhenDragging: const SizedBox(),
      child: boardContent,
    );
  }

  Widget _buildBoardMarker(String dId,
      {String displayName = '', bool isDragging = false}) {
    final color = _statusColor(dId);
    final String label = displayName.isNotEmpty ? displayName : dId;
    final bool hasAlarm = _alarmedDevices.contains(dId);
    final String statusInfo =
        _deviceStatusDetail[dId] ?? 'กำลังตรวจสอบสถานะ...';

    String tooltipMsg = label;
    if (hasAlarm) {
      final details = _alarmDetails[dId] ?? [];
      tooltipMsg += '\n🚨 ALARM ที่ตรวจพบ:';
      for (final d in details) tooltipMsg += '\n  • $d';
      tooltipMsg += '\n─────────────\n$statusInfo';
    } else {
      tooltipMsg += '\n$statusInfo';
    }

    IconData sensorIcon = PhosphorIcons.cloudSun();
    final idLower = dId.toLowerCase();
    if (idLower.contains('soil')) {
      sensorIcon = PhosphorIcons.plant();
    } else if (idLower.contains('min') || idLower.contains('npk') || idLower.contains('nitro')) {
      sensorIcon = PhosphorIcons.flask();
    }

    return Tooltip(
      message: tooltipMsg,
      preferBelow: false,
      verticalOffset: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isDragging
                  ? []
                  : hasAlarm
                      ? [
                          BoxShadow(
                              color: Colors.yellow.shade700.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2),
                          BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(2, 2)),
                        ]
                      : [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(2, 2))
                        ],
              border: Border.all(
                  color: hasAlarm ? Colors.yellow.shade700.withOpacity(0.5) : Colors.white,
                  width: 2.5),
            ),
            child: Icon(sensorIcon, color: Colors.white, size: 24),
          ),
          if (hasAlarm)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBC02D), // Yellow with exclamation
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(1, 1))
                  ],
                ),
                child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 12, weight: 900),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String dId) {
    switch (_deviceStatus[dId] ?? BoardStatus.offline) {
      case BoardStatus.online:
      case BoardStatus.alert: // ยังออนไลน์อยู่แต่มีค่าผิดปกติ
        return const Color(0xFF43A047);
      case BoardStatus.offline:
      default:
        return Colors.grey.shade700;
    }
  }

  // -------------------------------------------------------------------------
  // Helper: render base64 หรือ URL image
  // -------------------------------------------------------------------------
  Widget _buildImageWidget(String path, {BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('data:')) {
      // base64
      try {
        final bytes = base64Decode(path.split(',').last);
        return Image.memory(bytes, fit: fit, errorBuilder: (_, __, ___) => _imagePlaceholder());
      } catch (_) {
        return _imagePlaceholder();
      }
    } else if (path.startsWith('http')) {
      return Image.network(path, fit: fit, errorBuilder: (_, __, ___) => _imagePlaceholder());
    }
    return Image.asset(path, fit: fit, errorBuilder: (_, __, ___) => _imagePlaceholder());
  }

  Widget _imagePlaceholder() => Center(
      child: Icon(Icons.broken_image_outlined,
          color: _kTextMuted.withOpacity(0.3), size: 48));
}

// ---------------------------------------------------------------------------
// GridPainter
// ---------------------------------------------------------------------------
class GridPainter extends CustomPainter {
  final BuildContext context;
  GridPainter(this.context);

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.04)
          : Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;
    const double step = 25.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}