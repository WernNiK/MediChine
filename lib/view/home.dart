import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'tutorial.dart';
import 'history.dart';
import 'schedule.dart';
import 'package:Medichine/services/auth_guard.dart';
import 'package:Medichine/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  final bool showWelcome; // NEW: Add parameter to control welcome dialog

  const HomeScreen({super.key, this.showWelcome = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  String _userName = 'User';
  bool _hasShownWelcome = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.currentUser;
      if (mounted) {
        setState(() {
          _userName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
        });

        // Only show welcome dialog if explicitly requested (from login/signup)
        if (widget.showWelcome && !_hasShownWelcome) {
          _hasShownWelcome = true;
          _showWelcomeDialog();
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted && widget.showWelcome && !_hasShownWelcome) {
        _hasShownWelcome = true;
        _showWelcomeDialog();
      }
    }
  }

  void _showWelcomeDialog() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bgColor = Theme.of(context).scaffoldBackgroundColor;

      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.3),
        builder: (dialogContext) {
          Future.delayed(const Duration(seconds: 5), () {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          });

          return GestureDetector(
            onTap: () {
              Navigator.of(dialogContext).pop();
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                },
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🤗',
                        style: TextStyle(
                          fontSize: 120,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Hello, $_userName!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome to MediChine',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap anywhere to continue',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black45,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildContainerTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: SizedBox(
        height: 130,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.grey[900] : color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide.none,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: isDark ? color : Colors.white),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? color : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContainerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'SELECT CONTAINER',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildContainerTile(
                      context: context,
                      icon: Icons.inventory_2_outlined,
                      label: 'CONTAINER 1',
                      color: const Color(0xFF5ACFC9),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScheduleScreen(containerId: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildContainerTile(
                      context: context,
                      icon: Icons.inventory_2_outlined,
                      label: 'CONTAINER 2',
                      color: const Color(0xFF8AD879),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScheduleScreen(containerId: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildContainerTile(
                      context: context,
                      icon: Icons.inventory_2_outlined,
                      label: 'CONTAINER 3',
                      color: const Color(0xFFFA9F42),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScheduleScreen(containerId: 3),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildContainerTile(
                      context: context,
                      icon: Icons.inventory_2_outlined,
                      label: 'CONTAINER 4',
                      color: const Color(0xFFF3533A),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScheduleScreen(containerId: 4),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final titleColor = Theme.of(context).textTheme.titleLarge?.color;

    const scheduleColor = Color(0xFF5ACFC9);
    const historyColor = Color(0xFF8AD879);
    const tutorialColor = Color(0xFFFA9F42);
    const settingsColor = Color(0xFFF3533A);

    AspectRatio customButton({
      required VoidCallback onPressed,
      required Widget child,
      required Color color,
      required double aspectRatio,
    }) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.grey[900] : color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide.none,
          ),
          child: child,
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/med.png', width: 100, height: 100),
                const SizedBox(height: 5),
                Text(
                  'MediChine',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    fontFamily: "Times new roman",
                  ),
                ),
                const SizedBox(height: 5),

                customButton(
                  aspectRatio: 2,
                  color: scheduleColor,
                  onPressed: () {
                    _showContainerDialog(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month,
                          size: 80,
                          color: isDark ? scheduleColor : Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        'SET SCHEDULE',
                        style: TextStyle(
                          color: isDark ? scheduleColor : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: customButton(
                        aspectRatio: 1,
                        color: historyColor,
                        onPressed: () async {
                          final isAuthenticated = await AuthGuard.checkAuth(context);

                          if (!context.mounted) return;

                          if (isAuthenticated) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HistoryScreen(),
                              ),
                            );
                          }
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history,
                                size: 80,
                                color: isDark ? historyColor : Colors.white),
                            const SizedBox(height: 10),
                            Text(
                              'HISTORY',
                              style: TextStyle(
                                color: isDark ? historyColor : Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: customButton(
                        aspectRatio: 1,
                        color: tutorialColor,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorialScreen(),
                            ),
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school,
                                size: 80,
                                color: isDark ? tutorialColor : Colors.white),
                            const SizedBox(height: 10),
                            Text(
                              'TUTORIALS',
                              style: TextStyle(
                                color: isDark ? tutorialColor : Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                customButton(
                  aspectRatio: 2,
                  color: settingsColor,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SETTINGS  ',
                        style: TextStyle(
                          color: isDark ? settingsColor : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.settings,
                          size: 90,
                          color: isDark ? settingsColor : Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}