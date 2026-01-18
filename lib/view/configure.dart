import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:Medichine/services/auth_guard.dart';
import 'package:Medichine/services/api_service.dart';

class ConfigureScreen extends StatelessWidget {
  const ConfigureScreen({super.key});

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.transparent : Colors.transparent;
    final iconColor = isDark ? Colors.white70 : Colors.black87;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTimezoneDialog(BuildContext context) async {
    // Check authentication first
    if (!await AuthGuard.checkAuth(context)) return;

    tz.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    String currentSaved = prefs.getString('timezone') ?? 'Asia/Manila';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snackBarColor = isDark ? Colors.grey[900] : Colors.grey[200];
    final snackBarTextColor = isDark ? Colors.white : Colors.black;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                final formattedTime = TimeOfDay(
                  hour: localTime.hour,
                  minute: localTime.minute,
                ).format(context);

                final isSelected = zone == currentSaved;
                final isDefault = zone == 'Asia/Manila';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF5ACFC9).withOpacity(0.1)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? const Color(0xFF5ACFC9)
                          : Theme.of(context).iconTheme.color,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text(zone)),
                        if (isDefault)
                          const Text(
                            '(DEFAULT)',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text('Current time: $formattedTime'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const AlertDialog(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          content: Center(child: CircularProgressIndicator()),
                        ),
                      );

                      try {
                        // ✅ Pass context for automatic error handling
                        final response = await ApiService.post(
                          '/update_timezone',
                          body: {'timezone': zone},
                          context: context,
                        );

                        if (context.mounted) {
                          Navigator.pop(context); // close progress dialog
                        }

                        if (response.statusCode == 200) {
                          await prefs.setString('timezone', zone);
                          setState(() {
                            currentSaved = zone;
                          });

                          if (context.mounted) {
                            Navigator.pop(context); // close timezone dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Timezone set to $zone",
                                  style: TextStyle(color: snackBarTextColor),
                                ),
                                backgroundColor: snackBarColor,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                        // Errors are handled automatically
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // close progress dialog
                        }
                        print('Error setting timezone: $e');
                      }
                    },

                  ),
                );
              },
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _showMessageDialog(BuildContext context) async {
    // Check authentication first
    if (!await AuthGuard.checkAuth(context)) return;

    final TextEditingController dispensingController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snackBarColor = isDark ? Colors.grey[900] : Colors.grey[200];
    final snackBarTextColor = isDark ? Colors.white : Colors.black;

    // Load existing message
    final prefs = await SharedPreferences.getInstance();
    dispensingController.text = prefs.getString('dispensing_message') ?? '';

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Message Settings'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'For Custom Notifications',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: dispensingController,
                    minLines: 3,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      hintText: "Enter message for notification...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Show progress dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AlertDialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    content: Center(child: CircularProgressIndicator()),
                  ),
                );

                final String dispensingText = dispensingController.text.trim();
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setString('dispensing_message', dispensingText);

                try {
                  // ✅ UPDATED: Use ApiService instead of direct http call
                  final resp = await ApiService.post(
                    '/update_dispensing_message',
                    body: {'dispensing_message': dispensingText},
                  );

                  if (context.mounted) Navigator.pop(context); // Close loader
                  if (context.mounted) Navigator.pop(context); // Close dialog

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          resp.statusCode == 200
                              ? 'Notification message successfully edited.'
                              : 'Saved locally, but failed to update server.',
                          style: TextStyle(color: snackBarTextColor),
                        ),
                        backgroundColor: snackBarColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) Navigator.pop(context); // Close loader
                  if (context.mounted) Navigator.pop(context); // Close dialog

                  if (context.mounted) {
                    // ✅ Better error handling
                    String errorMessage = "Failed to update message";
                    if (e.toString().contains('User email not found')) {
                      errorMessage = "Session expired. Please log in again.";
                    } else if (e.toString().contains('Access denied')) {
                      errorMessage = "Access denied. Please reconnect device.";
                    } else {
                      errorMessage = "Saved locally, but failed to update server.";
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          errorMessage,
                          style: TextStyle(color: snackBarTextColor),
                        ),
                        backgroundColor: snackBarColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'SAVE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTestingDialog(BuildContext context) async {
    // Check authentication first
    if (!await AuthGuard.checkAuth(context)) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snackBarColor = isDark ? Colors.grey[900] : Colors.grey[200];
    final snackBarTextColor = isDark ? Colors.white : Colors.black;

    // ✅ UPDATED: sendTestCommand function with ApiService
    Future<void> sendTestCommand(int containerId) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Center(child: CircularProgressIndicator()),
        ),
      );

      try {
        // ✅ UPDATED: Use ApiService with container_id in body
        final response = await ApiService.post(
          '/test_command',
          body: {'container_id': containerId},
        );

        if (context.mounted) {
          Navigator.pop(context); // close loading
        }

        final success = response.statusCode == 200;
        final message = success
            ? 'Command sent to container $containerId'
            : 'Failed to send command to container $containerId (${response.statusCode})';

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message,
                style: TextStyle(color: snackBarTextColor),
              ),
              backgroundColor: snackBarColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);

          // ✅ Better error handling
          String errorMessage = "Error: $e";
          if (e.toString().contains('User email not found')) {
            errorMessage = "Session expired. Please log in again.";
          } else if (e.toString().contains('Access denied')) {
            errorMessage = "Access denied. Please reconnect device.";
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                style: TextStyle(color: snackBarTextColor),
              ),
              backgroundColor: snackBarColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    ButtonStyle buttonStyle(Color bgColor) {
      return ButtonStyle(
        backgroundColor: WidgetStateProperty.all(
          isDark ? Colors.transparent : bgColor,
        ),
        foregroundColor: WidgetStateProperty.all(
          isDark ? bgColor : Colors.white,
        ),
        minimumSize: WidgetStateProperty.all(
          const Size(double.infinity, 50),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        side: WidgetStateProperty.all(BorderSide.none),
      );
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48),
            SizedBox(height: 8),
            Text('Test Containers', textAlign: TextAlign.center),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: buttonStyle(const Color(0xFF5ACFC9)),
                onPressed: () => sendTestCommand(1),
                child: const Text('Container 1'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: buttonStyle(const Color(0xFF8AD879)),
                onPressed: () => sendTestCommand(2),
                child: const Text('Container 2'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: buttonStyle(const Color(0xFFFA9F42)),
                onPressed: () => sendTestCommand(3),
                child: const Text('Container 3'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: buttonStyle(const Color(0xFFF3533A)),
                onPressed: () => sendTestCommand(4),
                child: const Text('Container 4'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.titleLarge?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'CONFIGURE',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              _buildTile(
                context: context,
                icon: Icons.public,
                label: 'TIMEZONE',
                onTap: () => _showTimezoneDialog(context),
              ),
              const SizedBox(height: 16),
              _buildTile(
                context: context,
                icon: Icons.message,
                label: 'MESSAGE',
                onTap: () => _showMessageDialog(context),
              ),
              const SizedBox(height: 16),
              _buildTile(
                context: context,
                icon: Icons.bug_report,
                label: 'TESTING',
                onTap: () => _showTestingDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}