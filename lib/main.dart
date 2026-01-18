import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Medichine/view/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:Medichine/view/home.dart';
import 'package:Medichine/start/login.dart';
import 'package:Medichine/start/start.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase already initialized: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'MediChine',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  side: const BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            home: const InitialScreen(),
          );
        },
      ),
    );
  }
}

class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  Future<Map<String, dynamic>> _checkAppStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if app has been opened before (onboarding completed)
    final hasCompletedOnboarding = prefs.getBool('onboarding_completed') ?? false;

    // Check login status
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final lastLoginTimestamp = prefs.getInt('last_login_timestamp') ?? 0;

    // Check QR connection status
    final userEmail = prefs.getString('user_email') ?? '';
    final isQRConnected = prefs.getBool('firebase_connected_$userEmail') ?? false;

    // Check if a week (7 days) has passed since last login
    final now = DateTime.now().millisecondsSinceEpoch;
    final weekInMillis = 7 * 24 * 60 * 60 * 1000;
    final needsReLogin = (now - lastLoginTimestamp) > weekInMillis;

    return {
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'isLoggedIn': isLoggedIn && !needsReLogin,
      'isQRConnected': isQRConnected,
      'needsReLogin': needsReLogin,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkAppStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final hasCompletedOnboarding = data['hasCompletedOnboarding'] ?? false;
        final isLoggedIn = data['isLoggedIn'] ?? false;
        final isQRConnected = data['isQRConnected'] ?? false;
        final needsReLogin = data['needsReLogin'] ?? false;

        // Show message if needs re-login due to week passing
        if (needsReLogin && context.mounted) {
          Future.delayed(Duration.zero, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('For security, please log in again'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          });
        }

        // FIRST INSTALL FLOW: Login → QR Scan → Home
        if (!hasCompletedOnboarding) {
          if (!isLoggedIn) {
            // Step 1: Show Login
            return const LoginScreen();
          } else if (!isQRConnected) {
            // Step 2: Show QR Scanner (first time setup)
            return const QRScannerWelcomeScreen();
          } else {
            // Step 3: Mark onboarding complete and go to Home
            _completeOnboarding();
            return const HomeScreen(showWelcome: true);
          }
        }

        // SUBSEQUENT OPENS: Direct to Home if logged in
        return isLoggedIn ? const HomeScreen() : const LoginScreen();
      },
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }
}

// NEW: Welcome screen for first-time QR setup
class QRScannerWelcomeScreen extends StatelessWidget {
  const QRScannerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation during onboarding
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Image.asset('assets/med.png', height: 120),
                const SizedBox(height: 32),
                const Text(
                  'One More Step!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connect your MediChine device by scanning its QR code',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5ACFC9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF5ACFC9).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5ACFC9),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '1',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Power on your MediChine device',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5ACFC9),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '2',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Find the QR code on the device',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5ACFC9),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Scan the QR code with this app',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QrScannerScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5ACFC9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'SCAN QR CODE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}