import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Default base URL for Android emulator. Change to your backend host if needed:
  // - Android emulator: http://10.0.2.2:3000
  // - Windows/macOS (desktop): http://localhost:3000
  // - Real device: use your machine IP like http://192.168.1.5:3000
  // Determine base URL depending on platform so emulators/devices reach the host.
  // - Android emulator: use 10.0.2.2

  static String get baseUrl {
    return 'https://apiv2.askeva.io';
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String domain = 'app.askeva.io',
  }) async {
    final url = Uri.parse('$baseUrl/v1/users/login');
    try {
      if (kDebugMode) {
        print('AuthService.login -> POST $url');
        print(
          'AuthService.login -> body: ${jsonEncode({'email': email, 'domain': domain})}',
        );
      }

      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'domain': domain,
        }),
      );

      if (kDebugMode) {
        print('AuthService.login -> status: ${resp.statusCode}');
        print('AuthService.login -> body: ${resp.body}');
      }

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }

      // Friendly handling for authentication failure
      if (resp.statusCode == 400 || resp.statusCode == 401) {
        String msg = "Username and password doesn't match";
        try {
          final body = jsonDecode(resp.body);
          if (body is Map && body['message'] != null) {
            msg = body['message'];
          }
        } catch (_) {}
        throw Exception(msg);
      }

      // For any other non-success status code, show "Server is down"
      throw Exception('Server is down (Status: ${resp.statusCode})');
    } catch (e) {
      final err = e.toString();
      // Detect network issues
      if (err.contains('SocketException') ||
          err.contains('HttpException') ||
          err.contains('Connection refused') ||
          err.contains('Connection timed out')) {
        throw Exception('Server is down');
      }

      // Rethrow specific API errors or other exceptions
      rethrow;
    }
  }

  // Persist token helpers
  static const _prefKeyToken = 'auth_token';
  static const _prefKeyRoomId = 'auth_room_id';
  static const _prefKeyUsername = 'auth_username';
  static const _prefKeyEmail = 'auth_email';
  static const _prefKeyRole = 'auth_role';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyToken);
  }

  static Future<void> saveRoomId(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyRoomId, roomId);
  }

  static Future<String?> getRoomId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyRoomId);
  }

  static Future<void> saveUserData(
    String username,
    String email,
    String role,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUsername, username);
    await prefs.setString(_prefKeyEmail, email);
    await prefs.setString(_prefKeyRole, role);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUsername);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyEmail);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyRole);
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyToken);
    await prefs.remove(_prefKeyRoomId);
    await prefs.remove(_prefKeyUsername);
    await prefs.remove(_prefKeyEmail);
    await prefs.remove(_prefKeyRole);
  }

  // Step 1: Check user and get mobile number
  static Future<String> checkUserAndGetMobile(
    String email, {
    String domain = 'app.askeva.io',
  }) async {
    // Note: The backend endpoint is named 'forget-password' but we use it to get the mobile number
    final uri = Uri.parse(
      '$baseUrl/v1/users/forget-password',
    ).replace(queryParameters: {'email': email, 'domain': domain});

    if (kDebugMode) {
      print('AuthService.checkUser -> GET $uri');
    }

    final resp = await http.get(uri);

    if (kDebugMode) {
      print('AuthService.checkUser -> status: ${resp.statusCode}');
      print('AuthService.checkUser -> body: ${resp.body}');
    }

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['mobileNumber'] != null) {
        return data['mobileNumber'].toString();
      }
    }

    String msg = 'User not found';
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['msg'] != null) {
        msg = body['msg'];
      }
    } catch (_) {}
    throw Exception(msg);
  }

  // Step 2: Send OTP
  static Future<void> sendOtp(
    String contactNumber, {
    String domain = 'app.askeva.io',
  }) async {
    final url = Uri.parse('$baseUrl/v1/users/otp');
    final bodyData = {
      'contactNumber': contactNumber,
      'domain': domain,
      // Leaving 'email' out to bypass "User already exists" check
    };

    if (kDebugMode) {
      print('AuthService.sendOtp -> POST $url');
      print('AuthService.sendOtp -> body: $bodyData');
    }

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyData),
    );

    if (kDebugMode) {
      print('AuthService.sendOtp -> status: ${resp.statusCode}');
      print('AuthService.sendOtp -> body: ${resp.body}');
    }

    if (resp.statusCode == 200) {
      return;
    }

    String msg = 'Failed to send OTP';
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['msg'] != null) {
        msg = body['msg'];
      }
    } catch (_) {}
    throw Exception(msg);
  }

  // Step 3: Verify OTP and Login
  static Future<Map<String, dynamic>> verifyLoginOtp(
    String email,
    String otp, {
    String domain = 'app.askeva.io',
  }) async {
    final url = Uri.parse('$baseUrl/v1/users/verify-signinotp');
    final bodyData = {'email': email, 'otp': otp, 'domain': domain};

    if (kDebugMode) {
      print('AuthService.verifyLoginOtp -> POST $url');
      print('AuthService.verifyLoginOtp -> body: $bodyData');
    }

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyData),
    );

    if (kDebugMode) {
      print('AuthService.verifyLoginOtp -> status: ${resp.statusCode}');
      print('AuthService.verifyLoginOtp -> body: ${resp.body}');
    }

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    String msg = 'Invalid OTP';
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['message'] != null) {
        msg = body['message'];
      } else if (body is Map && body['msg'] != null) {
        msg = body['msg'];
      }
    } catch (_) {}
    throw Exception(msg);
  }

  // Get Profile
  static Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/users/profile');
    if (kDebugMode) {
      print('AuthService.getProfile -> GET $url');
    }

    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (kDebugMode) {
      print('AuthService.getProfile -> status: ${resp.statusCode}');
      print('AuthService.getProfile -> body: ${resp.body}');
    }

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to load profile');
  }

  // Update Profile
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/users/profile');
    if (kDebugMode) {
      print('AuthService.updateProfile -> PATCH $url');
      print('AuthService.updateProfile -> body: $data');
    }

    final resp = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (kDebugMode) {
      print('AuthService.updateProfile -> status: ${resp.statusCode}');
      print('AuthService.updateProfile -> body: ${resp.body}');
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    String msg = 'Failed to update profile';
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['message'] != null) {
        msg = body['message'];
      }
    } catch (_) {}
    throw Exception(msg);
  }

  // Get Invoices
  static Future<List<dynamic>> getInvoices() async {
    final token = await getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/users/invoices');
    if (kDebugMode) {
      print('AuthService.getInvoices -> GET $url');
    }

    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (kDebugMode) {
      print('AuthService.getInvoices -> status: ${resp.statusCode}');
      print('AuthService.getInvoices -> body: ${resp.body}');
    }

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }

    throw Exception('Failed to load invoices');
  }
}
