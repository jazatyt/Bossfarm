import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme_manager.dart';
import '../services/auth_service.dart';
import '../login_page.dart';
import '../history_view_page.dart';
import '../dashboard_page.dart';
import '../farm_layout_builder_page.dart';
import '../user_management_page.dart';
import '../services/layout_api_service.dart';
import '../all_farms_page.dart';
import '../alarms_page.dart';
import '../services/alarm_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';

class TopBar extends StatefulWidget {
  final VoidCallback? onLogoUpdated;
  final List<Widget>? actions;
  const TopBar({Key? key, this.onLogoUpdated, this.actions}) : super(key: key);

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final AuthService _authService = AuthService();
  final LayoutApiService _layoutApi = LayoutApiService();
  final AlarmService _alarmService = AlarmService();
  Timer? _alarmTimer;
  late bool _isAdmin;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _isAdmin = _authService.currentRole == 'admin';
    _logoUrl = _authService.logoUrl;

    // Sync logo from server to ensure it's up to date for everyone
    _authService.syncLogoFromServer().then((_) {
      if (mounted) {
        setState(() => _logoUrl = _authService.logoUrl);
      }
    });

    _alarmService.fetchAll();
    _alarmTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _alarmService.fetchAll().then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (!_isAdmin) return;
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        const fileName = 'logo_main.png';
        
        final uploadedPath = await _layoutApi.uploadImage(bytes, fileName, subfolder: 'icon');
        if (uploadedPath != null) {
          final fullUrl = uploadedPath.startsWith('http') 
              ? uploadedPath 
              : '${LayoutApiService.apiUrl}/$uploadedPath';
          
          final layout = await _layoutApi.fetchLayout();
          layout['logoUrl'] = fullUrl;
          await _layoutApi.saveLayout(layout);
          
          _authService.updateLogoUrl(fullUrl);
          
          if (mounted) {
            setState(() => _logoUrl = fullUrl);
            widget.onLogoUpdated?.call();
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking logo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = Theme.of(context).cardColor;
    final Color textDark = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A2E1A);
    final Color textMuted = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF6B8068);
    final Color green700 = const Color(0xFF2E7D32);

    final double width = MediaQuery.of(context).size.width;
    final bool isSmall = width < 480;

    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 10, 15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32), 
          bottomRight: Radius.circular(32)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Row(
        children: [
          // Brand Logo & Name (Click to go Home)
          GestureDetector(
            onTap: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
                (route) => false),
            onLongPress: _isAdmin ? _pickLogo : null,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: green700.withOpacity(0.1),
                      shape: BoxShape.circle,
                      image: _logoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_logoUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _logoUrl == null
                        ? Icon(Icons.eco_rounded, color: green700, size: 24)
                        : null,
                  ),
                  if (!isSmall) ...[
                    const SizedBox(width: 12),
                    Text(
                      'BOSS FARM',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: green700,
                          letterSpacing: 1.2),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const Spacer(),

          if (widget.actions != null) ...[
            ...widget.actions!,
            const SizedBox(width: 8),
            const VerticalDivider(width: 1, indent: 12, endIndent: 12),
            const SizedBox(width: 8),
          ],

          // Navigation Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => ThemeManager.toggleTheme(),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: textMuted, size: isSmall ? 18 : 22,
                ),
                tooltip: 'Toggle Theme',
              ),
              // ── Alarm Alarm Icon ─────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pushReplacement(
                        context, MaterialPageRoute(builder: (_) => const AlarmsPage())),
                    icon: Icon(Icons.notifications_none_rounded,
                        color: textMuted, size: isSmall ? 20 : 24),
                    tooltip: 'Alarms',
                  ),
                  if (_alarmService.totalActive > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${_alarmService.totalActive}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HistoryViewPage())),
                icon: Icon(Icons.history_rounded, color: textMuted, size: isSmall ? 20 : 24),
                tooltip: 'View History',
              ),
              IconButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FarmLayoutBuilderPage())),
                icon: Icon(Icons.grid_view_rounded, color: textMuted, size: isSmall ? 18 : 22),
                tooltip: 'Farm Layout',
              ),
              if (_isAdmin)
                IconButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserManagementPage())),
                  icon: Icon(Icons.settings_suggest_rounded, color: Colors.blue.shade400, size: isSmall ? 20 : 24),
                  tooltip: 'Management',
                ),
            ],
          ),

          const SizedBox(width: 4),
          const VerticalDivider(width: 1, indent: 8, endIndent: 8),
          const SizedBox(width: 8),

          // User Info
          _buildUserBadge(isSmall, textDark),

          const SizedBox(width: 4),

          // Logout
          IconButton(
            onPressed: () {
              AuthService.logout();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
            },
            icon: Icon(Icons.logout_rounded, color: Colors.red.shade400, size: isSmall ? 18 : 22),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildUserBadge(bool isSmall, Color textDark) {
    final String role = _authService.currentRole.toUpperCase();
    final bool isAdmin = role == 'ADMIN';
    final bool isTester = role == 'TESTER';
    final String? expiry = _authService.currentExpiryDate;
    
    int? daysLeft;
    if (expiry != null) {
      try {
        final expDate = DateTime.parse(expiry);
        daysLeft = expDate.difference(DateTime.now()).inDays + 1;
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.red.withOpacity(0.05) : (isTester ? Colors.purple.withOpacity(0.05) : Colors.blue.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isAdmin ? Colors.red : (isTester ? Colors.purple : Colors.blue)).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _authService.currentUsername?.toUpperCase() ?? 'GUEST',
            style: GoogleFonts.inter(fontSize: isSmall ? 10 : 12, fontWeight: FontWeight.w900, color: textDark),
          ),
          if (isTester && daysLeft != null)
            Text(
              '$daysLeft d left',
              style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w600, color: Colors.purple.shade600),
            ),
          const SizedBox(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isAdmin ? Colors.red : (isTester ? Colors.purple : Colors.blue),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              role,
              style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
