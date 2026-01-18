import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:Medichine/services/auth_guard.dart';
import 'package:Medichine/services/api_service.dart';

class EditScheduleScreen extends StatefulWidget {
  final int scheduleId;
  const EditScheduleScreen({super.key, required this.scheduleId});

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  final _quantityController = TextEditingController(text: '1');
  final _nameController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);
  List<String> _selectedDays = [];
  String? _labelName;
  String _selectedTimezone = 'Asia/Manila';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
    _fetchAndPopulate();
  }

  Future<void> _initializeTimezone() async {
    tz.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    _selectedTimezone = prefs.getString('timezone') ?? 'Asia/Manila';
    final now = tz.TZDateTime.now(tz.getLocation(_selectedTimezone));
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  Future<void> _fetchAndPopulate() async {
    // Check authentication first
    if (!await AuthGuard.checkAuth(context)) {
      Navigator.pop(context);
      return;
    }

    try {
      // ✅ Use ApiService - email is automatically included
      final resp = await ApiService.get('/schedule/${widget.scheduleId}');

      if (resp.statusCode != 200) {
        throw Exception('Failed to load schedule: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body);

      _labelName = data['name']?.toString() ?? '';
      _nameController.text = _labelName!;
      _quantityController.text = (data['quantity'] ?? 1).toString();

      if (data['time'] != null) {
        final parts = data['time'].toString().split(RegExp(r'[:\s]'));
        if (parts.length >= 3) {
          final h12 = int.tryParse(parts[0]) ?? 12;
          final m = int.tryParse(parts[1]) ?? 0;
          final pm = parts[2].toUpperCase() == 'PM';
          _selectedTime = TimeOfDay(hour: (h12 % 12) + (pm ? 12 : 0), minute: m);
        }
      }

      final days = data['days']?.toString() ?? '';
      _selectedDays = days.isEmpty
          ? []
          : days.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Failed to load schedule: $e');
      if (mounted) {
        _showErrorDialog('Failed to load schedule.\nPlease check your connection.');
        Navigator.pop(context);
      }
    }
  }

  String get _formattedTime {
    final h = _selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod;
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    final p = _selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
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
              final formatted = TimeOfDay.fromDateTime(localTime).format(context);
              final isSelected = zone == _selectedTimezone;

              return ListTile(
                leading: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.teal)
                    : const Icon(Icons.circle_outlined),
                title: Text(zone),
                subtitle: Text('Current time: $formatted'),
                tileColor: isSelected ? Colors.teal.withOpacity(0.1) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('timezone', zone);
                  final newNow = tz.TZDateTime.now(location);
                  setState(() {
                    _selectedTimezone = zone;
                    _selectedTime = TimeOfDay(hour: newNow.hour, minute: newNow.minute);
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

  void _toggleDay(String day) {
    setState(() {
      if (day == 'Everyday') {
        if (_selectedDays.contains('Everyday')) {
          _selectedDays.clear();
        } else {
          _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Everyday'];
        }
      } else {
        _selectedDays.remove('Everyday');
        if (_selectedDays.contains(day)) {
          _selectedDays.remove(day);
        } else {
          _selectedDays.add(day);
          if (['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].every((d) => _selectedDays.contains(d))) {
            _selectedDays.add('Everyday');
          }
        }
      }
    });
  }

  Future<void> _promptLabelNameInput() async {
    _nameController.text = _labelName ?? '';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Label Name'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'NAME'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              setState(() => _labelName = _nameController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _adjustQuantity(int delta) {
    final curr = int.tryParse(_quantityController.text) ?? 1;
    _quantityController.text = (curr + delta).clamp(1, 10).toString();
  }

  Future<void> _updateSchedule() async {
    // Check authentication before updating
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
            Text("Updating...", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );

    // Handle empty days case
    final daysToSend = _selectedDays.isEmpty
        ? [_weekdayAbbrev(DateTime.now())]
        : _selectedDays;

    try {
      // ✅ Use ApiService - email is automatically included
      final resp = await ApiService.put(
        '/update_schedule/${widget.scheduleId}',
        body: {
          'container_id': 0, // Keep existing container_id
          'name': _labelName ?? 'No name',
          'time': _formattedTime,
          'days': daysToSend.where((d) => d != 'Everyday').join(','),
          'quantity': int.tryParse(_quantityController.text) ?? 1,
        },
      );

      Navigator.pop(context); // Close loading dialog

      if (resp.statusCode == 200) {
        Navigator.pop(context, true); // Return to previous screen with success
      } else {
        _showErrorDialog('Failed to update schedule.\nCheck your internet connection.');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (e.toString().contains('User email not found')) {
        _showErrorDialog('Session expired. Please log in again.');
      } else {
        _showErrorDialog('Failed to connect.\nCheck your internet connection.');
      }
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  String _weekdayAbbrev(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday: return 'Mon';
      case DateTime.tuesday: return 'Tue';
      case DateTime.wednesday: return 'Wed';
      case DateTime.thursday: return 'Thu';
      case DateTime.friday: return 'Fri';
      case DateTime.saturday: return 'Sat';
      case DateTime.sunday: return 'Sun';
      default: return '';
    }
  }

  Widget _dayButton(String day, bool isDark) {
    final sel = _selectedDays.contains(day);
    final bg = sel ? const Color(0xFF5ACFC9) : (isDark ? Colors.grey[800] : Colors.grey[300]);
    final tc = sel ? Colors.white : (isDark ? Colors.white70 : Colors.black);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: InkWell(
          onTap: () => _toggleDay(day),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc)),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cancelColor = isDark ? Colors.grey[900]! : const Color(0xFFF3533A);
    final saveColor = isDark ? Colors.grey[900]! : const Color(0xFF5ACFC9);
    final cancelText = isDark ? const Color(0xFFF3533A) : Colors.white;
    final saveText = isDark ? const Color(0xFF5ACFC9) : Colors.white;

    // Show loading indicator while fetching data
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('EDIT SCHEDULE', style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: BackButton(color: textColor),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('EDIT SCHEDULE', style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.public),
              color: textColor,
              onPressed: _showTimezoneDialog,
            )
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: BackButton(color: textColor),
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
                    onTap: _promptLabelNameInput,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _labelName?.isEmpty ?? true ? 'Add Label Name' : _labelName!,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Time:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(_formattedTime, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selected Timezone: $_selectedTimezone',
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Days:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 8),
                  Row(children: ['Mon', 'Tue', 'Wed', 'Thu'].map((d) => _dayButton(d, isDark)).toList()),
                  Row(children: ['Fri', 'Sat', 'Sun'].map((d) => _dayButton(d, isDark)).toList()),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _toggleDay('Everyday'),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: _selectedDays.contains('Everyday') ? (isDark ? Colors.grey[800] : Colors.grey[300]) : const Color(0xFFF3533A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Everyday',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: _selectedDays.contains('Everyday') ? (isDark ? Colors.white70 : Colors.black) : Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Add Quantity:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline, size: 40, color: Color(0xFFF3533A)), onPressed: () => _adjustQuantity(-1)),
                    SizedBox(
                      width: 120,
                      child: TextField(controller: _quantityController, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24), keyboardType: TextInputType.number),
                    ),
                    IconButton(icon: const Icon(Icons.add_circle_outline, size: 40, color: Color(0xFF5ACFC9)), onPressed: () => _adjustQuantity(1)),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(backgroundColor: cancelColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), padding: const EdgeInsets.symmetric(vertical: 18), side: BorderSide.none),
                    child: Text('CANCEL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cancelText)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateSchedule,
                    style: ElevatedButton.styleFrom(backgroundColor: saveColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), padding: const EdgeInsets.symmetric(vertical: 18), side: BorderSide.none),
                    child: Text('EDIT', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: saveText)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}