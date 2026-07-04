import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'services/layout_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'widgets/top_bar.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final AuthService _authService = AuthService();
  final LayoutApiService _layoutApi = LayoutApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _users = [];
  bool _isLoading = true;
  bool _isUploadingLogo = false;
  String? _logoUrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _logoUrl = _authService.logoUrl;
    
    // Sync logo from server
    _authService.syncLogoFromServer().then((_) {
      if (mounted) {
        setState(() => _logoUrl = _authService.logoUrl);
      }
    });
    _fetchUsers();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final String name = (user['username'] ?? '').toString().toLowerCase();
      final String email = (user['email'] ?? '').toString().toLowerCase();
      final String role = (user['role'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery) || role.contains(_searchQuery);
    }).toList();
  }

  Future<void> _fetchUsers() async {
    try {
      setState(() => _isLoading = true);
      final users = await _authService.getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      _showSnack('โหลดข้อมูลไม่สำเร็จ: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _handleDelete(String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบผู้ใช้ $username ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _authService.deleteUser(username);
      if (res['status'] == 'success') {
        _showSnack('ลบผู้ใช้สำเร็จ');
        _fetchUsers();
      } else {
        _showSnack(res['message'] ?? 'เกิดข้อผิดพลาด', isError: true);
      }
    }
  }

  Future<void> _handleAddTime(String username, String? currentExpiry) async {
    int selectedDays = 30;
    final List<int> options = [7, 14, 30, 60, 90, 180, 365];

    final confirmed = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A2A1A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.timer_outlined, color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('เพิ่มเวลา: $username',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentExpiry != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, color: Colors.purple, size: 14),
                        const SizedBox(width: 6),
                        Text('หมดอายุปัจจุบัน: ',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                        Text(currentExpiry.split(' ')[0],
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.purple)),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 14),
                        const SizedBox(width: 6),
                        Text('ยังไม่มีวันหมดอายุ — จะสร้างใหม่',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade700)),
                      ],
                    ),
                  ),
                Text('เพิ่มเวลาอีก (วัน)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((days) {
                    final bool isSelected = selectedDays == days;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedDays = days),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.purple : Colors.purple.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.purple.withOpacity(isSelected ? 1.0 : 0.2)),
                        ),
                        child: Text(
                          '$days วัน',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : Colors.purple,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ยกเลิก', style: GoogleFonts.inter(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_alarm_rounded, size: 16),
                label: Text('เพิ่ม $selectedDays วัน', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, selectedDays),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != null) {
      _showSnack('กำลังอัปเดต...');
      final res = await _authService.updateUserExpiry(username, confirmed);
      if (res['status'] == 'success') {
        _showSnack('เพิ่มเวลาสำเร็จ +$confirmed วัน ✓');
        _fetchUsers();
      } else {
        _showSnack(res['message'] ?? 'เกิดข้อผิดพลาด', isError: true);
      }
    }
  }

  Future<void> _handleRoleChange(String username, String currentRole) async {
    String selectedRole = currentRole.toLowerCase();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('จัดการสิทธิ์: $username'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(title: const Text('User'), value: 'user', groupValue: selectedRole, onChanged: (v) => setDialogState(() => selectedRole = v!)),
              RadioListTile<String>(title: const Text('Tester'), value: 'tester', groupValue: selectedRole, onChanged: (v) => setDialogState(() => selectedRole = v!)),
              RadioListTile<String>(title: const Text('Admin'), value: 'admin', groupValue: selectedRole, onChanged: (v) => setDialogState(() => selectedRole = v!)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            TextButton(onPressed: () => Navigator.pop(ctx, selectedRole), child: const Text('บันทึก')),
          ],
        ),
      ),
    );

    if (res != null && res.toLowerCase() != currentRole.toLowerCase()) {
      final updateRes = await _authService.updateUserRole(username, res.toLowerCase());
      if (updateRes['status'] == 'success') {
        _showSnack('อัปเดตสิทธิ์สำเร็จ');
        _fetchUsers();
      } else {
        _showSnack(updateRes['message'] ?? 'เกิดข้อผิดพลาด', isError: true);
      }
    }
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final croppedBytes = await _showCropDialog(bytes);
        if (croppedBytes != null) {
          setState(() => _isUploadingLogo = true);
          const fileName = 'logo_main.png'; 
          final uploadedPath = await _layoutApi.uploadImage(croppedBytes, fileName, subfolder: 'icon');
          if (uploadedPath != null) {
            final fullUrl = uploadedPath.startsWith('http') ? uploadedPath : '${LayoutApiService.apiUrl}/$uploadedPath';
            final layout = await _layoutApi.fetchLayout();
            layout['logoUrl'] = fullUrl;
            await _layoutApi.saveLayout(layout);
            _authService.updateLogoUrl(fullUrl);
            _showSnack('อัปเดตโลโก้สำเร็จ');
            setState(() => _logoUrl = fullUrl);
          } else {
            _showSnack('อัปโหลดล้มเหลว', isError: true);
          }
        }
      }
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e', isError: true);
    } finally {
      setState(() => _isUploadingLogo = false);
    }
  }

  Future<Uint8List?> _showCropDialog(Uint8List imageBytes) async {
    final GlobalKey boundaryKey = GlobalKey();
    final TransformationController transformController = TransformationController();
    double currentScale = 1.0;
    int currentRotation = 0;
    Uint8List? result;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A1F0A) : const Color(0xFFF1F5F1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 📸 พื้นที่จัดวางรูปภาพ
                RepaintBoundary(
                  key: boundaryKey,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          color: isDark ? const Color(0xFF0A1F0A) : const Color(0xFFE8F5E9),
                          child: InteractiveViewer(
                            transformationController: transformController,
                            minScale: 0.1,
                            maxScale: 5.0,
                            onInteractionUpdate: (details) {
                              setDialogState(() {
                                currentScale = transformController.value.getMaxScaleOnAxis();
                              });
                            },
                            child: RotatedBox(
                              quarterTurns: currentRotation,
                              child: Image.memory(imageBytes, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                      // 💡 หน้ากากวงกลมและขอบสีขาวหนา
                      IgnorePointer(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            children: [
                              ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  (isDark ? const Color(0xFF0A1F0A) : const Color(0xFFF1F5F1)).withOpacity(0.85),
                                  ui.BlendMode.srcOut,
                                ),
                                child: Stack(
                                  children: [
                                    Container(decoration: BoxDecoration(color: isDark ? const Color(0xFF0A1F0A) : const Color(0xFFF1F5F1), backgroundBlendMode: ui.BlendMode.dstOut)),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: MediaQuery.of(context).size.width * 0.8,
                                        height: MediaQuery.of(context).size.width * 0.8,
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.82,
                                  height: MediaQuery.of(context).size.width * 0.82,
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF2E7D32), width: 4)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 🎚️ แถบเลื่อนและปุ่มหมุน
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.image_outlined, color: isDark ? Colors.white54 : Colors.grey, size: 16),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF2E7D32),
                                inactiveTrackColor: const Color(0xFF2E7D32).withOpacity(0.2),
                                thumbColor: const Color(0xFF2E7D32),
                                trackHeight: 2,
                              ),
                              child: Slider(
                                value: currentScale.clamp(1.0, 3.0),
                                min: 1.0,
                                max: 3.0,
                                onChanged: (v) {
                                  setDialogState(() {
                                    currentScale = v;
                                    final Matrix4 matrix = Matrix4.identity()..scale(v);
                                    transformController.value = matrix;
                                  });
                                },
                              ),
                            ),
                          ),
                          Icon(Icons.image, color: isDark ? Colors.white : const Color(0xFF1B5E20), size: 22),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.grey.shade600), onPressed: () => Navigator.pop(context)),
                          // 🔄 ปุ่มหมุนทีละ 90 องศา
                          Container(
                            decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: IconButton(
                              icon: Icon(Icons.rotate_right_rounded, color: isDark ? Colors.white : const Color(0xFF2E7D32)),
                              onPressed: () {
                                setDialogState(() {
                                  currentRotation = (currentRotation + 1) % 4;
                                });
                              },
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                final RenderRepaintBoundary boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                                final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                                final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                                result = byteData!.buffer.asUint8List();
                                Navigator.pop(context);
                              } catch (e) {
                                print(e);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: Text('ตกลง', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A120A) : const Color(0xFFF1F5F1),
      body: Column(
        children: [
          const TopBar(),
          // Sub-header for Management
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.transparent,
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
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF1B5E20), size: 18),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                Text('Admin Management',
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : const Color(0xFF1B5E20),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    )),
                const Spacer(),
                IconButton(
                  onPressed: _fetchUsers,
                  icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : const Color(0xFF1B5E20)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildLogoSection(isDark),
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF162516) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people_alt_rounded, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 10),
                                  Text('การจัดการผู้ใช้', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1B5E20))),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                    child: Text('${_filteredUsers.length} คน', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _searchController,
                                style: GoogleFonts.inter(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'ค้นหาชื่อ, อีเมล หรือสิทธิ์...',
                                  prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                                  filled: true,
                                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                              ),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(thickness: 0.5)),
                              _filteredUsers.isEmpty
                                  ? _buildEmptyState()
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _filteredUsers.length,
                                      itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index], isDark),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
                    border: Border.all(color: const Color(0xFF2E7D32), width: 2.5),
                  ),
                  child: ClipOval(
                    child: _logoUrl != null
                        ? Image.network(_logoUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_rounded, size: 40, color: Colors.grey))
                        : const Icon(Icons.image_rounded, size: 40, color: Colors.grey),
                  ),
                ),
              ),
              if (_isUploadingLogo) const Positioned.fill(child: CircularProgressIndicator(color: Color(0xFF2E7D32), strokeWidth: 3)),
              Positioned(
                bottom: 5, right: 5,
                child: GestureDetector(
                  onTap: _pickAndUploadLogo,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('เปลี่ยนไอคอนโลโก้', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1B5E20))),
          Text('เลือกและปรับแต่งรูปภาพให้เป็นวงกลม', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Column(children: [Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withOpacity(0.5)), const SizedBox(height: 12), Text('ไม่พบรายชื่อที่ค้นหา', style: GoogleFonts.inter(color: Colors.grey))])));

  Widget _buildUserCard(dynamic user, bool isDark) {
    final String username = user['username'] ?? 'Unknown';
    final String role = (user['role'] ?? 'user').toString().toUpperCase();
    final String email = user['email'] ?? '-';
    final String expiry = user['expiry_date'] != null ? user['expiry_date'].toString().split(' ')[0] : 'ไม่จำกัด';
    final bool isAdmin = role == 'ADMIN';
    final bool isTester = role == 'TESTER';

    // ตรวจสอบว่า tester หมดอายุหรือยัง
    bool isExpired = false;
    if (isTester && user['expiry_date'] != null) {
      try {
        final expiryDate = DateTime.parse(user['expiry_date'].toString());
        isExpired = expiryDate.isBefore(DateTime.now());
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(backgroundColor: isAdmin ? Colors.red.withOpacity(0.1) : (isTester ? Colors.purple.withOpacity(0.1) : const Color(0xFF2E7D32).withOpacity(0.1)), child: Icon(isAdmin ? Icons.admin_panel_settings_rounded : (isTester ? Icons.science_rounded : Icons.person_rounded), color: isAdmin ? Colors.red : (isTester ? Colors.purple : const Color(0xFF2E7D32)), size: 20)),
          title: Text(username, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
          subtitle: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: isAdmin ? Colors.red : (isTester ? Colors.purple : Colors.blue), borderRadius: BorderRadius.circular(6)), child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white))),
            const SizedBox(width: 8),
            if (isTester) Text('หมดอายุ: $expiry', style: TextStyle(fontSize: 10, color: isExpired ? Colors.red : Colors.grey.shade500)),
            if (isTester && isExpired) ...[
              const SizedBox(width: 4),
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFC107), size: 16),
            ],
          ]),
          children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(children: [const Divider(), _buildDetailRow('Email', email, Icons.email_outlined), const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [if (isTester) _actionButton(icon: Icons.timer_outlined, label: 'เพิ่มเวลา', color: Colors.purple, onTap: () => _handleAddTime(username, user['expiry_date']?.toString())), _actionButton(icon: Icons.shield_outlined, label: 'เปลี่ยนสิทธิ์', color: Colors.blue, onTap: () => _handleRoleChange(username, role.toLowerCase())), _actionButton(icon: Icons.delete_outline_rounded, label: 'ลบ', color: Colors.red, onTap: () => _handleDelete(username))])]))],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) => Row(children: [Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 8), Text('$label: ', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)), Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))]);

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Column(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)), const SizedBox(height: 4), Text(label, style: GoogleFonts.inter(fontSize: 9, color: color, fontWeight: FontWeight.w600))])));
}
