import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class LeadConfigurationService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<Map<String, dynamic>> getConfiguration() async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load lead configuration');
  }

  static Future<List<dynamic>> getQuickReplies() async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/quick-replies');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['data'] as List<dynamic>;
    }
    throw Exception('Failed to load quick replies');
  }

  static Future<Map<String, dynamic>> createQuickReply(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/quick-replies');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create quick reply');
  }

  static Future<Map<String, dynamic>> updateQuickReply(
    String id,
    Map<String, dynamic> data,
  ) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw Exception('Quick reply id is required');
    }
    final uri = Uri.parse(
      '$baseUrl/v1/lead-configuration/quick-replies/${Uri.encodeComponent(cleanId)}',
    );
    final token = await AuthService.getToken();
    final body = {
      'title': data['title']?.toString().trim() ?? '',
      'message': data['message']?.toString().trim() ?? '',
    };
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    String message = 'Failed to update quick reply';
    try {
      final errBody = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (errBody != null && errBody['message'] != null) {
        message = errBody['message'] as String;
      }
    } catch (_) {}
    throw Exception(message);
  }

  static Future<void> deleteQuickReply(String id) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/quick-replies/$id');
    final token = await AuthService.getToken();
    final resp = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete quick reply');
    }
  }

  static Future<Map<String, dynamic>> getWebhookConfig() async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/webhook');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load webhook configuration');
  }

  static Future<void> updateWebhookConfig(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/webhook');
    final token = await AuthService.getToken();
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to update webhook configuration');
    }
  }

  /// POST /webhook/test - test webhook connection (uses saved config)
  static Future<Map<String, dynamic>> testWebhook() async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/webhook/test');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200 && body['success'] == true) {
      return body;
    }
    throw Exception(body['message'] ?? 'Webhook test failed');
  }

  static Future<Map<String, dynamic>> getFacebookAuthUrl() async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/facebook/auth-url');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body;
    }
    throw Exception('Failed to get Facebook auth URL');
  }

  static Future<Map<String, dynamic>> getAlertConfig() async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/alerts');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load alert configuration');
  }

  static Future<void> updateAlertConfig(
    String alertType,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/alerts');
    final token = await AuthService.getToken();
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'alertType': alertType, 'alertData': data}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to update alert configuration');
    }
  }

  /// DELETE /alerts/:alertType - remove alert configuration (e.g. on Reset)
  static Future<void> deleteAlertConfig(String alertType) async {
    final uri = Uri.parse(
        '$baseUrl/v1/lead-configuration/alerts/${Uri.encodeComponent(alertType)}');
    final token = await AuthService.getToken();
    final resp = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete alert configuration');
    }
  }

  // --- Lead fields (Settings) - match web Configuration.jsx ---
  /// POST /fields - add custom field
  static Future<Map<String, dynamic>> addCustomField(
    Map<String, dynamic> fieldData,
  ) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/fields');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(fieldData),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    throw Exception(body['message'] ?? 'Failed to add custom field');
  }

  /// PUT /fields/:fieldKey - update field (displayInTable, mandatory, etc.)
  static Future<void> updateField(
    String fieldKey,
    Map<String, dynamic> updates,
  ) async {
    final uri =
        Uri.parse('$baseUrl/v1/lead-configuration/fields/${Uri.encodeComponent(fieldKey)}');
    final token = await AuthService.getToken();
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to update field');
    }
  }

  /// DELETE /fields/:fieldKey - delete custom field only
  static Future<void> deleteField(String fieldKey) async {
    final uri =
        Uri.parse('$baseUrl/v1/lead-configuration/fields/${Uri.encodeComponent(fieldKey)}');
    final token = await AuthService.getToken();
    final resp = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to delete field');
    }
  }

  /// PUT /options/:fieldKey - update dropdown options for a select field
  static Future<void> updateFieldOptions(
    String fieldKey,
    List<String> options,
  ) async {
    final uri = Uri.parse(
        '$baseUrl/v1/lead-configuration/options/${Uri.encodeComponent(fieldKey)}');
    final token = await AuthService.getToken();
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'options': options}),
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to update options');
    }
  }

  static Future<String> getAssignmentMode() async {
    try {
      final uri = Uri.parse('$baseUrl/v1/lead-configuration/assignment-mode');
      final token = await AuthService.getToken();
      final resp = await http.get(
        uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (body['data'] is Map) ? body['data'] as Map : body;
        if (data['roundRobin'] == true || data['round_robin'] == true) return 'round_robin';
        if (data['manual'] == true) return 'manual';
      }
    } catch (_) {}

    try {
      final config = await getConfiguration();
      if (config['roundRobin'] == true || config['round_robin'] == true) return 'round_robin';
      if (config['manual'] == true) return 'manual';
    } catch (_) {}
    return 'manual';
  }

  static Future<void> saveAssignmentMode(String mode) async {
    final body = {
      'manual': mode == 'manual',
      'roundRobin': mode == 'round_robin',
    };
    final token = await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('$baseUrl/v1/lead-configuration/assignment-mode');
      final resp = await http.put(uri, headers: headers, body: jsonEncode(body));
      if (resp.statusCode == 200 || resp.statusCode == 201) return;
    } catch (_) {}

    final uri = Uri.parse('$baseUrl/v1/lead-configuration');
    await http.put(uri, headers: headers, body: jsonEncode(body));
  }

  /// Triggers automated alerts when a new lead is created.
  static Future<void> triggerAlertsOnLeadCreation(Map<String, dynamic> leadData) async {
    try {
      final alerts = await getAlertConfig();
      if (alerts.isEmpty) return;

      final token = await AuthService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // 1. New Lead Creation Alert -> sends to lead's primary contact number
      final newLeadAlert = alerts['newLeadCreationAlert'] as Map<String, dynamic>?;
      if (newLeadAlert != null && newLeadAlert['active'] == true) {
        final template = newLeadAlert['template'] as Map<String, dynamic>?;
        final mappings = newLeadAlert['formData']?['variableMappings'] as Map<String, dynamic>?;
        
        final rawMobile = (leadData['fullMobile'] ?? leadData['mobile'] ?? '').toString().replaceAll(RegExp(r'[^\d]'), '');
        var cc = (leadData['countryCode'] ?? '91').toString().replaceAll(RegExp(r'[^\d]'), '');
        if (cc.isEmpty) cc = '91';

        String cleanMobile = rawMobile;
        if (cc == '91' && cleanMobile.startsWith('9191') && cleanMobile.length >= 12) {
          cleanMobile = cleanMobile.substring(4);
        } else if (cleanMobile.startsWith(cc + cc) && cleanMobile.length >= (cc.length * 2 + 6)) {
          cleanMobile = cleanMobile.substring(cc.length * 2);
        } else if (cc == '91' && cleanMobile.startsWith('91') && cleanMobile.length >= 11 && cleanMobile.length <= 13) {
          cleanMobile = cleanMobile.substring(2);
        } else if (cleanMobile.startsWith(cc) && cleanMobile.length >= (cc.length + 6)) {
          cleanMobile = cleanMobile.substring(cc.length);
        }

        final recipient = '+$cc$cleanMobile';

        if (template != null && recipient.length > 5) {
          final variables = <String, dynamic>{};
          if (mappings != null) {
            mappings.forEach((varKey, fieldKey) {
              if (fieldKey != null && fieldKey.toString().isNotEmpty) {
                variables[varKey.toString()] = (leadData[fieldKey.toString()] ?? '').toString();
              }
            });
          }

          final payload = {
            'templateName': template['name'] ?? template['id'],
            'recipient': recipient,
            'variables': variables,
            'language': template['language'] ?? 'en',
          };

          await http.post(
            Uri.parse('$baseUrl/v1/lead-configuration/send-template'),
            headers: headers,
            body: jsonEncode(payload),
          );
        }
      }

      // 2. Business Alert -> sends to business / agent contact number
      final businessAlert = alerts['businessAlert'] as Map<String, dynamic>?;
      if (businessAlert != null && businessAlert['active'] == true) {
        final template = businessAlert['template'] as Map<String, dynamic>?;
        final mappings = businessAlert['formData']?['variableMappings'] as Map<String, dynamic>?;
        final rawAgentMobile = (businessAlert['recipientNumber'] ?? businessAlert['formData']?['recipientNumber'] ?? '').toString();
        var cleanAgentMobile = rawAgentMobile.replaceAll(RegExp(r'[^\d]'), '');
        if (cleanAgentMobile.startsWith('9191') && cleanAgentMobile.length >= 12) {
          cleanAgentMobile = cleanAgentMobile.substring(4);
        } else if (cleanAgentMobile.startsWith('91') && cleanAgentMobile.length >= 11 && cleanAgentMobile.length <= 13) {
          cleanAgentMobile = cleanAgentMobile.substring(2);
        }
        if (cleanAgentMobile.length == 10) {
          cleanAgentMobile = '91$cleanAgentMobile';
        }
        final agentMobile = cleanAgentMobile.isEmpty ? '' : '+$cleanAgentMobile';

        if (template != null && agentMobile.length > 5) {
          final variables = <String, dynamic>{};
          if (mappings != null) {
            mappings.forEach((varKey, fieldKey) {
              if (fieldKey != null && fieldKey.toString().isNotEmpty) {
                variables[varKey.toString()] = (leadData[fieldKey.toString()] ?? '').toString();
              }
            });
          }

          final payload = {
            'templateName': template['name'] ?? template['id'],
            'recipient': agentMobile,
            'variables': variables,
            'language': template['language'] ?? 'en',
          };

          await http.post(
            Uri.parse('$baseUrl/v1/lead-configuration/send-template'),
            headers: headers,
            body: jsonEncode(payload),
          );
        }
      }
    } catch (e) {
      // Log silently to avoid breaking lead creation flow
      if (kDebugMode) {
        debugPrint('[LeadConfigurationService] triggerAlertsOnLeadCreation error: $e');
      }
    }
  }
}



