import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class AuthGuard {
  static final AuthService _authService = AuthService();

  /// Check if user is logged in AND has scanned QR code before allowing API requests
  static Future<bool> checkAuth(BuildContext context) async {
    final isLoggedIn = await _authService.isLoggedIn;

    if (!isLoggedIn) {
      if (context.mounted) {
        _showLoginRequiredDialog(context);
      }
      return false;
    }

    // Check if QR code has been scanned for this user
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email');
    final isQRScanned = prefs.getBool('firebase_connected_$userEmail') ?? false;

    if (!isQRScanned) {
      if (context.mounted) {
        _showQRNotScannedDialog(context);
      }
      return false;
    }

    return true;
  }

  /// Show dialog prompting user to log in
  static void _showLoginRequiredDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: isDark ? Colors.orangeAccent : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('Login Required'),
          ],
        ),
        content: const Text(
          'You need to log in before using this feature.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog prompting user to scan QR code
  static void _showQRNotScannedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Color(0xFF5ACFC9), size: 32),
            SizedBox(width: 8),
            Expanded(child: Text('QR Code Not Scanned')),
          ],
        ),
        content: const Text(
          'Please scan the QR code first to connect your device.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Show snackbar for auth error
  static void showAuthError(BuildContext context, {bool isQRError = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snackBarColor = isDark ? Colors.grey[900] : Colors.grey[200];
    final snackBarTextColor = isDark ? Colors.white : Colors.black;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isQRError
              ? 'Please scan the QR code to connect your device'
              : 'Please log in to use this feature',
          style: TextStyle(color: snackBarTextColor),
        ),
        backgroundColor: snackBarColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}