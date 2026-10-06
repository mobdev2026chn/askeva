import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../main.dart';
import '../screens/login_screen.dart';
import 'api_config.dart';
import 'session.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Thin HTTP wrapper that injects the bearer token and normalises errors.
/// All repositories go through this so auth + base URL are handled once.
class ApiClient {
  final Session session;
  ApiClient(this.session);

  static bool _isRedirectingToLogin = false;

  /// Clears stored authentication session and immediately redirects to LoginScreen.
  void handleSessionExpired() {
    try {
      session.clear();
    } catch (_) {}

    if (_isRedirectingToLogin) return;
    _isRedirectingToLogin = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      Future.delayed(const Duration(seconds: 3), () {
        _isRedirectingToLogin = false;
      });
    });
  }

  Map<String, String> _headers({bool auth = true, bool json = true}) {
    final t = session.token;
    return {
      if (json) 'Content-Type': 'application/json',
      if (auth && t != null && t.isNotEmpty) ...{
        'Authorization': 'Bearer $t',
        'x-access-token': t,
        'token': t,
      },
      if (session.roomId != null && session.roomId!.isNotEmpty) 'x-room-id': session.roomId!,
      if (session.userId != null && session.userId!.isNotEmpty) 'x-user-id': session.userId!,
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = path.startsWith('http') ? path : '${ApiConfig.apiV1}$path';
    final uri = Uri.parse(base);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...query.map((k, v) => MapEntry(k, '$v')),
    });
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body, bool auth = true}) =>
      _send('PUT', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {Object? body, Map<String, dynamic>? query, bool auth = true}) =>
      _send('DELETE', path, body: body, query: query, auth: auth);

  /// POST that returns the raw response body instead of decoded JSON — used for
  /// /payments/addWallet, which returns the gateway HTML page.
  Future<String> postText(String path, {Object? body, bool auth = true}) async {
    final uri = _uri(path);
    final resp = await http.post(uri, headers: _headers(auth: auth), body: body == null ? null : jsonEncode(body));
    if (kDebugMode) debugPrint('API POST(text) $uri -> ${resp.statusCode}');
    if (resp.statusCode >= 200 && resp.statusCode < 300) return resp.body;
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      handleSessionExpired();
    }
    throw ApiException('Request failed (${resp.statusCode})', statusCode: resp.statusCode);
  }

  /// Multipart upload of [bytes] under form field [field]; returns decoded JSON.
  Future<dynamic> uploadFile(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
    String? contentType,
    bool auth = true,
  }) async {
    final uri = _uri(path);
    final req = http.MultipartRequest('POST', uri);
    if (auth && session.token != null) req.headers['Authorization'] = 'Bearer ${session.token}';
    final mf = http.MultipartFile.fromBytes(
      field,
      bytes,
      filename: filename,
      contentType: contentType != null ? MediaType.parse(contentType) : null,
    );
    req.files.add(mf);
    final resp = await http.Response.fromStream(await req.send());
    if (kDebugMode) debugPrint('API UPLOAD $uri -> ${resp.statusCode} body=${resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body}');
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.body.isEmpty ? null : jsonDecode(resp.body);
    }
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      handleSessionExpired();
    }
    throw ApiException('Upload failed (${resp.statusCode}): ${resp.body}', statusCode: resp.statusCode);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final uri = _uri(path, query);
    try {
      final headers = _headers(auth: auth);
      final encoded = body == null ? null : jsonEncode(body);
      late http.Response resp;
      switch (method) {
        case 'GET':
          resp = await http.get(uri, headers: headers);
        case 'POST':
          resp = await http.post(uri, headers: headers, body: encoded);
        case 'PATCH':
          resp = await http.patch(uri, headers: headers, body: encoded);
        case 'PUT':
          resp = await http.put(uri, headers: headers, body: encoded);
        case 'DELETE':
          resp = await http.delete(uri, headers: headers, body: encoded);
      }

      if (kDebugMode) {
        debugPrint('API $method $uri -> ${resp.statusCode}\nRequest: $encoded\nResponse: ${resp.body}');
      }

      try {
        final file = File('api_logs.txt');
        file.writeAsStringSync(
          '${DateTime.now()}: $method $uri -> ${resp.statusCode}\nRequest: $encoded\nResponse: ${resp.body}\n\n',
          mode: FileMode.append,
        );
      } catch (_) {}

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.body.isEmpty) return null;
        return jsonDecode(resp.body);
      }

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        handleSessionExpired();
        throw ApiException('Session expired. Please sign in again.', statusCode: 401);
      }

      String msg = 'Request failed (${resp.statusCode})';
      try {
        final b = jsonDecode(resp.body);
        if (b is Map) {
          final errObj = b['error'];
          if (errObj is Map && errObj['msg'] != null) {
            msg = errObj['msg'].toString();
          } else if (errObj is String && errObj.isNotEmpty) {
            msg = errObj;
          } else if ((b['message'] ?? b['msg']) != null) {
            msg = (b['message'] ?? b['msg']).toString();
          }
        }
      } catch (_) {}

      final msgLower = msg.toLowerCase();
      if (msgLower.contains('session expired') ||
          msgLower.contains('jwt expired') ||
          msgLower.contains('token expired') ||
          msgLower.contains('unauthorized') ||
          msgLower.contains('please sign in again') ||
          msgLower.contains('invalid token')) {
        handleSessionExpired();
        throw ApiException('Session expired. Please sign in again.', statusCode: 401);
      }

      throw ApiException(msg, statusCode: resp.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      final err = e.toString();
      debugPrint('ApiClient error ($uri): $err');
      if (err.contains('SocketException') ||
          err.contains('Connection refused') ||
          err.contains('Failed host lookup')) {
        throw ApiException('Server unreachable (${uri.host}). Please check your internet connection.');
      }
      throw ApiException(err.replaceFirst('Exception: ', ''));
    }
  }
}
