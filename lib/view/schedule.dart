import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:Medichine/services/api_service.dart';
import 'create.dart';
import 'edit.dart';

class ScheduleScreen extends StatefulWidget {
  final int containerId;
  const ScheduleScreen({super.key, required this.containerId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<dynamic> schedules = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchSchedules();
  }

  Future<void> fetchSchedules() async {
    setState(() => isLoading = true);

    try {
      final resp = await ApiService.get('/get_schedules/${widget.containerId}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          schedules = data['schedules'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteSchedule(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this schedule?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(side: BorderSide.none),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    if (ok == true) {
      // Optimistic update
      setState(() => schedules.removeWhere((s) => s['id'] == id));

      try {
        final resp = await ApiService.delete('/delete_schedule/$id');

        if (resp.statusCode != 200) {
          // Revert on failure
          await fetchSchedules();
        }
      } catch (e) {
        // Revert on error
        await fetchSchedules();
      }
    }
  }

  Future<void> deleteAllSchedules() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete All Schedules"),
        content: const Text("Are you sure you want to delete all schedules?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(side: BorderSide.none),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    if (ok == true) {
      // Optimistic update
      final backupSchedules = List.from(schedules);
      setState(() => schedules.clear());

      try {
        final resp = await ApiService.delete('/delete_all_schedules/${widget.containerId}');

        if (resp.statusCode != 200) {
          // Revert on failure
          setState(() => schedules = backupSchedules);
        }
      } catch (e) {
        // Revert on error
        setState(() => schedules = backupSchedules);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = theme.textTheme.titleLarge?.color;
    final textColor = isDark ? Colors.white : Colors.black;
    final addBg = isDark ? Colors.grey[900]! : const Color(0xFF5ACFC9);
    final addTxt = isDark ? const Color(0xFF5ACFC9) : Colors.white;
    final bool hasSchedules = schedules.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CONTAINER ${widget.containerId}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            iconSize: 40,
            color: hasSchedules ? const Color(0xFFF3533A) : Colors.grey,
            onPressed: hasSchedules ? deleteAllSchedules : null,
            tooltip: 'Delete All Schedules',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchSchedules,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedules',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : schedules.isEmpty
                    ? ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(
                      child: Text(
                        'No schedule yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                )
                    : ListView.builder(
                  itemCount: schedules.length,
                  padding: const EdgeInsets.only(bottom: 140),
                  itemBuilder: (ctx, i) {
                    final s = schedules[i];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 2,
                      color: isDark ? Colors.grey[950] : Colors.grey[200],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    s['name'] ?? 'No name',
                                    style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Color(0xFF8AD879),
                                      ),
                                      onPressed: () async {
                                        final updated = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditScheduleScreen(
                                              scheduleId: s['id'],
                                            ),
                                          ),
                                        );
                                        if (updated == true) fetchSchedules();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Color(0xFFF3533A),
                                      ),
                                      onPressed: () => deleteSchedule(s['id']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Days: ${s['days'] ?? 'None'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Time: ${s['time'] ?? 'Not set'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.medication,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Quantity: ${s['quantity'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
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
      floatingActionButton: SizedBox(
        width: 200,
        height: 100,
        child: ElevatedButton(
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => CreateScheduleScreen(
                  containerId: widget.containerId,
                ),
              ),
            );
            if (created == true) fetchSchedules();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: addBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            side: BorderSide.none,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 50, color: addTxt),
              const SizedBox(height: 6),
              Text(
                "Add",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: addTxt,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}