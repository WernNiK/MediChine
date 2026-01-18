import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ApiService {
  static const String baseUrl = 'https://Werniverse-medichine.hf.space';

  /// Get user email from SharedPreferences
  static Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  /// Show error dialog with proper message
  static Future<void> _showErrorDialog(BuildContext context, String title, String message) async {
    if (!context.mounted) return;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Handle API errors and show appropriate dialogs
  static Future<void> _handleError(BuildContext? context, http.Response response) async {
    if (context == null || !context.mounted) return;

    try {
      final errorData = json.decode(response.body);
      final detail = errorData['detail'] ?? 'Unknown error';
      final errorCode = errorData['error_code'];

      switch (response.statusCode) {
        case 403:
          if (errorCode == 'UNAUTHORIZED_ACCESS') {
            await _showErrorDialog(
              context,
              'Access Denied',
              'This device is registered to another account.\n\n$detail',
            );
          } else if (detail.contains('disconnected')) {
            await _showErrorDialog(
              context,
              'Device Disconnected',
              'Your device has been disconnected. Please reconnect by scanning the QR code again.',
            );
          } else {
            await _showErrorDialog(
              context,
              'Access Denied',
              detail,
            );
          }
          break;

        case 400:
          if (errorCode == 'EMAIL_REQUIRED') {
            await _showErrorDialog(
              context,
              'Session Error',
              'Your session has expired. Please log in again.',
            );
          } else if (errorCode == 'INVALID_EMAIL') {
            await _showErrorDialog(
              context,
              'Invalid Email',
              'Your email format is invalid. Please log in again.',
            );
          } else {
            await _showErrorDialog(
              context,
              'Invalid Request',
              detail,
            );
          }
          break;

        case 404:
          await _showErrorDialog(
            context,
            'Not Found',
            'The requested resource was not found.',
          );
          break;

        case 500:
          await _showErrorDialog(
            context,
            'Server Error',
            'An internal server error occurred. Please try again later.',
          );
          break;

        default:
          await _showErrorDialog(
            context,
            'Error',
            'An unexpected error occurred: $detail',
          );
      }
    } catch (e) {
      // If response is not JSON
      await _showErrorDialog(
        context,
        'Error',
        'An unexpected error occurred (${response.statusCode})',
      );
    }
  }

  /// GET request with email automatically included
  static Future<http.Response> get(
      String endpoint, {
        BuildContext? context,
        Map<String, String>? additionalParams,
      }) async {
    final email = await _getUserEmail();
    if (email == null) {
      throw Exception('User email not found. Please log in.');
    }

    final params = {'email': email};
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: params);

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200 && context != null) {
        await _handleError(context, response);
      }

      return response;
    } catch (e) {
      if (context != null && context.mounted) {
        await _showErrorDialog(
          context,
          'Connection Error',
          'Failed to connect to the server. Please check your internet connection.',
        );
      }
      rethrow;
    }
  }

  /// POST request with email automatically included
  static Future<http.Response> post(
      String endpoint, {
        required Map<String, dynamic> body,
        BuildContext? context,
      }) async {
    final email = await _getUserEmail();
    if (email == null) {
      throw Exception('User email not found. Please log in.');
    }

    // Add email to body
    final bodyWithEmail = {...body, 'email': email};

    final uri = Uri.parse('$baseUrl$endpoint');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bodyWithEmail),
      );

      if (response.statusCode != 200 && context != null) {
        await _handleError(context, response);
      }

      return response;
    } catch (e) {
      if (context != null && context.mounted) {
        await _showErrorDialog(
          context,
          'Connection Error',
          'Failed to connect to the server. Please check your internet connection.',
        );
      }
      rethrow;
    }
  }

  /// PUT request with email automatically included
  static Future<http.Response> put(
      String endpoint, {
        required Map<String, dynamic> body,
        BuildContext? context,
      }) async {
    final email = await _getUserEmail();
    if (email == null) {
      throw Exception('User email not found. Please log in.');
    }

    final bodyWithEmail = {...body, 'email': email};
    final uri = Uri.parse('$baseUrl$endpoint');

    try {
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bodyWithEmail),
      );

      if (response.statusCode != 200 && context != null) {
        await _handleError(context, response);
      }

      return response;
    } catch (e) {
      if (context != null && context.mounted) {
        await _showErrorDialog(
          context,
          'Connection Error',
          'Failed to connect to the server. Please check your internet connection.',
        );
      }
      rethrow;
    }
  }

  /// DELETE request with email automatically included
  static Future<http.Response> delete(
      String endpoint, {
        BuildContext? context,
      }) async {
    final email = await _getUserEmail();
    if (email == null) {
      throw Exception('User email not found. Please log in.');
    }

    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: {'email': email},
    );

    try {
      final response = await http.delete(uri);

      if (response.statusCode != 200 && context != null) {
        await _handleError(context, response);
      }

      return response;
    } catch (e) {
      if (context != null && context.mounted) {
        await _showErrorDialog(
          context,
          'Connection Error',
          'Failed to connect to the server. Please check your internet connection.',
        );
      }
      rethrow;
    }
  }
}