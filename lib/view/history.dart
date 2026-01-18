import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'history_data.dart';
import 'package:Medichine/services/api_service.dart';

class HistoryDataScreen extends StatelessWidget {
  const HistoryDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History Data")),
      body: const Center(child: Text("This is the History Data Screen")),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> historyList = [];
  bool isLoading = false;

  final String baseDomain = 'Werniverse-medichine.hf.space';
  Uri buildUri(String path) => Uri.https(baseDomain, path);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchHistory();
    });
  }

  Future<void> fetchHistory() async {
    try {
      // ✅ Use ApiService
      final res = await ApiService.get('/history');

      if (res.statusCode == 200) {
        final dynamic decoded = json.decode(res.body);
        final List<dynamic> rawHistory =
        decoded is List ? decoded : (decoded.values.toList());
        final transformedHistory = rawHistory.map((item) => {
          "time_taken": item["datetime_taken"] ?? item["time_taken"] ?? "Unknown time",
          "name": item["medicine_name"] ?? "Unknown Medicine",
          "days": item["scheduled_days"] ?? "Unknown days",
          "time": item["scheduled_time"] ?? "Unknown time",
          "quantity": item["quantity"] ?? "Unknown quantity",
          "container_id": item["container_id"] ?? "Unknown container",
          "id": item["id"] ?? 0,
        }).toList();
        setState(() => historyList = transformedHistory);
      } else {
        print("❌ Failed to fetch history: ${res.statusCode}");
        _showSnackBar("Failed to fetch history", isError: true);
      }
    } catch (e) {
      print("❌ Error fetching history: $e");
      _showSnackBar("Error fetching history: $e", isError: true);
    }
  }

  Future<void> deleteHistory(String timeTaken, int? historyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete history entry at "$timeTaken"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ok'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // ✅ Use ApiService
        final res = historyId != null && historyId > 0
            ? await ApiService.delete('/delete_history/$historyId')
            : await ApiService.delete('/delete_history/$timeTaken');

        if (res.statusCode == 200) {
          await fetchHistory();
          _showSnackBar("History entry deleted", isError: false);
        } else {
          _showSnackBar("Failed to delete history entry", isError: true);
        }
      } catch (e) {
        print("❌ Error deleting history: $e");
        _showSnackBar("Error deleting history: $e", isError: true);
      }
    }
  }

  Future<void> deleteAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete All History'),
        content: const Text('Are you sure you want to delete all records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await ApiService.delete('/delete_all_history');

        if (res.statusCode == 200) {
          await fetchHistory();
          _showSnackBar("All history deleted", isError: false);
        } else {
          _showSnackBar("Failed to delete all history", isError: true);
        }
      } catch (e) {
        print("❌ Error deleting all: $e");
        _showSnackBar("Error deleting all: $e", isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = theme.textTheme.titleLarge?.color;
    final deleteColor = isDark ? Colors.grey[900]! : const Color(0xFFF3533A);
    final deleteIconTextColor = isDark ? const Color(0xFFF3533A) : Colors.white;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: titleColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'HISTORY',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.data_usage, color: titleColor, size: 30),
              tooltip: "History Data",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: 200,
          height: 100,
          child: ElevatedButton(
            onPressed: historyList.isEmpty ? null : deleteAllHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: historyList.isEmpty ? Colors.grey : deleteColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              side: BorderSide.none,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete,
                    color: historyList.isEmpty ? Colors.grey[600] : deleteIconTextColor,
                    size: 40),
                const SizedBox(height: 4),
                Text(
                  "Delete All",
                  style: TextStyle(
                    color: historyList.isEmpty ? Colors.grey[600] : deleteIconTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: fetchHistory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Medicine History',
                style: TextStyle(
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: historyList.isEmpty
                    ? ListView(
                  children: [
                    const SizedBox(height: 200),
                    Center(
                      child: Text(
                        'No history available',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                )
                    : ListView.builder(
                  itemCount: historyList.length,
                  padding: const EdgeInsets.only(bottom: 140),
                  itemBuilder: (context, index) {
                    final item = historyList[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      color: isDark ? Colors.grey[950] : Colors.grey[200],
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Time Taken:",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: isDark ? Colors.grey[950] : Colors.grey[200],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item["time_taken"] ?? "Unknown time",
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 30),
                                  onPressed: () => deleteHistory(item["time_taken"] ?? "Unknown", item["id"]),
                                  tooltip: "Delete this entry",
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Name: ${item["name"] ?? "Unknown"}",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.medical_services, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text("Container: ${item["container_id"] ?? "Unknown"}", style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text("Days: ${item["days"] ?? "Unknown"}", style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text("Scheduled: ${item["time"] ?? "Unknown"}", style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.medication, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text("Quantity: ${item["quantity"]?.toString() ?? "Unknown"}", style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}