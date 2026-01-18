import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:Medichine/services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const scheduleColor = Color(0xFF5ACFC9);
  static const historyColor = Color(0xFF8AD879);
  static const tutorialColor = Color(0xFFFA9F42);
  static const settingsColor = Color(0xFFF3533A);

  List<dynamic> historyList = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  double avgDelay = 0.0;
  int onTimeCount = 0;
  int averageCount = 0;
  int lateCount = 0;
  int totalDoses = 0;
  double adherenceRate = 0.0;

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final res = await ApiService.get('/history', context: context).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (res.statusCode == 200) {
        final dynamic decoded = json.decode(res.body);
        final List<dynamic> rawHistory =
        decoded is List ? decoded : (decoded.values.toList());

        setState(() {
          historyList = rawHistory.map((item) {
            return {
              "id": item["id"] ?? 0,
              "medicine_name": item["medicine_name"] ?? "Unknown",
              "container_id": item["container_id"] ?? "Unknown container",
              "quantity": item["quantity"] ?? "Unknown quantity",
              "scheduled_time": item["scheduled_time"] ?? "12:00am",
              "scheduled_days": item["scheduled_days"] ?? "Unknown days",
              "time_taken": item["time_taken"] ?? "12:00am",
            };
          }).toList();

          isLoading = false;
          hasError = false;
        });
        _calculateAnalytics();
      } else {
        setState(() {
          hasError = true;
          errorMessage = 'Server error: ${res.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Network error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  DateTime? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;

    try {
      String cleanTime = timeStr.toLowerCase().trim();
      bool isPM = cleanTime.contains('pm');
      bool isAM = cleanTime.contains('am');

      if (!isPM && !isAM) return null;

      cleanTime = cleanTime.replaceAll(RegExp(r'[apm\s]'), '');

      final parts = cleanTime.split(":");
      if (parts.length != 2) return null;

      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      if (isPM && hour != 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return null;
      }

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);

    } catch (e) {
      print('Error parsing time: $timeStr - $e');
      return null;
    }
  }

  void _calculateAnalytics() {
    double totalDelay = 0;
    int validEntries = 0;
    onTimeCount = 0;
    averageCount = 0;
    lateCount = 0;
    totalDoses = historyList.length;

    for (var item in historyList) {
      final sched = _parseTime(item["scheduled_time"]);
      final taken = _parseTime(item["time_taken"]);

      if (sched != null && taken != null) {
        double schedMins = sched.hour * 60 + sched.minute.toDouble();
        double takenMins = taken.hour * 60 + taken.minute.toDouble();
        double delay = takenMins - schedMins;

        // Handle day boundary crossing (e.g., scheduled at 11:50 PM, taken at 12:10 AM next day)
        if (delay > 720) { // More than 12 hours late
          delay -= 1440; // Subtract 24 hours (assume next day)
        } else if (delay < -720) { // More than 12 hours early
          delay += 1440; // Add 24 hours (assume previous day)
        }

        totalDelay += delay;
        validEntries++;

        // Updated categorization with stricter timing requirements
        if (delay.abs() <= 1) { // Within 1 minute - On Time
          onTimeCount++;
        } else if (delay.abs() <= 5) { // 1-5 minutes off - Average
          averageCount++;
        } else { // More than 5 minutes off - Late
          lateCount++;
        }
      }
    }

    setState(() {
      avgDelay = validEntries > 0 ? totalDelay / validEntries : 0.0;
      // Calculate adherence rate based on on-time doses
      adherenceRate = totalDoses > 0 ? (onTimeCount / totalDoses) * 100 : 0.0;
    });
  }

  String _minutesToHHmm(double value) {
    int hours = value ~/ 60;
    int minutes = value.toInt() % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
  }

  // Helper function to convert minutes to AM/PM format
  String _formatTimeAMPM(double minutes) {
    int totalMins = minutes.toInt();
    int hours = (totalMins ~/ 60) % 24;
    int mins = totalMins % 60;

    // Handle negative values
    if (totalMins < 0) {
      hours = 23 + (totalMins ~/ 60) + 1;
      mins = 60 + (totalMins % 60);
      if (mins >= 60) {
        hours++;
        mins -= 60;
      }
      hours = hours % 24;
    }

    String period = hours >= 12 ? 'pm' : 'am';
    int displayHour = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    return "${displayHour}:${mins.toString().padLeft(2, '0')}$period";
  }

  // Helper function to get day of week
  String _getDayOfWeek(int index) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[index % 7];
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: settingsColor),
          SizedBox(height: 16),
          Text(
            'Failed to load data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.titleLarge?.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "HISTORY DATA",
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: fetchHistory,
        color: scheduleColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildBody(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Text('Loading analytics...'),
      );
    }

    if (hasError) {
      return _buildErrorWidget();
    }

    if (historyList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication, size: 64, color: historyColor),
            SizedBox(height: 16),
            Text(
              'No medication history available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Start taking your medication to see analytics',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _buildSummaryCard(
              'Adherence Rate',
              '${adherenceRate.toStringAsFixed(1)}%',
              adherenceRate >= 70 ? historyColor : (adherenceRate >= 50 ? tutorialColor : settingsColor),
              Icons.timeline,
            ),
            _buildSummaryCard(
              'Avg Delay',
              _formatDelayDisplay(avgDelay),
              avgDelay.abs() <= 1 ? historyColor : (avgDelay.abs() <= 5 ? tutorialColor : settingsColor),
              Icons.access_time,
            ),
            _buildSummaryCard(
              'On Time',
              '$onTimeCount/$totalDoses',
              historyColor,
              Icons.check_circle,
            ),
            _buildSummaryCard(
              'Total Doses',
              totalDoses.toString(),
              historyColor,
              Icons.medication,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Status Message
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: adherenceRate >= 80
                ? historyColor.withOpacity(0.1)
                : (adherenceRate >= 60 ? tutorialColor.withOpacity(0.1) : settingsColor.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: adherenceRate >= 80
                  ? historyColor
                  : (adherenceRate >= 60 ? tutorialColor : settingsColor),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                adherenceRate >= 80
                    ? Icons.check_circle
                    : (adherenceRate >= 60 ? Icons.schedule : Icons.warning),
                color: adherenceRate >= 80
                    ? historyColor
                    : (adherenceRate >= 60 ? tutorialColor : settingsColor),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adherenceRate >= 80
                          ? "Outstanding precision! Patient consistently taking medicine on time"
                          : adherenceRate >= 60
                          ? "Good adherence with minor delay, but needs improvement"
                          : "Timing needs improvement for better medication effectiveness",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: adherenceRate >= 80
                            ? historyColor
                            : (adherenceRate >= 60 ? tutorialColor : settingsColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Precise (±1min): $onTimeCount • Acceptable (1-5min): $averageCount • Delayed (>5min): $lateCount",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        _buildCharts(),
      ],
    );
  }

  String _formatDelayDisplay(double delayMinutes) {
    if (delayMinutes >= 0) {
      int hours = delayMinutes ~/ 60;
      int minutes = (delayMinutes % 60).round();
      if (hours > 0) {
        return '+${hours}h ${minutes}m';
      } else {
        return '+${minutes}m';
      }
    } else {
      int hours = delayMinutes.abs() ~/ 60;
      int minutes = (delayMinutes.abs() % 60).round();
      if (hours > 0) {
        return '-${hours}h ${minutes}m';
      } else {
        return '-${minutes}m';
      }
    }
  }

  Widget _buildCharts() {
    final List<FlSpot> scheduledSpots = [];
    final List<FlSpot> takenSpots = [];
    final List<FlSpot> delaySpots = [];

    // Ensure we have data to display
    if (historyList.isEmpty) {
      return const SizedBox.shrink();
    }

    for (int i = 0; i < historyList.length; i++) {
      final sched = _parseTime(historyList[i]["scheduled_time"]);
      final taken = _parseTime(historyList[i]["time_taken"]);

      if (sched != null && taken != null) {
        double schedY = sched.hour * 60 + sched.minute.toDouble();
        double takenY = taken.hour * 60 + taken.minute.toDouble();

        scheduledSpots.add(FlSpot(i.toDouble(), schedY));
        takenSpots.add(FlSpot(i.toDouble(), takenY));

        double delay = takenY - schedY;

        // Handle day boundary crossing for delay calculation
        if (delay > 720) { // More than 12 hours late
          delay -= 1440; // Subtract 24 hours
        } else if (delay < -720) { // More than 12 hours early
          delay += 1440; // Add 24 hours
        }

        delaySpots.add(FlSpot(i.toDouble(), delay));
      }
    }

    // If no valid data points, don't show charts
    if (scheduledSpots.isEmpty && takenSpots.isEmpty) {
      return const Center(
        child: Text(
          'No valid time data available for charts',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart 1 - Scheduled vs Actual Time
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Scheduled vs. Taken Time",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 16, height: 3, color: scheduleColor),
                    const SizedBox(width: 8),
                    const Text('Scheduled', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    Container(width: 16, height: 3, color: historyColor),
                    const SizedBox(width: 8),
                    const Text('Actual', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                AspectRatio(
                  aspectRatio: 1.2,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 1440,
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: true),
                      // Add custom touch data to show proper time format in tooltips
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBorder: BorderSide(color: Colors.grey.shade400),
                          tooltipRoundedRadius: 8,
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final flSpot = barSpot;
                              String timeFormatted = _formatTimeAMPM(flSpot.y);
                              String lineType = '';
                              Color color = Colors.black;

                              if (barSpot.barIndex == 0) {
                                lineType = 'Scheduled';
                                color = scheduleColor;
                              } else if (barSpot.barIndex == 1) {
                                lineType = 'Taken';
                                color = historyColor;
                              }

                              return LineTooltipItem(
                                '$lineType: $timeFormatted',
                                TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            interval: 240, // Every 4 hours
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatTimeAMPM(value),
                                style: const TextStyle(fontSize: 9),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: historyList.length > 10 ? 2 : 1,
                            getTitlesWidget: (value, meta) =>
                                Text("${(value.toInt() + 1)}", style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        if (scheduledSpots.isNotEmpty)
                          LineChartBarData(
                            spots: scheduledSpots,
                            isCurved: false,
                            color: scheduleColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                          ),
                        if (takenSpots.isNotEmpty)
                          LineChartBarData(
                            spots: takenSpots,
                            isCurved: false,
                            color: historyColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Chart 2 - Delay Pattern
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Delay Pattern (Minutes)",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 16, height: 3, color: settingsColor),
                    const SizedBox(width: 8),
                    const Text('Delay (+ late, - early)', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                AspectRatio(
                  aspectRatio: 1.2,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: true),
                      // Add custom touch data for delay chart
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final flSpot = barSpot;
                              String delayFormatted = _formatDelayDisplay(flSpot.y);

                              return LineTooltipItem(
                                'Delay: $delayFormatted',
                                const TextStyle(
                                  color: settingsColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 5, // Every 5 minutes (more granular than before)
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                "${value.toInt()}m",
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: historyList.length > 7 ? 2 : 1,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              return Text(
                                "${index + 1}",
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        if (delaySpots.isNotEmpty)
                          LineChartBarData(
                            spots: delaySpots,
                            isCurved: true,
                            color: settingsColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: settingsColor.withOpacity(0.1),
                            ),
                          ),
                      ],
                      // Add horizontal lines to show the new timing thresholds
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          // On-time reference line
                          HorizontalLine(
                            y: 0,
                            color: historyColor.withOpacity(0.7),
                            strokeWidth: 2,
                            dashArray: [5, 5],
                          ),
                          // 1-minute threshold lines
                          HorizontalLine(
                            y: 1,
                            color: tutorialColor.withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [3, 3],
                          ),
                          HorizontalLine(
                            y: -1,
                            color: tutorialColor.withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [3, 3],
                          ),
                          // 5-minute threshold lines
                          HorizontalLine(
                            y: 5,
                            color: settingsColor.withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [3, 3],
                          ),
                          HorizontalLine(
                            y: -5,
                            color: settingsColor.withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [3, 3],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}