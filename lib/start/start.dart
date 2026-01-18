import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_tools/qr_code_tools.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:Medichine/view/home.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _showScanner = false;
  bool _scanned = false;
  bool _isProcessing = false;
  String? _lastScannedCode;
  bool _flashOn = false;
  int _scanAttempts = 0;
  DateTime? _lastScanAttempt;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    controller?.resumeCamera();

    controller?.scannedDataStream.listen((scanData) {
      final code = scanData.code;
      final now = DateTime.now();

      if (code != null &&
          code.isNotEmpty &&
          !_scanned &&
          !_isProcessing &&
          _lastScannedCode != code &&
          (_lastScanAttempt == null || now.difference(_lastScanAttempt!).inMilliseconds > 500)) {

        _lastScanAttempt = now;
        _lastScannedCode = code;
        _scanAttempts++;

        print('QR detected (attempt $_scanAttempts): ${code.substring(0, code.length.clamp(0, 50))}...');
        _processQRCode(code);
      }
    });
  }

  Future<bool> _verifyBackendConfig() async {
    try {
      final res = await http.get(Uri.parse("https://Werniverse-medichine.hf.space/firebase_config"))
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['qr_config_received'] == true;
      }
    } catch (e) {
      debugPrint("❌ Failed to verify config: $e");
    }
    return false;
  }

  Future<Map<String, dynamic>> _checkDeviceAccess(String deviceId, String userEmail) async {
    try {
      final response = await http.post(
        Uri.parse('https://Werniverse-medichine.hf.space/device/check_access'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'email': userEmail,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to check device access");
      }
    } catch (e) {
      throw Exception("Connection error: $e");
    }
  }

  Future<void> _processQRCode(String? code) async {
    if (code == null || code.isEmpty || _scanned || _isProcessing) return;

    if (mounted) {
      setState(() => _isProcessing = true);
    }

    controller?.pauseCamera();

    try {
      print('Processing QR code...');

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(code);
      } catch (e) {
        throw Exception("Invalid QR Code format");
      }

      final firebaseUrl = parsed['firebase_url']?.toString().trim();
      final deviceId = parsed['device_id']?.toString().trim();
      final authToken = parsed['auth_token']?.toString().trim();

      if (firebaseUrl?.isEmpty != false ||
          deviceId?.isEmpty != false ||
          authToken?.isEmpty != false) {
        throw Exception("QR Code missing required information");
      }

      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');

      if (userEmail == null || userEmail.isEmpty) {
        throw Exception("User email not found. Please log in again.");
      }

      print('Checking device access...');

      final accessCheck = await _checkDeviceAccess(deviceId!, userEmail);

      if (accessCheck['access_granted'] != true) {
        throw Exception(accessCheck['message'] ?? "Access denied to this device");
      }

      print('Access granted, connecting to server...');

      final response = await http.post(
        Uri.parse('https://Werniverse-medichine.hf.space/register_firebase'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Connection': 'close',
        },
        body: jsonEncode({
          'firebase_url': firebaseUrl,
          'device_id': deviceId,
          'auth_token': authToken,
          'owner_email': userEmail,
        }),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException("Connection timeout - server is taking too long. Please try again."),
      );

      print('Server response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Verifying device ownership...');

        final verifyResponse = await http.post(
          Uri.parse('https://Werniverse-medichine.hf.space/device/verify_ownership'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'device_id': deviceId,
            'email': userEmail,
          }),
        ).timeout(const Duration(seconds: 10));

        if (verifyResponse.statusCode == 200) {
          final verifyData = jsonDecode(verifyResponse.body);

          if (verifyData['is_owner'] != true) {
            throw Exception(
                "Device ownership verification failed. This device is registered to a different account."
            );
          }
        } else {
          throw Exception("Failed to verify device ownership");
        }

        await Future.wait([
          prefs.setBool('firebase_connected_$userEmail', true),
          prefs.setString('firebase_config', code),
          prefs.setString('connected_device_id', deviceId),
          prefs.setString('device_owner_email', userEmail),
          prefs.setString('user_email', userEmail),
          prefs.setBool('onboarding_completed', true), // ✅ Mark onboarding complete
        ]);

        final isRegistered = await _verifyBackendConfig();

        if (!isRegistered) {
          throw Exception("❌ Device registered but backend did not confirm. Please try again.");
        }

        if (mounted) {
          setState(() {
            _scanned = true;
            _isProcessing = false;
          });

          print('✅ Connection successful, navigating to home...');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text("Connected to device: $deviceId")),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // ✅ Navigate to Home with welcome dialog on first setup
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomeScreen(showWelcome: true),
                ),
                    (route) => false, // Remove all previous routes
              );
            }
          });
        }
      } else if (response.statusCode == 403) {
        String errorMsg = "Access denied: This device is already registered to another account";
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['detail'] ?? errorMsg;
        } catch (e) {
          // Use default message
        }
        throw Exception(errorMsg);
      } else {
        String errorMsg = "Connection failed (${response.statusCode})";
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['detail'] ?? errorData['error'] ?? errorMsg;
        } catch (e) {
          // Use default message
        }
        throw Exception(errorMsg);
      }
    } on TimeoutException catch (e) {
      print('QR processing timeout: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog(
            "Connection Timeout",
            "The server is taking too long to respond. This might be due to:\n\n• Slow internet connection\n• Server is busy\n• Database is locked\n\nPlease wait a moment and try again."
        );

        _lastScannedCode = null;
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted && controller != null && _showScanner) {
            print('Resuming camera for retry...');
            controller?.resumeCamera();
          }
        });
      }
    } catch (e) {
      print('QR processing error: $e');

      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog("Connection Failed", e.toString());

        _lastScannedCode = null;
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && controller != null && _showScanner) {
            print('Resuming camera for retry...');
            controller?.resumeCamera();
          }
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();

    try {
      setState(() {
        _isProcessing = true;
        _scanned = false;
        _lastScannedCode = null;
      });

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (picked == null) {
        setState(() => _isProcessing = false);
        return;
      }

      debugPrint('✅ Image selected from gallery: ${picked.path}');
      String? qrText;

      try {
        qrText = await QrCodeToolsPlugin.decodeFrom(picked.path);
        debugPrint('✅ QR code directly decoded.');
      } catch (e) {
        debugPrint('⚠️ Direct decode failed: $e');
      }

      if (qrText == null || qrText.isEmpty) {
        try {
          final bytes = await picked.readAsBytes();
          final image = img.decodeImage(bytes);

          if (image != null) {
            var processed = image;
            if (processed.width > 800 || processed.height > 800) {
              processed = img.copyResize(
                processed,
                width: processed.width >= processed.height ? 800 : null,
                height: processed.height > processed.width ? 800 : null,
              );
            }

            processed = img.adjustColor(processed, contrast: 1.3, brightness: 1.1);

            final tempFile = File('${Directory.systemTemp.path}/temp_qr_${DateTime.now().millisecondsSinceEpoch}.png');
            await tempFile.writeAsBytes(img.encodePng(processed));

            try {
              qrText = await QrCodeToolsPlugin.decodeFrom(tempFile.path);
              debugPrint('✅ QR decoded from preprocessed image.');
            } finally {
              if (await tempFile.exists()) await tempFile.delete();
            }
          }
        } catch (e) {
          debugPrint('❌ Preprocessing failed: $e');
        }
      }

      if (qrText != null && qrText.isNotEmpty) {
        debugPrint('📦 QR content (from image): ${qrText.substring(0, qrText.length.clamp(0, 100))}');

        Map<String, dynamic> parsed;
        try {
          parsed = jsonDecode(qrText);
        } catch (_) {
          throw Exception("Invalid QR Code format");
        }

        final firebaseUrl = parsed['firebase_url']?.toString().trim();
        final deviceId = parsed['device_id']?.toString().trim();
        final authToken = parsed['auth_token']?.toString().trim();

        if (firebaseUrl?.isEmpty != false ||
            deviceId?.isEmpty != false ||
            authToken?.isEmpty != false) {
          throw Exception("QR Code missing required information");
        }

        final prefs = await SharedPreferences.getInstance();
        final userEmail = prefs.getString('user_email');

        if (userEmail == null || userEmail.isEmpty) {
          throw Exception("User email not found. Please log in again.");
        }

        final accessCheck = await _checkDeviceAccess(deviceId!, userEmail);

        if (accessCheck['access_granted'] != true) {
          throw Exception(accessCheck['message'] ?? "Access denied to this device");
        }

        final response = await http.post(
          Uri.parse('https://Werniverse-medichine.hf.space/register_firebase'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Connection': 'close',
          },
          body: jsonEncode({
            'firebase_url': firebaseUrl,
            'device_id': deviceId,
            'auth_token': authToken,
            'owner_email': userEmail,
          }),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          print('Verifying device ownership...');

          final verifyResponse = await http.post(
            Uri.parse('https://Werniverse-medichine.hf.space/device/verify_ownership'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': deviceId,
              'email': userEmail,
            }),
          ).timeout(const Duration(seconds: 10));

          if (verifyResponse.statusCode == 200) {
            final verifyData = jsonDecode(verifyResponse.body);

            if (verifyData['is_owner'] != true) {
              throw Exception(
                  "Device ownership verification failed. This device is registered to a different account."
              );
            }
          } else {
            throw Exception("Failed to verify device ownership");
          }

          await Future.wait([
            prefs.setBool('firebase_connected_$userEmail', true),
            prefs.setString('firebase_config', qrText),
            prefs.setString('connected_device_id', deviceId),
            prefs.setString('device_owner_email', userEmail),
            prefs.setBool('onboarding_completed', true), // ✅ Mark onboarding complete
          ]);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text("Connected to device: $deviceId")),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // ✅ Navigate to Home with welcome dialog
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomeScreen(showWelcome: true),
                  ),
                      (route) => false,
                );
              }
            });
          }
        } else if (response.statusCode == 403) {
          String errorMsg = "Access denied: This device is already registered to another account";
          try {
            final errorData = jsonDecode(response.body);
            errorMsg = errorData['detail'] ?? errorMsg;
          } catch (_) {}
          throw Exception(errorMsg);
        } else {
          String errorMsg = "Connection failed (${response.statusCode})";
          try {
            final errorData = jsonDecode(response.body);
            errorMsg = errorData['detail'] ?? errorData['error'] ?? errorMsg;
          } catch (_) {}
          throw Exception(errorMsg);
        }
      } else {
        throw Exception("No QR code detected in the selected image.");
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout in _pickImageFromGallery: $e');
      if (mounted) {
        _showErrorDialog(
            "Connection Timeout",
            "The server is taking too long to respond. Please wait a moment and try again."
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Error in _pickImageFromGallery: $e\n$stack');
      if (mounted) {
        _showErrorDialog("Image Processing Failed", e.toString());
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _toggleFlash() async {
    if (controller != null) {
      await controller?.toggleFlash();
      setState(() => _flashOn = !_flashOn);
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Text(
              "Scan attempts: $_scanAttempts",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_showScanner) {
                setState(() => _showScanner = false);
              }
            },
            child: const Text("CANCEL"),
          ),
          if (_showScanner)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _lastScannedCode = null;
                _scanAttempts = 0;
                controller?.resumeCamera();
              },
              child: const Text("RETRY"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _showScanner
              ? Column(
            children: [
              Expanded(
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.green,
                    borderRadius: 12,
                    borderLength: 25,
                    borderWidth: 6,
                    cutOutSize: MediaQuery.of(context).size.width * 0.65,
                  ),
                  onPermissionSet: (ctrl, p) {
                    if (!p) {
                      _showErrorDialog("Camera Permission Required",
                          "Please allow camera access to scan QR codes.");
                    }
                  },
                ),
              ),
            ],
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Image.asset('assets/med.png', height: 200),
              ),
              const SizedBox(height: 20),
              const Text(
                'Connect to MediChine',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Scan the QR code on your device to get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        label: const Text(
                          'SCAN QR CODE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5ACFC9),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide.none
                        ),
                        onPressed: () => setState(() => _showScanner = true),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library, color: Color(0xFF5ACFC9)),
                        label: const Text(
                          'UPLOAD QR IMAGE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5ACFC9),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF5ACFC9),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _pickImageFromGallery,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),

          if (_showScanner)
            Positioned(
              top: 45,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            controller?.pauseCamera();
                            setState(() => _showScanner = false);
                          },
                        ),
                        const Text(
                          'Scanning...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _flashOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFlash,
                    ),
                  ),
                ],
              ),
            ),

          if (_showScanner && !_isProcessing)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _scanAttempts > 0
                      ? 'Scanning... (${_scanAttempts} attempts)'
                      : 'Position QR code in the frame',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Connecting...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}