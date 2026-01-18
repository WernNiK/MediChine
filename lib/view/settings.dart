import 'dart:io';
import 'package:Medichine/view/configure.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'about.dart';
import 'contact.dart';
import 'theme.dart';
import '../start/login.dart';
import 'profile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String _userName = 'User';
  String _userEmail = '';
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final user = await _authService.currentUser;
      final prefs = await SharedPreferences.getInstance();

      // Use email-specific key for profile image (same as ProfileScreen)
      final userEmail = user?.email ?? '';
      final imagePath = prefs.getString('profile_image_$userEmail');

      if (mounted) {
        setState(() {
          _isLoggedIn = user != null;
          _userName = user?.displayName ?? 'User';
          _userEmail = userEmail;
          _profileImagePath = imagePath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildProfileAvatar({required bool isDark}) {
    if (_profileImagePath != null && File(_profileImagePath!).existsSync()) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: FileImage(File(_profileImagePath!)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Icon(
        Icons.account_circle,
        size: 60,
        color: isDark ? const Color(0xFF5ACFC9) : Colors.white,
      );
    }
  }

  Widget _buildTile({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      height: 140,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.grey[900] : color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide.none,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: 50, color: isDark ? color : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isDark ? color : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SETTINGS',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge!.color,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              // Profile Section - Clickable and refreshes on return
              InkWell(
                onTap: _isLoggedIn
                    ? () async {
                  // Navigate to ProfileScreen and refresh when returning
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                  // Refresh profile data when coming back
                  _checkAuthStatus();
                }
                    : () async {
                  // Navigate to LoginScreen
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  // Refresh after login
                  _checkAuthStatus();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : const Color(0xFF5ACFC9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isLoading
                      ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                      : _isLoggedIn
                      ? Row(
                    children: [
                      _buildProfileAvatar(isDark: isDark),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFF5ACFC9)
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF5ACFC9)
                                    .withOpacity(0.8)
                                    : Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: isDark
                            ? const Color(0xFF5ACFC9)
                            : Colors.white,
                      ),
                    ],
                  )
                      : Row(
                    children: [
                      Icon(
                        Icons.account_circle,
                        size: 60,
                        color: isDark
                            ? const Color(0xFF5ACFC9)
                            : Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Not Logged In',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFF5ACFC9)
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to login or sign up',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF5ACFC9)
                                    .withOpacity(0.8)
                                    : Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: isDark
                            ? const Color(0xFF5ACFC9)
                            : Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildTile(
                context: context,
                color: const Color(0xFF5ACFC9),
                icon: isDark ? Icons.light_mode : Icons.dark_mode,
                label: 'PREFERENCES',
                onTap: () {
                  themeProvider.toggleTheme();
                },
              ),
              const SizedBox(height: 16),
              _buildTile(
                context: context,
                color: const Color(0xFF8AD879),
                icon: Icons.info,
                label: 'ABOUT',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildTile(
                context: context,
                color: const Color(0xFFFA9F42),
                icon: Icons.contact_mail,
                label: 'CONTACT US',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildTile(
                context: context,
                color: const Color(0xFFF3533A),
                icon: Icons.settings,
                label: 'CONFIGURE',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConfigureScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}