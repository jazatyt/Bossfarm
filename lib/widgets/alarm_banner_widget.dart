import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/alarm_service.dart';

// ── Theme constants ──────────────────────────────────────────────────────────
const _kGreen700      = Color(0xFF2E7D32);

/// Widget การ์ด Alarms สำหรับใส่ใน DashboardPage
/// ใช้แทน _buildSensorSummarySection() หรือวางไว้ตรงไหนก็ได้
class AlarmBannerWidget extends StatelessWidget {
  final AlarmService alarmService;

  const AlarmBannerWidget({Key? key, required this.alarmService})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final _kSurface  = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
    final _kTextDark = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A2E1A);
    final _kMuted    = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF6B8068);

    final critical = alarmService.criticalCount;
    final total    = alarmService.totalActive;

    return GestureDetector(
      onTap: () => context.push('/alarms'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 14, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Text('Alarms',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: _kTextDark, letterSpacing: -0.3)),
                const SizedBox(width: 6),
                Icon(Icons.open_in_new_rounded, size: 12, color: _kMuted),
                const Spacer(),
                if (total > 0)
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
                        Text('$total ACTIVE',
                            style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w800,
                                color: const Color(0xFFD32F2F))),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 10),

            // ── Actions Row ──────────────────────────────────────
            Row(
              children: [
                _miniCard(context, 'Active Alarms', total,
                    _kGreen700, Icons.notifications_active_rounded, 0),
                const SizedBox(width: 8),
                _miniCard(context, 'History', 0,
                    const Color(0xFFF57C00), Icons.history_rounded, 1),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(BuildContext context, String label, int count, Color color, IconData icon, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final _kTextDark = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A2E1A);
    final _kMuted    = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF6B8068);

    return Expanded(
      child: GestureDetector(
        onTap: () => context.push('/alarms', extra: index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.10), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(label,
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w600,
                            color: _kMuted, height: 1.1),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Icon(icon, size: 10, color: color.withOpacity(0.5)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (label != 'History')
                    Text('$count',
                        style: GoogleFonts.inter(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: _kTextDark, height: 1))
                  else
                    Text('History',
                        style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: color, height: 1)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color.withOpacity(0.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
