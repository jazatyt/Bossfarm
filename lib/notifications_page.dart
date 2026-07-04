import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sensor_alert.dart';

class NotificationsPage extends StatelessWidget {
  final List<SensorAlert> alerts;
  const NotificationsPage({Key? key, required this.alerts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text('Notifications (${alerts.length})',
          style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 1,
      ),
      body: alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  const SizedBox(height: 16),
                  Text('No alerts found',
                    style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final isCritical = alert.severity == AlertSeverity.critical;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  color: alert.color.withOpacity(0.06),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: alert.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12)),
                      child: Icon(alert.icon, color: alert.color, size: 22),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(alert.category,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800, fontSize: 14,
                              color: alert.color)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: alert.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8)),
                          child: Text(isCritical ? 'Critical' : 'Warning',
                            style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: alert.color)),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(alert.message,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(
                          '${alert.time.hour.toString().padLeft(2,'0')}:${alert.time.minute.toString().padLeft(2,'0')}',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
