import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';
import 'lead_configuration_service.dart';

class LeadsService {
  static String get baseUrl => AuthService.baseUrl;

  /// Fetches dynamic lead fields configuration from backend.
  static Future<List<dynamic>> getLeadFields() async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['data']?['leadFields'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to load lead fields');
  }

  /// Fetches one page of leads from backend. Optional [q] searches name, email, fullMobile, etc.
  static Future<Map<String, dynamic>> getLeads({
    int page = 1,
    int limit = 100,
    String? q,
  }) async {
    final queryParams = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (q != null && q.isNotEmpty) {
      queryParams['q'] = q;
    }
    final uri = Uri.parse(
      '$baseUrl/v1/lead-configuration/leads',
    ).replace(queryParameters: queryParams);
    if (kDebugMode) {
      debugPrint('[LeadsService.getLeads] REQUEST (no filters): $uri');
    }
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final List<dynamic> data = body['data'] ?? [];
      final total = body['total'] as int? ?? data.length;
      if (kDebugMode) {
        debugPrint('[LeadsService.getLeads] RESPONSE: page=$page, items=${data.length}, total=$total');
      }
      return {
        'items': data,
        'total': total,
      };
    }
    throw Exception('Failed to load leads');
  }

  /// Fetches all leads from backend (pages until no more). No filtering - app will filter locally.
  static Future<List<dynamic>> fetchAllLeads() async {
    const limit = 100;
    final all = <dynamic>[];
    int page = 1;
    while (true) {
      final res = await getLeads(page: page, limit: limit);
      final items = res['items'] as List<dynamic>;
      all.addAll(items);
      if (items.length < limit) break;
      page++;
    }
    if (kDebugMode) {
      debugPrint('[LeadsService.fetchAllLeads] fetched ${all.length} leads total');
    }
    return all;
  }

  static Future<List<dynamic>> getCompanies({String? q}) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration');
    final token = await AuthService.getToken();
    try {
      final resp = await http.get(
        uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final fields = body['data']?['leadFields'] as List<dynamic>?;
        if (fields != null) {
          final companyField = fields.firstWhere(
            (f) => f['fieldKey'] == 'company',
            orElse: () => null,
          );
          if (companyField != null && companyField['options'] != null) {
            final List<String> options = List<String>.from(
              companyField['options'],
            );
            return options.map((name) => {'id': name, 'name': name}).toList();
          }
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> createCompany(String name) async {
    // Backend doesn't have a direct "create company" endpoint that adds to options.
    // It uses updateCompanyOptions to replace the whole list.
    // For now, we return the name as if it was created so the UI can proceed.
    return {'id': name, 'name': name};
  }

  static Future<Map<String, dynamic>> getCompanyCustomers(
    String companyId, {
    int page = 1,
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/companies/$companyId/customers',
    ).replace(queryParameters: {'page': '$page', 'limit': '$limit'});
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load customers');
  }

  static Future<Map<String, dynamic>> getLead(String id) async {
    if (kDebugMode) debugPrint('[LeadsService.getLead] START id=$id');
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/$id');
    final token = await AuthService.getToken();
    try {
      final resp = await http
          .get(
            uri,
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      if (kDebugMode) debugPrint('[LeadsService.getLead] RESPONSE status=${resp.statusCode}');
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>;
        if (kDebugMode) debugPrint('[LeadsService.getLead] OK name=${data['name']}');
        return data;
      }
      throw Exception('Failed to load lead');
    } catch (e) {
      if (kDebugMode) debugPrint('[LeadsService.getLead] ERROR $e');
      rethrow;
    }
  }

  /// Lead activity (audit) logs from v1/lead-configuration/leads/:id/audit-logs
  static Future<List<dynamic>> getLeadActivity(String id) async {
    if (id.isEmpty) return [];
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/$id/audit-logs');
    final token = await AuthService.getToken();
    final resp = await http
        .get(
          uri,
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is List) return data;
      }
      return [];
    }
    throw Exception('Failed to load activity');
  }

  /// Call logs from Exotel (all user's calls). Filter by lead phone in UI.
  static Future<List<dynamic>> getLeadCalls({int page = 1, int limit = 100}) async {
    final uri = Uri.parse('$baseUrl/v1/exotel/call-logs')
        .replace(queryParameters: {'page': '$page', 'limit': '$limit'});
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data is List) return data;
      return [];
    }
    throw Exception('Failed to load call logs');
  }

  static Future<List<dynamic>> getLeadReminders(String leadId) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/$leadId/reminders');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data is List) return data;
      return [];
    }
    throw Exception('Failed to load reminders');
  }

  static Future<Map<String, dynamic>> addLeadReminder(
    String leadId,
    Map<String, dynamic> reminderData,
  ) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/$leadId/reminders');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(reminderData),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to add reminder: ${resp.body}');
  }

  static Future<Map<String, dynamic>> updateLeadReminder(
    String leadId,
    String reminderId,
    Map<String, dynamic> updates,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/v1/lead-configuration/leads/$leadId/reminders/$reminderId',
    );
    final token = await AuthService.getToken();
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update reminder: ${resp.body}');
  }

  static Future<void> deleteLeadReminder(String leadId, String reminderId) async {
    final uri = Uri.parse(
      '$baseUrl/v1/lead-configuration/leads/$leadId/reminders/$reminderId',
    );
    final token = await AuthService.getToken();
    final resp = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete reminder: ${resp.body}');
    }
  }

  /// Approved templates for send-template dropdown (backend returns array directly)
  static Future<List<dynamic>> getApprovedTemplates() async {
    if (kDebugMode) debugPrint('[LeadsService.getApprovedTemplates] START');
    final uri = Uri.parse('$baseUrl/v1/templates/approved');
    final token = await AuthService.getToken();
    try {
      final resp = await http
          .get(
            uri,
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      if (kDebugMode) debugPrint('[LeadsService.getApprovedTemplates] RESPONSE status=${resp.statusCode}');
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        int count = 0;
        if (decoded is List) count = decoded.length;
        if (decoded is Map && decoded['data'] is List) count = (decoded['data'] as List).length;
        if (kDebugMode) debugPrint('[LeadsService.getApprovedTemplates] OK count=$count');
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['data'] is List) return decoded['data'] as List;
        return [];
      }
      throw Exception('Failed to load templates');
    } catch (e) {
      if (kDebugMode) debugPrint('[LeadsService.getApprovedTemplates] ERROR $e');
      rethrow;
    }
  }

  static (String, String) _cleanMobileAndCc(String rawMobile, String rawCc) {
    var mobile = rawMobile.replaceAll(RegExp(r'[^\d]'), '').trim();
    var cc = rawCc.replaceAll(RegExp(r'[^\d]'), '').trim();
    if (cc.isEmpty) cc = '91';

    if (cc == '91' && mobile.startsWith('9191') && mobile.length >= 12) {
      mobile = mobile.substring(4);
    } else if (mobile.startsWith(cc + cc) && mobile.length >= (cc.length * 2 + 6)) {
      mobile = mobile.substring(cc.length * 2);
    } else if (cc == '91' && mobile.startsWith('91') && mobile.length >= 11 && mobile.length <= 13) {
      mobile = mobile.substring(2);
    } else if (mobile.startsWith(cc) && mobile.length >= (cc.length + 6)) {
      mobile = mobile.substring(cc.length);
    }

    return (mobile, cc);
  }

  static Future<Map<String, dynamic>> sendTemplateMessage(
    Map<String, dynamic> payload,
  ) async {
    final copyBody = Map<String, dynamic>.from(payload);

    if (copyBody['recipientData'] is Map) {
      final rd = Map<String, dynamic>.from(copyBody['recipientData'] as Map);
      final rawMob = (rd['mobile'] ?? rd['fullMobile'] ?? rd['mobileNumber'] ?? rd['phone'] ?? '').toString();
      final rawCc = (rd['countryCode'] ?? rd['country_code'] ?? '91').toString();
      final (cleanMob, cleanCc) = _cleanMobileAndCc(rawMob, rawCc);
      rd['mobile'] = cleanMob;
      rd['mobileNumber'] = cleanMob;
      rd['fullMobile'] = '$cleanCc$cleanMob';
      rd['countryCode'] = cleanCc;
      copyBody['recipientData'] = rd;
    }

    if (copyBody['recipient'] != null) {
      final rawMob = copyBody['recipient'].toString();
      final (cleanMob, cleanCc) = _cleanMobileAndCc(rawMob, '91');
      copyBody['recipient'] = '+$cleanCc$cleanMob';
    }

    final uri = Uri.parse('$baseUrl/v1/lead-configuration/send-template');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(copyBody),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to send template: ${resp.body}');
  }

  static Future<List<dynamic>> getLeadNotes(String id) async {
    if (id.isEmpty) return [];
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/$id/notes');
    final token = await AuthService.getToken();
    try {
      final resp = await http
          .get(
            uri,
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body is Map<String, dynamic>) {
          final data = body['data'];
          if (data is List) return data;
        }
        return [];
      }
      throw Exception('Failed to load notes');
    } catch (e) {
      rethrow;
    }
  }

  /// Normalize lead id from API (handles _id as string or Map with \$oid).
  static String? leadIdFromLead(dynamic lead) {
    if (lead == null) return null;
    if (lead is Map) {
      final id = lead['_id'] ?? lead['id'];
      if (id == null) return null;
      if (id is String) return id;
      if (id is Map && id['\$oid'] != null) return id['\$oid'].toString();
      return id.toString();
    }
    return lead.toString();
  }

  /// Convert lead to customer. Backend: PUT /leads/:leadId/convert
  static Future<Map<String, dynamic>> convertLeadToCustomer(String leadId) async {
    final uri = Uri.parse(
      '$baseUrl/v1/lead-configuration/leads/$leadId/convert',
    );
    final token = await AuthService.getToken();
    final resp = await http.put(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to convert: ${resp.body}');
  }

  static Future<Map<String, dynamic>> addLeadNote(
    String id,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/$id/notes');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to add note: ${resp.body}');
  }

  /// Delete a single note. Backend: DELETE /leads/:leadId/notes/:noteId
  static Future<void> deleteLeadNote(String leadId, String noteId) async {
    final uri = Uri.parse(
      '$baseUrl/v1/lead-configuration/leads/$leadId/notes/$noteId',
    );
    final token = await AuthService.getToken();
    final resp = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete note: ${resp.body}');
    }
  }

  /// Clear all notes (bulk delete). Backend: POST /leads/:leadId/notes/bulk-delete, body: { noteIds }
  static Future<void> bulkDeleteLeadNotes(
    String leadId,
    List<String> noteIds,
  ) async {
    if (noteIds.isEmpty) return;
    final uri = Uri.parse(
      '$baseUrl/v1/lead-configuration/leads/$leadId/notes/bulk-delete',
    );
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'noteIds': noteIds}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to clear notes: ${resp.body}');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
    dynamic file,
    String folderName,
  ) async {
    // file can be File (mobile) or PlatformFile (web/mobile picker)
    final uri = Uri.parse('$baseUrl/v1/filehandler/upload/$folderName');
    final token = await AuthService.getToken();
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    if (file is String) {
      request.files.add(await http.MultipartFile.fromPath('file', file));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    } else if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );
    }

    final resp = await request.send();
    final respStr = await resp.stream.bytesToString();
    if (resp.statusCode == 200) {
      return jsonDecode(respStr) as Map<String, dynamic>;
    }
    throw Exception('Upload failed: $respStr');
  }

  static Future<Map<String, dynamic>> getCustomer(String id) async {
    final uri = Uri.parse('$baseUrl/api/customers/$id');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load customer');
  }

  static Future<List<dynamic>> getCustomerTickets(String id) async {
    final uri = Uri.parse(
      '$baseUrl/api/tickets',
    ).replace(queryParameters: {'customerId': id});
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['items'] as List<dynamic>;
    }
    throw Exception('Failed to load tickets');
  }

  static Future<List<dynamic>> getCustomerAppointments(String id) async {
    final uri = Uri.parse('$baseUrl/api/customers/$id/appointments');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['items'] as List<dynamic>;
    }
    throw Exception('Failed to load appointments');
  }

  /// Status options for global filter: same as web (Leads.jsx).
  /// From lead configuration leadFields[fieldKey===status].options, then append "Converted" if not present.
  static Future<List<String>> getStatuses() async {
    List<String> options;
    try {
      final uri = Uri.parse('$baseUrl/v1/lead-configuration');
      final token = await AuthService.getToken();
      final resp = await http.get(
        uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final fields = body['data']?['leadFields'] as List<dynamic>?;
        if (fields != null) {
          final statusFields = fields.cast<Map<String, dynamic>>().where((f) => f['fieldKey'] == 'status').toList();
          if (statusFields.isNotEmpty && statusFields.first['options'] != null) {
            options = List<String>.from(statusFields.first['options'] as List<dynamic>);
            return _statusOptionsWithConverted(options);
          }
        }
      }
    } catch (_) {}
    options = ['New Lead', 'Hot', 'Warm', 'Cold', 'Invalid'];
    return _statusOptionsWithConverted(options);
  }

  static List<String> _statusOptionsWithConverted(List<String> fromConfig) {
    const converted = 'Converted';
    if (fromConfig.any((s) => s == converted)) return fromConfig;
    return [...fromConfig, converted];
  }

  /// Fetch source options from lead configuration so filter values match backend lead documents.
  static Future<List<String>> getSources() async {
    try {
      final uri = Uri.parse('$baseUrl/v1/lead-configuration');
      final token = await AuthService.getToken();
      final resp = await http.get(
        uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final fields = body['data']?['leadFields'] as List<dynamic>?;
        if (fields != null) {
          final sourceFields = fields.cast<Map<String, dynamic>>().where((f) => f['fieldKey'] == 'source').toList();
          if (sourceFields.isNotEmpty && sourceFields.first['options'] != null) {
            return List<String>.from(sourceFields.first['options'] as List<dynamic>);
          }
        }
      }
    } catch (_) {}
    return ['Website', 'Referral', 'Social Media', 'Business Card'];
  }

  /// Country code options from lead configuration (same as web). Returns list of {code, name}.
  static const Map<String, String> _countryCodeNames = {
    '1': 'USA',
    '91': 'India',
    '44': 'UK',
    '81': 'Japan',
    '61': 'Australia',
  };

  static Future<List<Map<String, String>>> getCountryCodeOptions() async {
    try {
      final uri = Uri.parse('$baseUrl/v1/lead-configuration');
      final token = await AuthService.getToken();
      final resp = await http.get(
        uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final fields = body['data']?['leadFields'] as List<dynamic>?;
        if (fields != null) {
          final ccFields = fields
              .cast<Map<String, dynamic>>()
              .where((f) => f['fieldKey'] == 'countryCode')
              .toList();
          if (ccFields.isNotEmpty && ccFields.first['options'] != null) {
            final codes = List<String>.from(ccFields.first['options'] as List<dynamic>);
            return codes
                .map((code) => {
                      'code': code.toString(),
                      'name': _countryCodeNames[code.toString()] ?? 'Code $code',
                    })
                .toList();
          }
        }
      }
    } catch (_) {}
    return _countryCodeNames.entries
        .map((e) => {'code': e.key, 'name': e.value})
        .toList();
  }

  static Future<List<dynamic>> getAgents() async {
    final uri = Uri.parse('$baseUrl/v1/agents/agents');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['data'] as List<dynamic>;
    }
    throw Exception('Failed to load agents');
  }

  static Future<Map<String, dynamic>> createAgent(String name) async {
    // Backend createAgent requires email, password, etc.
    // For now, return mock so UI can proceed with the name.
    return {'id': name, 'name': name};
  }

  static Future<Map<String, dynamic>> createLead(
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads');
    final token = await AuthService.getToken();

    print('LeadsService.createLead -> POST $uri');
    print('LeadsService.createLead -> body: ${jsonEncode(data)}');

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    print('LeadsService.createLead -> status: ${resp.statusCode}');
    print('LeadsService.createLead -> body: ${resp.body}');

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final resMap = jsonDecode(resp.body) as Map<String, dynamic>;
      final createdData = (resMap['data'] is Map) ? resMap['data'] as Map<String, dynamic> : data;
      LeadConfigurationService.triggerAlertsOnLeadCreation(createdData);
      return resMap;
    }
    throw Exception('Failed to create lead: ${resp.statusCode} - ${resp.body}');
  }

  static Future<Map<String, dynamic>?> findLeadByPhone(String number) async {
    try {
      final all = await fetchAllLeads();
      final q = number.trim().toLowerCase();
      final match = all.cast<Map<String, dynamic>>().where((lead) {
        final fullMobile = (lead['fullMobile'] ?? '').toString().toLowerCase();
        final mobile = (lead['mobile'] ?? '').toString().toLowerCase();
        return fullMobile.contains(q) || mobile.contains(q);
      });
      final list = match.toList();
      if (list.isNotEmpty) return list.first;
    } catch (e) {
      // Ignore errors for background check
    }
    return null;
  }

  static Future<void> deleteLead(String id) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/$id');
    final token = await AuthService.getToken();
    final resp = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete lead');
    }
  }

  static Future<void> updateLead(String id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/$id');
    final token = await AuthService.getToken();
    if (kDebugMode) {
      debugPrint('[LeadsService.updateLead] PUT $uri');
      debugPrint('[LeadsService.updateLead] body assignedTo=${data['assignedTo']}, assigned=${data['assigned']}');
    }
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (kDebugMode) {
      debugPrint('[LeadsService.updateLead] status=${resp.statusCode}, body=${resp.body.length > 200 ? "${resp.body.substring(0, 200)}..." : resp.body}');
    }
    if (resp.statusCode != 200) {
      throw Exception('Failed to update lead: ${resp.statusCode} - ${resp.body}');
    }
  }

  static Future<void> sendTemplate(String id, String templateType) async {
    // Placeholder for sending template
    // Ideally this would hit an endpoint like POST /api/leads/:id/send-template
    // For now we will simulate a delay
    await Future.delayed(const Duration(seconds: 1));
    // throw Exception('Template sending not configured');
  }

  /// Fetch existing leads for duplicate check (email, fullMobile).
  static Future<List<dynamic>> getExistingLeadsForDuplicateCheck() async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/duplicate-check');
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load existing leads');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return [];
    return List<dynamic>.from(data);
  }

  /// Bulk create leads. duplicateAction: skip | update | create.
  /// Backend: POST /v1/lead-configuration/leads/bulk, body: { leads, duplicateAction?, sendAlert? }.
  /// Each lead: name, company?, email?, status?, source?, countryCode, mobile? (all strings; backend adds fullMobile, userId, timestamps).
  static Future<Map<String, dynamic>> bulkCreateLeads(
    List<Map<String, dynamic>> leads, {
    String duplicateAction = 'skip',
    bool sendAlert = false,
  }) async {
    if (leads.isEmpty) throw Exception('No leads to import');
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/bulk');
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');

    if (kDebugMode) {
      print('[LeadsService.bulkCreateLeads] POST $uri');
      print('[LeadsService.bulkCreateLeads] leads count: ${leads.length}, duplicateAction: $duplicateAction, sendAlert: $sendAlert');
      print('[LeadsService.bulkCreateLeads] token present: ${token.isNotEmpty}');
      if (leads.isNotEmpty) {
        print('[LeadsService.bulkCreateLeads] first lead sample: ${leads.first}');
      }
    }

    // Build payload exactly as backend expects: leads array, duplicateAction, sendAlert
    final body = <String, dynamic>{
      'leads': leads,
      'duplicateAction': duplicateAction,
      'sendAlert': sendAlert,
    };
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (kDebugMode) {
      print('[LeadsService.bulkCreateLeads] response status: ${resp.statusCode}');
      print('[LeadsService.bulkCreateLeads] response body length: ${resp.body.length}');
    }

    final decoded = resp.body.isNotEmpty
        ? (jsonDecode(resp.body) as Map<String, dynamic>? ?? <String, dynamic>{})
        : <String, dynamic>{};
    if (resp.statusCode != 200) {
      if (kDebugMode) print('[LeadsService.bulkCreateLeads] error body: ${resp.body.length > 500 ? resp.body.substring(0, 500) : resp.body}');
      final msg = decoded['message']?.toString() ?? decoded['msg']?.toString() ?? resp.body;
      throw Exception(msg.isNotEmpty ? msg : 'Bulk import failed (${resp.statusCode})');
    }
    // Backend returns { success: true, message, data: { total, success, failed, skipped, updated, errors } }
    if (decoded['success'] == false) {
      if (kDebugMode) print('[LeadsService.bulkCreateLeads] body.success is false: $decoded');
      throw Exception(decoded['message']?.toString() ?? 'Import failed');
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    if (kDebugMode && data != null) {
      print('[LeadsService.bulkCreateLeads] success: total=${data['total']}, created=${data['success']}, failed=${data['failed']}, skipped=${data['skipped']}, updated=${data['updated']}');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> importLeads(
    dynamic file, {
    bool checkMobile = false,
    bool checkEmail = false,
    bool checkName = false,
  }) async {
    // file is PlatformFile
    final uri = Uri.parse('$baseUrl/api/leads/import');
    final request = http.MultipartRequest('POST', uri);

    request.fields['checkMobile'] = checkMobile.toString();
    request.fields['checkEmail'] = checkEmail.toString();
    request.fields['checkName'] = checkName.toString();

    // For web vs mobile
    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    }

    final resp = await request.send();
    if (resp.statusCode != 200) {
      throw Exception('Import failed');
    }
    final respStr = await resp.stream.bytesToString();
    return jsonDecode(respStr) as Map<String, dynamic>;
  }

  /// Export leads as Excel (.xlsx) by fetching leads via getLeads and building file in Dart.
  /// Avoids backend export URL / invalid leadId issues; always produces .xlsx.
  static Future<String> exportLeadsAsFile({
    List<String>? ids,
    String format = 'xlsx',
  }) async {
    if (format != 'xlsx') {
      throw Exception('Only Excel (.xlsx) export is supported');
    }
    // Fetch all leads (filtering done in app)
    List<dynamic> items = await fetchAllLeads();
    if (ids != null && ids.isNotEmpty) {
      final idSet = ids.toSet();
      items = items.where((e) {
        final id = (e['_id'] ?? e['id'])?.toString();
        return id != null && idSet.contains(id);
      }).toList();
    }
    if (items.isEmpty) {
      throw Exception('No leads to export');
    }
    // Build Excel: Name, Company, Email, Status, Source, Assigned, Created Date (DD-MM-YYYY HH:mm)
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Leads');
    final leadSheet = excel['Leads'];
    final headers = [
      'Name',
      'Company',
      'Email',
      'Status',
      'Source',
      'Assigned',
      'Created Date',
    ];
    leadSheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final lead in items) {
      final company = lead['company'];
      final companyStr = company is Map
          ? (company['name'] ?? '').toString()
          : (company ?? '').toString();
      final assigned = lead['assignedTo'];
      final assignedStr = assigned is Map
          ? (assigned['name'] ?? assigned['email'] ?? '').toString()
          : (assigned ?? '').toString();
      String status = (lead['status'] ?? '').toString();
      if (status.isEmpty || status == 'New') status = 'New Lead';
      String createdDate = '';
      final createdAt = lead['createdAt'];
      if (createdAt != null) {
        try {
          final dt = createdAt is DateTime
              ? createdAt
              : DateTime.tryParse(createdAt.toString());
          if (dt != null) {
            createdDate =
                '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} '
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }
        } catch (_) {}
      }
      leadSheet.appendRow([
        TextCellValue((lead['name'] ?? '').toString()),
        TextCellValue(companyStr),
        TextCellValue((lead['email'] ?? '').toString()),
        TextCellValue(status),
        TextCellValue((lead['source'] ?? '').toString()),
        TextCellValue(assignedStr),
        TextCellValue(createdDate),
      ]);
    }
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to generate Excel file');
    final dir = await getTemporaryDirectory();
    final filename =
        'leads-export-${DateTime.now().toIso8601String().split('T').first}.xlsx';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Export leads as Excel (.xlsx). Returns path to saved file.
  static Future<String> exportLeadsAsCsv({List<String>? ids}) async {
    return exportLeadsAsFile(ids: ids, format: 'xlsx');
  }

  static String getExportUrl({List<String>? ids}) {
    return ''; // Client-side export only; no URL.
  }

  static String getCustomerExportUrl({List<String>? ids}) {
    String url = '$baseUrl/api/customers/export';
    if (ids != null && ids.isNotEmpty) {
      url += '?ids=${ids.join(",")}';
    }
    return url;
  }

  static Future<void> deleteLeads(List<String> ids) async {
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/leads/bulk-delete');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'leadIds': ids}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete leads');
    }
  }

  static Future<List<dynamic>> getAgentStats({int days = 30}) async {
    // The endpoint /api/leads/stats/by-agent does not exist in backend.
    // Returning empty list to prevent errors until endpoint is implemented.
    return [];
    /*
    final uri = Uri.parse(
      '$baseUrl/api/leads/stats/by-agent',
    ).replace(queryParameters: {'days': '$days'});
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to load agent stats');
    */
  }

  static Future<Map<String, dynamic>> getLeadsSummary() async {
    // Correct endpoint: /v1/lead-configuration/dashboard/analytics
    final uri = Uri.parse('$baseUrl/v1/lead-configuration/dashboard/analytics');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;

      if (data == null) {
        return {'total': 0, 'statusStats': [], 'sourceStats': []};
      }

      // Parse Overview
      final overview = data['overview'] as Map<String, dynamic>?;
      final total = overview?['totalLeads'] ?? 0;

      // Parse Status Counts (Map -> List)
      final statusCounts = data['statusCounts'] as Map<String, dynamic>? ?? {};
      final statusStats = statusCounts.entries.map((e) {
        return {'name': e.key, 'count': e.value};
      }).toList();

      // Parse Source Performance (List -> List with key mapping)
      final sourcePerf = data['sourcePerformance'] as List<dynamic>? ?? [];
      final sourceStats = sourcePerf.map((e) {
        return {'name': e['source'], 'count': e['leads']};
      }).toList();

      return {
        'total': total,
        'statusStats': statusStats,
        'sourceStats': sourceStats,
      };
    }
    throw Exception('Failed to load leads summary: ${resp.statusCode}');
  }
}
