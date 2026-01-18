import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:Medichine/services/auth_guard.dart';
import 'package:Medichine/services/api_service.dart';

class CreateScheduleScreen extends StatefulWidget {
  final int containerId;
  const CreateScheduleScreen({super.key, required this.containerId});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final TextEditingController quantityController = TextEditingController(text: '1');
  final TextEditingController nameInputController = TextEditingController();

  late TimeOfDay selectedTime;
  final List<String> selectedDays = [];
  String? labelName;
  String selectedTimezone = 'Asia/Manila';

  static const String BACKEND_URL = 'https://Werniverse-medichine.hf.space/save_schedule';

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
  }

  Future<void> _initializeTimezone() async {
    tz.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    selectedTimezone = prefs.getString('timezone') ?? 'Asia/Manila';
    final now = tz.TZDateTime.now(tz.getLocation(selectedTimezone));
    selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
    setState(() {});
  }

  Future<void> _showTimezoneDialog() async {
    final timezones = [
      'Asia/Manila',
      'Asia/Tokyo',
      'Asia/Dubai',
      'Europe/London',
      'Europe/Paris',
      'America/New_York',
      'America/Los_Angeles',
      'UTC',
    ];

    final now = DateTime.now();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Timezone'),
        content: SizedBox(
          height: 400,
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: timezones.length,
            itemBuilder: (_, i) {
              final zone = timezones[i];
              final location = tz.getLocation(zone);
              final localTime = tz.TZDateTime.from(now, location);
              final formattedTime = TimeOfDay(hour: localTime.hour, minute: localTime.minute)
                  .format(context);

              final isSelected = selectedTimezone == zone;

              return ListTile(
                leading: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.teal)
                    : const Icon(Icons.circle_outlined),
                title: Text(zone),
                subtitle: Text('Current time: $formattedTime'),
                tileColor: isSelected ? Colors.teal.withOpacity(0.1) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('timezone', zone);
                  selectedTimezone = zone;

                  final newNow = tz.TZDateTime.now(tz.getLocation(zone));
                  setState(() {
                    selectedTime = TimeOfDay(hour: newNow.hour, minute: newNow.minute);
                  });

                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void toggleDay(String day) {
    setState(() {
      if (day == 'Everyday') {
        if (selectedDays.contains('Everyday')) {
          selectedDays.clear();
        } else {
          selectedDays
            ..clear()
            ..addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Everyday']);
        }
      } else {
        selectedDays.remove('Everyday');
        if (selectedDays.contains(day)) {
          selectedDays.remove(day);
        } else {
          selectedDays.add(day);
        }
        const allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        if (allDays.every((d) => selectedDays.contains(d))) {
          selectedDays.add('Everyday');
        }
      }
    });
  }

  void adjustQuantity(int delta) {
    final current = int.tryParse(quantityController.text) ?? 1;
    final next = (current + delta).clamp(1, 10);
    setState(() {
      quantityController.text = next.toString();
    });
  }

  Future<void> showTimePickerDialog() async {
    final time = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (time != null) setState(() => selectedTime = time);
  }

  Future<void> promptLabelNameInput() async {
    nameInputController.text = labelName ?? '';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Label Name'),
        content: TextField(
          controller: nameInputController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'NAME'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
              onPressed: () {
                setState(() => labelName = nameInputController.text.trim());
                Navigator.pop(context);
              },
              child: const Text('OK')),
        ],
      ),
    );
  }

  String formattedTime() {
    final h = selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
    final m = selectedTime.minute.toString().padLeft(2, '0');
    final p = selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Future<void> saveSchedule() async {
    // Check authentication before saving
    if (!await AuthGuard.checkAuth(context)) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Saving...", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );

    if (selectedDays.isEmpty) {
      final now = DateTime.now();
      const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final currentDay = weekDays[now.weekday - 1];
      selectedDays.add(currentDay);
    }

    final days = selectedDays.where((d) => d != 'Everyday').join(',');
    final time = formattedTime();
    final quantity = int.tryParse(quantityController.text) ?? 1;

    try {
      // ✅ UPDATED: Pass context to handle errors automatically
      final resp = await ApiService.post(
        '/save_schedule',
        body: {
          "container_id": widget.containerId,
          "name": labelName ?? "No name",
          "time": time,
          "days": days,
          "quantity": quantity,
        },
        context: context, // ✅ This enables automatic error dialogs
      );

      Navigator.pop(context); // Close loading dialog

      if (resp.statusCode == 200) {
        Navigator.pop(context, true); // Success - go back
      }
      // Error dialogs are handled automatically by ApiService
    } catch (e) {
      Navigator.pop(context);
      // Network errors are handled automatically by ApiService
      print('Error saving schedule: $e');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  Widget dayButton(String day, bool isDark) {
    final sel = selectedDays.contains(day);
    final bg = sel ? Colors.tealAccent : (isDark ? Colors.grey[800] : Colors.grey[300]);
    final tc = sel ? Colors.white : (isDark ? Colors.white70 : Colors.black);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () => toggleDay(day),
          child: Container(
            height: 50,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cancelColor = isDark ? Colors.grey[900] : const Color(0xFFF3533A);
    final saveColor = isDark ? Colors.grey[900] : const Color(0xFF5ACFC9);
    final cancelTextCol = isDark ? const Color(0xFFF3533A) : Colors.white;
    final saveTextCol = isDark ? const Color(0xFF5ACFC9) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('CONTAINER ${widget.containerId}', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 30, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.public),
              color: isDark ? Colors.white : Colors.black,
              onPressed: _showTimezoneDialog,
            )
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Name:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: promptLabelNameInput,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Text(
                        labelName?.isEmpty ?? true ? 'Add Label Name' : labelName!,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Time:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: showTimePickerDialog,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Text(formattedTime(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selected Timezone: $selectedTimezone',
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Days:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: ['Mon', 'Tue', 'Wed', 'Thu'].map((d) => dayButton(d, isDark)).toList()),
                  Row(children: ['Fri', 'Sat', 'Sun'].map((d) => dayButton(d, isDark)).toList()),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => toggleDay('Everyday'),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: selectedDays.contains('Everyday') ? (isDark ? Colors.grey[800] : Colors.grey[300]) : const Color(0xFFF3533A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Everyday',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: selectedDays.contains('Everyday') ? (isDark ? Colors.white70 : Colors.black) : Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Add Quantity:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline, size: 40, color: Color(0xFFF3533A)), onPressed: () => adjustQuantity(-1)),
                    SizedBox(
                      width: 120,
                      child: TextField(controller: quantityController, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24), keyboardType: TextInputType.number),
                    ),
                    IconButton(icon: const Icon(Icons.add_circle_outline, size: 40, color: Color(0xFF5ACFC9)), onPressed: () => adjustQuantity(1)),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(backgroundColor: cancelColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), padding: const EdgeInsets.symmetric(vertical: 18), side: BorderSide.none),
                  child: Text('CANCEL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cancelTextCol)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: saveSchedule,
                  style: ElevatedButton.styleFrom(backgroundColor: saveColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), padding: const EdgeInsets.symmetric(vertical: 18), side: BorderSide.none),
                  child: Text('SAVE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: saveTextCol)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}