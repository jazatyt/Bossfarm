import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'services/influx_service.dart';
import 'widgets/sensor_line_chart.dart';

class SensorPage extends StatefulWidget {
  final String? field;
  final String? title;

  const SensorPage({Key? key, this.field, this.title}) : super(key: key);

  @override
  _SensorPageState createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  List<Map<String, dynamic>> data = [];
  bool isLoading = true;
  bool isError = false;
  String errorMessage = '';
  Timer? _timer;
  late String selectedRange;
  DateTime? lastUpdated;

  final InfluxService _influxService = InfluxService();

  final List<Map<String, String>> ranges = [
    {'label': '1 Hour', 'value': '-1h'},
    {'label': '1 Day', 'value': '-1d'},
    {'label': '7 Days', 'value': '-7d'},
    {'label': '30 Days', 'value': '-30d'},
    {'label': '90 Days', 'value': '-90d'},
  ];


  @override
  void initState() {
    super.initState();
    selectedRange = (widget.field != null) ? '-30d' : '-1h';
    fetchData();
    // Start polling if it's a short range
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (selectedRange == '-1h' || selectedRange == '-1d') {
        fetchData(isAutoRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchData({bool isAutoRefresh = false}) async {
    if (!isAutoRefresh) {
      setState(() {
        isLoading = true;
        isError = false;
      });
    }

    try {
      final fieldToFetch = widget.field ?? 'temperature';
      final results = await _influxService.fetchTimeSeries(fieldToFetch, range: selectedRange);

      if (mounted) {
        setState(() {
          data = results; 
          isLoading = false;
          isError = false;
          lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted && !isAutoRefresh) {
        setState(() {
          isError = true;
          errorMessage = e.toString();
          isLoading = false;
        });
      }
      debugPrint("Error fetching data: $e");
    }
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isError ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isError ? Colors.red : Colors.green,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isError ? Colors.red : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isError ? 'Disconnected' : 'Live Data',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isError ? Colors.red[700] : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ranges.length,
        itemBuilder: (context, index) {
          final range = ranges[index];
          final isSelected = selectedRange == range['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(range['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    selectedRange = range['value']!;
                    data = []; // Clear current data to show loading spinner
                  });
                  fetchData();
                }
              },
              selectedColor: Colors.teal[600],
              labelStyle: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              elevation: isSelected ? 4 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (data.isEmpty) return const SizedBox.shrink();
    
    // Assume the first item in the list is the most recent (InfluxDB default)
    final latest = data.isNotEmpty ? data.first : null;
    final value = latest != null ? latest['_value']?.toString() ?? '0.0' : '0.0';
    final measurement = widget.title ?? widget.field ?? 'Sensor';
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[700]!, Colors.teal[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                measurement.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  fontSize: 14,
                ),
              ),
              const Icon(Icons.sensors, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Latest reading update',
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
          ),
          if (lastUpdated != null)
            Text(
              'Last sync: ${lastUpdated!.hour.toString().padLeft(2, '0')}:${lastUpdated!.minute.toString().padLeft(2, '0')}:${lastUpdated!.second.toString().padLeft(2, '0')} (UTC+7)',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text(
          widget.title ?? "Real-time Insights",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _buildStatusChip(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchData,
        child: Column(
          children: [
            _buildRangeSelector(),
            Expanded(
              child: isLoading && data.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : isError && data.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text("Failed to load data", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(errorMessage, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey)),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(onPressed: () => fetchData(), child: const Text("Retry")),
                            ],
                          ),
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(child: _buildSummaryCard()),
                            if (data.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverToBoxAdapter(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "TREND ANALYSIS",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.blueGrey[300],
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SensorLineChart(
                                          data: data,
                                          label: (widget.field?.toLowerCase() ?? 'temperature').contains('temp') 
                                              ? 'temp.' 
                                              : (widget.field?.toLowerCase() ?? 'temperature').contains('humid')
                                                  ? 'Humid.'
                                                  : (widget.field?.toLowerCase() ?? 'temperature').contains('co2')
                                                      ? 'CO2'
                                                      : widget.title ?? widget.field ?? 'Sensor',
                                          unit: (widget.field?.toLowerCase() ?? 'temperature').contains('temp') 
                                              ? '°C' 
                                              : (widget.field?.toLowerCase() ?? 'temperature').contains('humid')
                                                  ? 'Rh%'
                                                  : (widget.field?.toLowerCase() ?? 'temperature').contains('co2')
                                                      ? 'ppm'
                                                      : '',
                                        ),

                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  "HISTORY LOG",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blueGrey[300],
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final reversedData = data.reversed.toList();
                                  final item = reversedData[index];
                                  final timeStr = item['_time']?.toString() ?? '';
                                  final value = item['_value']?.toString() ?? '0';
                                  
                                  // Parse time for better display
                                  String displayTime = timeStr;
                                  try {
                                    final dt = DateTime.parse(timeStr).toLocal();
                                    displayTime = "${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} (UTC+7)";
                                  } catch (_) {}

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.show_chart, color: Colors.teal),
                                      ),
                                      title: Text(
                                        "Value: $value",
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Colors.blueGrey[900],
                                        ),
                                      ),
                                      subtitle: Text(
                                        displayTime,
                                        style: GoogleFonts.inter(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                      ),
                                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                                    ),
                                  );
                                },
                                childCount: data.length,
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
