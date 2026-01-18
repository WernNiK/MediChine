import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Medichine/services/auth_service.dart';
import 'package:Medichine/start/login.dart';
import 'package:Medichine/start/start.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = true;
  String _userName = 'User';
  String _userEmail = '';
  String? _profileImagePath;
  bool _isQRConnected = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.currentUser;
      final prefs = await SharedPreferences.getInstance();

      // ✅ FIX: Get email from Firebase first, then sync to SharedPreferences
      final firebaseEmail = user?.email ?? '';
      final storedEmail = prefs.getString('user_email');

      // ✅ CRITICAL: Ensure SharedPreferences email matches Firebase
      if (firebaseEmail.isNotEmpty && firebaseEmail != storedEmail) {
        debugPrint('⚠️ Email mismatch detected. Syncing...');
        debugPrint('   Firebase: $firebaseEmail');
        debugPrint('   Stored: $storedEmail');
        await prefs.setString('user_email', firebaseEmail.toLowerCase().trim());
      }

      final userEmail = firebaseEmail;
      final imagePath = prefs.getString('profile_image_$userEmail');

      // Verify device ownership
      bool qrConnected = false;
      final storedDeviceId = prefs.getString('connected_device_id');
      final deviceOwnerEmail = prefs.getString('device_owner_email');

      if (storedDeviceId != null &&
          deviceOwnerEmail != null &&
          deviceOwnerEmail == userEmail) {

        try {
          final response = await http.post(
            Uri.parse('https://Werniverse-medichine.hf.space/device/verify_ownership'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': storedDeviceId,
              'email': userEmail,
            }),
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            qrConnected = data['is_owner'] == true;

            if (!qrConnected) {
              debugPrint('⚠️ User is no longer the owner. Clearing connection.');
              await prefs.remove('firebase_connected_$userEmail');
              await prefs.remove('firebase_config');
              await prefs.remove('connected_device_id');
              await prefs.remove('device_owner_email');
            } else {
              debugPrint('✅ Device ownership verified for $userEmail');
            }
          }
        } catch (e) {
          debugPrint('Failed to verify device ownership: $e');
          qrConnected = false;
        }
      } else if (storedDeviceId != null && deviceOwnerEmail != userEmail) {
        debugPrint('⚠️ Email mismatch. Current: $userEmail, Owner: $deviceOwnerEmail');
        await prefs.remove('firebase_connected_$userEmail');
      }

      if (mounted) {
        setState(() {
          _userName = user?.displayName ?? 'User';
          _userEmail = userEmail;
          _profileImagePath = imagePath;
          _isQRConnected = qrConnected;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_$_userEmail', image.path);

        if (mounted) {
          setState(() {
            _profileImagePath = image.path;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_image_$_userEmail');

      if (mounted) {
        setState(() {
          _profileImagePath = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.grey[400]),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            if (_profileImagePath != null)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.grey[400]),
                title: const Text('Remove picture'),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfilePicture();
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDisconnect() async {
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Device'),
        content: const Text(
          'Are you sure you want to disconnect this device? You can reconnect later by scanning the QR code again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDisconnect == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final deviceId = prefs.getString('connected_device_id') ?? '';
        final userEmail = prefs.getString('user_email') ?? '';

        if (deviceId.isEmpty || userEmail.isEmpty) {
          throw Exception('Device or email information not found');
        }

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Disconnecting...'),
                ],
              ),
            ),
          );
        }

        final response = await http.post(
          Uri.parse('https://Werniverse-medichine.hf.space/device/disconnect'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'device_id': deviceId,
            'owner_email': userEmail,
          }),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Connection timeout'),
        );

        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (response.statusCode == 200) {
          await prefs.remove('firebase_connected_$userEmail');
          await prefs.remove('firebase_config');
          await prefs.remove('connected_device_id');
          await prefs.remove('device_owner_email');

          if (mounted) {
            setState(() {
              _isQRConnected = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Device disconnected successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          String errorMsg = 'Failed to disconnect device';
          try {
            final errorData = jsonDecode(response.body);
            errorMsg = errorData['detail'] ?? errorData['message'] ?? errorMsg;
          } catch (e) {
            errorMsg = 'Server error: ${response.statusCode}';
          }
          throw Exception(errorMsg);
        }
      } on TimeoutException catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection timeout. Please check your internet and try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email') ?? '';

      // ✅ FIX: Clear connection data for this user
      if (userEmail.isNotEmpty) {
        await prefs.remove('firebase_connected_$userEmail');
      }

      // Clear device connection data
      final deviceOwnerEmail = prefs.getString('device_owner_email');
      if (deviceOwnerEmail == userEmail) {
        debugPrint('🔌 Current user is device owner. Clearing device data.');
        await prefs.remove('connected_device_id');
        await prefs.remove('firebase_config');
        await prefs.remove('device_owner_email');
      } else {
        debugPrint('ℹ️ Current user is not device owner. Preserving device data.');
      }

      // ✅ CRITICAL FIX: Clear user_email LAST, after using it above
      await prefs.remove('user_email');
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('last_login_timestamp');

      // Sign out from Firebase
      await _authService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'PROFILE',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge!.color,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: _showImageOptions,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : const Color(0xFF5ACFC9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        image: _profileImagePath != null
                            ? DecorationImage(
                          image: FileImage(File(_profileImagePath!)),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: _profileImagePath == null
                          ? Icon(
                        Icons.person,
                        size: 60,
                        color: isDark ? const Color(0xFF5ACFC9) : Colors.white,
                      )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImageOptions,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5ACFC9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                context: context,
                title: 'Name',
                value: _userName,
                icon: Icons.person_outline,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                context: context,
                title: 'Email',
                value: _userEmail,
                icon: Icons.email_outlined,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildConnectionCard(
                context: context,
                isDark: isDark,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3533A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide.none,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'LOGOUT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : const Color(0xFF5ACFC9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF5ACFC9),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard({
    required BuildContext context,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : const Color(0xFF5ACFC9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isQRConnected ? Icons.check_circle : Icons.qr_code_scanner,
                  color: _isQRConnected ? Colors.green : const Color(0xFF5ACFC9),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Connection',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isQRConnected ? 'Connected' : 'Not Connected',
                      style: TextStyle(
                        fontSize: 16,
                        color: _isQRConnected
                            ? Colors.green
                            : (isDark ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QrScannerScreen(),
                  ),
                );
                await _loadUserData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5ACFC9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide.none,
              ),
              icon: Icon(
                _isQRConnected ? Icons.sync : Icons.qr_code_scanner,
                color: Colors.white,
              ),
              label: Text(
                _isQRConnected ? 'CONNECT TO A NEW DEVICE' : 'CONNECT DEVICE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_isQRConnected) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleDisconnect,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Color(0xFFF3533A),
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(
                  Icons.link_off,
                  color: Color(0xFFF3533A),
                ),
                label: const Text(
                  'DISCONNECT DEVICE',
                  style: TextStyle(
                    color: Color(0xFFF3533A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}