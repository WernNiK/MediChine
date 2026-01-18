import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This service handles app lifecycle events
/// Note: Android/iOS automatically clears SharedPreferences on uninstall
/// This class provides additional manual cleanup if needed
class AppLifecycleHandler extends WidgetsBindingObserver {
  static final AppLifecycleHandler _instance = AppLifecycleHandler._internal();

  factory AppLifecycleHandler() => _instance;

  AppLifecycleHandler._internal();

  /// Initialize lifecycle observer
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Cleanup when app is disposed
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
      // App is in foreground
        _checkAuthExpiry();
        break;
      case AppLifecycleState.paused:
      // App is in background
        break;
      case AppLifecycleState.inactive:
      // App is inactive
        break;
      case AppLifecycleState.detached:
      // App is detached (being closed)
        break;
      case AppLifecycleState.hidden:
      // App is hidden
        break;
    }
  }

  /// Check if user needs to re-authenticate
  Future<void> _checkAuthExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (isLoggedIn) {
      final lastLoginTimestamp = prefs.getInt('last_login_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final weekInMillis = 7 * 24 * 60 * 60 * 1000;

      // If more than a week has passed, mark as logged out
      if ((now - lastLoginTimestamp) > weekInMillis) {
        await prefs.setBool('is_logged_in', false);
        await prefs.remove('last_login_timestamp');
      }
    }
  }

  /// Manual cleanup method (if needed for testing or specific scenarios)
  /// Note: On actual uninstall, the OS automatically clears app data
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Clear only authentication data (keep QR and other settings)
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('last_login_timestamp');
  }
}