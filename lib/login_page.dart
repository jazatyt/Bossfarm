import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'theme_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _authService = AuthService();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  String? _stableLogoUrl;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _stableLogoUrl = _authService.logoUrl;
    
    // Sync logo from server to ensure it's up to date for everyone
    _authService.syncLogoFromServer().then((_) {
      if (mounted) {
        setState(() => _stableLogoUrl = _authService.logoUrl);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnack('กรุณากรอกข้อมูลให้ครบถ้วน', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.login(username, password);
    setState(() => _isLoading = false);

    if (result['status'] == 'success') {
      if (mounted) {
        context.go('/');
      }
    } else {
      if (mounted) {
        _showSnack(result['message'] ?? 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? const Color(0xFFB71C1C) : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2E1A);
    final mutedColor = isDark ? const Color(0xFFA5B9A2) : const Color(0xFF546E7A);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background gradient blobs
          Positioned(
            top: -80, left: -60,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1B5E20).withOpacity(0.25),
              ),
            ),
          ),
          Positioned(
            bottom: -40, right: -80,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF388E3C).withOpacity(0.15),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App icon + title
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                  color: const Color(0xFF66BB6A),
                                ),
                                onPressed: () => ThemeManager.toggleTheme(),
                              ),
                            ],
                          ),
                          RepaintBoundary(
                            child: SizedBox(
                              width: 100, height: 100,
                              child: ClipOval(
                                child: _stableLogoUrl != null
                                    ? Image.network(
                                        _stableLogoUrl!,
                                        key: ValueKey('logo_$_stableLogoUrl'),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Image.asset(
                                          'img/logo2.png',
                                          key: const ValueKey('logo_default'),
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : Image.asset(
                                        'img/logo2.png',
                                        key: const ValueKey('logo_default'),
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Boss Farm',
                            style: GoogleFonts.inter(
                              fontSize: 34, fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1B5E20), letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '',
                            style: GoogleFonts.inter(fontSize: 14, color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 52),

                    // Card form
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(isDark ? 0.3 : 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เข้าสู่ระบบ',
                            style: GoogleFonts.inter(
                              fontSize: 22, fontWeight: FontWeight.w700,
                              color: textColor, letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'จัดการฟาร์มและดูข้อมูลเซนเซอร์แบบเรียลไทม์',
                            style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
                          ),
                          const SizedBox(height: 28),

                          // Username
                          _buildFieldLabel('ชื่อผู้ใช้งาน'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _usernameController,
                            hint: 'กรอกชื่อผู้ใช้งาน',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 20),

                          // Password
                          _buildFieldLabel('รหัสผ่าน'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passwordController,
                            hint: 'กรอกรหัสผ่าน',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                          ),
                          const SizedBox(height: 32),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Text(
                                      'เข้าสู่ระบบ',
                                      style: GoogleFonts.inter(
                                        fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ยังไม่มีบัญชี? ',
                          style: GoogleFonts.inter(color: mutedColor, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/register'),
                          child: Text(
                            'สมัครสมาชิก',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF66BB6A),
                              fontSize: 14, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(label, style: GoogleFonts.inter(
      fontSize: 13, fontWeight: FontWeight.w600, 
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCFD8DC) : const Color(0xFF546E7A),
    ));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      style: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A2E1A), fontSize: 15),
      cursorColor: const Color(0xFF66BB6A),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF90A4AE)
                : Colors.grey[500],
            fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        suffixIcon: isPassword
            ? GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF7BA87B) : const Color(0xFF4A6A4A), size: 20,
                ),
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF263238)
            : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}
