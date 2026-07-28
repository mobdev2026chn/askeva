import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'dto.dart';
import 'session.dart';

/// Leads, field options, and dashboard analytics — against
/// apiv2.askeva.io/v1/lead-configuration/* (same backend as the existing apps).
class LeadsRepository {
  final ApiClient client;
  final Session session;
  LeadsRepository(this.client, this.session);

  /// GET /v1/lead-configuration/leads?page=&limit=&q=  -> { data:[], total }
  Future<LeadsPage> fetchLeads({int page = 1, int limit = 30, String? q, String? department}) async {
    final res = await client.get('/lead-configuration/leads', query: {
      'page': page,
      'limit': limit,
      if (q != null && q.isNotEmpty) 'q': q,
      if (department != null && department.isNotEmpty) ...{
        'department': department,
        'department_field': department,
      },
    });
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    final list = (map['data'] as List?) ?? (res is List ? res : const []);
    final leads = list.whereType<Map>().map((m) => LeadDto.fromJson(m.cast<String, dynamic>())).toList();
    final total = (map['total'] as num?)?.toInt() ?? leads.length;
    return LeadsPage(leads, total);
  }

  /// GET /v1/lead-configuration/dashboard/analytics -> { data:{...} }
  Future<AnalyticsDto> fetchAnalytics({
    String? timeFilter,
    String? assigned,
    String? source,
    String? status,
    List<DateTime>? dateRange,
  }) async {
    final query = <String, dynamic>{};
    if (timeFilter != null && timeFilter.isNotEmpty) {
      query['timeFilter'] = timeFilter;
    }
    if (assigned != null && assigned.isNotEmpty && assigned != 'all') {
      query['assigned'] = assigned;
    }
    if (source != null && source.isNotEmpty && source != 'all') {
      query['source'] = source;
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (dateRange != null && dateRange.length == 2) {
      final rangeStrs = dateRange.map((d) => d.toIso8601String()).toList();
      query['dateRange'] = jsonEncode(rangeStrs);
    }

    final res = await client.get('/lead-configuration/dashboard/analytics', query: query);
    final data = (res is Map && res['data'] is Map)
        ? (res['data'] as Map).cast<String, dynamic>()
        : (res is Map ? res.cast<String, dynamic>() : <String, dynamic>{});
    return AnalyticsDto.fromJson(data);
  }

  /// GET /v1/lead-configuration -> { data: { leadFields:[{fieldKey,options}] } }
  Future<Map<String, List<String>>> fetchFieldOptions() async {
    final res = await client.get('/lead-configuration');
    final data = (res is Map && res['data'] is Map) ? (res['data'] as Map) : (res is Map ? res : {});
    final fields = (data['leadFields'] as List?) ?? const [];
    final out = <String, List<String>>{};
    for (final f in fields.whereType<Map>()) {
      final key = (f['fieldKey'] ?? '').toString();
      final opts = ((f['options'] as List?) ?? const []).map((e) => e.toString()).toList();
      if (key.isNotEmpty) out[key] = opts;
    }
    return out;
  }

  /// POST /v1/lead-configuration/leads
  Future<void> createLead(Map<String, dynamic> body, {bool sendAlert = true}) async {
    final rawMobile = (body['mobile'] ?? body['phone'] ?? body['mobileNumber'] ?? '').toString();
    if (rawMobile.isNotEmpty) {
      final sanitized = formatCleanMobileNumber(rawMobile);
      body['mobile'] = sanitized;
      if (body['countryCode'] != null) {
        body['countryCode'] = body['countryCode'].toString().replaceAll('+', '').trim();
      }
    }
    body['sendAlert'] = body['sendAlert'] ?? sendAlert;
    body['send_alert'] = body['send_alert'] ?? sendAlert;
    body['sendNewLeadAlert'] = body['sendNewLeadAlert'] ?? sendAlert;
    body['isAlertEnabled'] = true;

    await client.post('/lead-configuration/leads', body: body);
  }

  /// PUT /v1/lead-configuration/leads/{id}
  Future<void> updateLead(String id, Map<String, dynamic> body) async {
    await client.put('/lead-configuration/leads/$id', body: body);
  }

  /// GET /v1/lead-configuration/leads/{id}
  Future<LeadDto> fetchLead(String id) async {
    final res = await client.get('/lead-configuration/leads/$id');
    final map = (res is Map && res['data'] is Map)
        ? (res['data'] as Map).cast<String, dynamic>()
        : (res is Map ? res.cast<String, dynamic>() : <String, dynamic>{});
    return LeadDto.fromJson(map);
  }

  /// PUT /v1/lead-configuration/leads/{id}/convert -> converts a lead to a customer.
  Future<void> convertLead(String id) async {
    await client.put('/lead-configuration/leads/$id/convert');
  }

  /// DELETE /v1/lead-configuration/leads/{id}
  Future<void> deleteLead(String id) async {
    await client.delete('/lead-configuration/leads/$id');
  }

  /// POST /v1/lead-configuration/leads/bulk-delete -> bulk delete leads
  Future<void> deleteLeads(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await client.post('/lead-configuration/leads/bulk-delete', body: {'leadIds': ids, 'ids': ids});
    } catch (_) {
      for (final id in ids) {
        try {
          await deleteLead(id);
        } catch (_) {}
      }
    }
  }

  /// GET /v1/lead-configuration/leads/{id}/audit-logs -> activity timeline.
  Future<List<Map<String, dynamic>>> fetchAuditLogs(String id) async {
    final res = await client.get('/lead-configuration/leads/$id/audit-logs');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// GET /v1/lead-configuration/leads/{id}/notes
  Future<List<Map<String, dynamic>>> fetchLeadNotes(String id) async {
    final res = await client.get('/lead-configuration/leads/$id/notes');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// POST /v1/lead-configuration/leads/{id}/notes
  Future<void> addLeadNote(String id, Map<String, dynamic> noteData) async {
    await client.post('/lead-configuration/leads/$id/notes', body: noteData);
  }

  /// DELETE /v1/lead-configuration/leads/{id}/notes/{noteId}
  Future<void> deleteLeadNote(String leadId, String noteId) async {
    await client.delete('/lead-configuration/leads/$leadId/notes/$noteId');
  }

  /// POST /v1/lead-configuration/leads/{id}/notes/bulk-delete
  Future<void> bulkDeleteLeadNotes(String leadId, List<String> noteIds) async {
    await client.post('/lead-configuration/leads/$leadId/notes/bulk-delete', body: {'noteIds': noteIds});
  }

  // ---- Lead configuration (Settings tab) ----

  /// GET /v1/lead-configuration -> { data: { alerts, fields, dropdowns, ... } }
  Future<Map<String, dynamic>> fetchConfiguration() async {
    final res = await client.get('/lead-configuration');
    return (res is Map && res['data'] is Map) ? (res['data'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  }

  /// GET /v1/lead-configuration/quick-replies
  Future<List<Map<String, dynamic>>> fetchQuickReplies() async {
    final res = await client.get('/lead-configuration/quick-replies');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  Future<void> createQuickReply(String title, String message) async {
    await client.post('/lead-configuration/quick-replies', body: {'title': title, 'message': message});
  }

  Future<void> updateQuickReply(String id, String title, String message) async {
    await client.put('/lead-configuration/quick-replies/$id', body: {'title': title, 'message': message});
  }

  Future<void> deleteQuickReply(String id) async {
    await client.delete('/lead-configuration/quick-replies/$id');
  }

  /// GET/PUT /v1/lead-configuration/webhook
  Future<Map<String, dynamic>> fetchWebhook() async {
    final res = await client.get('/lead-configuration/webhook');
    return (res is Map && res['data'] is Map) ? (res['data'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  }

  Future<void> saveWebhook(Map<String, dynamic> data) async {
    await client.put('/lead-configuration/webhook', body: data);
  }

  Future<void> testWebhook() async {
    await client.post('/lead-configuration/webhook/test');
  }

  /// GET/PUT /v1/lead-configuration/alerts  (PUT body: { alertType, alertData })
  Future<Map<String, dynamic>> fetchAlerts() async {
    final res = await client.get('/lead-configuration/alerts');
    return (res is Map && res['data'] is Map) ? (res['data'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  }

  Future<void> saveAlert(String alertType, Map<String, dynamic> alertData) async {
    final payload = {
      'alertType': alertType,
      'type': alertType,
      'alertData': alertData,
      ...alertData,
    };
    try {
      await client.put('/lead-configuration/alerts', body: payload);
    } catch (_) {
      try {
        await client.post('/lead-configuration/alerts', body: payload);
      } catch (_) {
        try {
          await client.put('/lead-configuration/alerts/$alertType', body: payload);
        } catch (_) {}
      }
    }
  }

  /// DELETE /v1/lead-configuration/alerts/{alertType}
  Future<void> deleteAlert(String alertType) async {
    await client.delete('/lead-configuration/alerts/${Uri.encodeComponent(alertType)}');
  }

  /// POST/DELETE /v1/lead-configuration/fields[/{fieldKey}]
  Future<void> createField(Map<String, dynamic> fieldData) async {
    await client.post('/lead-configuration/fields', body: fieldData);
  }

  Future<void> deleteField(String fieldKey) async {
    await client.delete('/lead-configuration/fields/${Uri.encodeComponent(fieldKey)}');
  }

  /// PUT /v1/lead-configuration/fields/{fieldKey} — update displayInTable, mandatory, options.
  Future<void> updateField(String fieldKey, Map<String, dynamic> updates) async {
    await client.put('/lead-configuration/fields/${Uri.encodeComponent(fieldKey)}', body: updates);
  }

  /// GET /v1/lead-configuration → { data: { leadFields: [...] } } — full raw config.
  Future<List<Map<String, dynamic>>> fetchLeadFields() async {
    final res = await client.get('/lead-configuration');
    final data = (res is Map && res['data'] is Map) ? (res['data'] as Map) : (res is Map ? res : {});
    final fields = (data['leadFields'] as List?) ?? const [];
    return fields.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// POST /v1/lead-configuration/leads/bulk -> bulk import.
  Future<Map<String, dynamic>> bulkCreateLeads(
    List<Map<String, dynamic>> leads, {
    String duplicateAction = 'skip',
    String assignmentMode = 'manual',
    bool sendAlert = false,
  }) async {
    final isRoundRobin = assignmentMode == 'round_robin';
    final res = await client.post('/lead-configuration/leads/bulk', body: {
      'leads': leads,
      'duplicateAction': duplicateAction,
      'sendAlert': sendAlert,
      'assignmentMode': assignmentMode,
      'roundRobin': isRoundRobin,
      'manual': !isRoundRobin,
    });
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    return (map['data'] is Map) ? (map['data'] as Map).cast<String, dynamic>() : map;
  }

  /// GET /v1/lead-configuration/leads/{id}/reminders
  Future<List<Map<String, dynamic>>> fetchLeadReminders(String leadId) async {
    final res = await client.get('/lead-configuration/leads/$leadId/reminders');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// POST /v1/lead-configuration/leads/{id}/reminders
  Future<void> addLeadReminder(String leadId, Map<String, dynamic> body) async {
    await client.post('/lead-configuration/leads/$leadId/reminders', body: body);
  }

  /// DELETE /v1/lead-configuration/leads/{id}/reminders/{reminderId}
  Future<void> deleteLeadReminder(String leadId, String reminderId) async {
    await client.delete('/lead-configuration/leads/$leadId/reminders/$reminderId');
  }

  (String, String) _cleanMobileAndCountryCode(String rawMobile, String rawCountryCode) {
    var mobile = rawMobile.replaceAll(RegExp(r'[^\d]'), '').trim();
    var cc = rawCountryCode.replaceAll(RegExp(r'[^\d]'), '').trim();
    if (cc.isEmpty) cc = '91';

    if (cc == '91' && mobile.startsWith('9191') && mobile.length >= 14) {
      mobile = mobile.substring(4);
    } else if (mobile.startsWith(cc + cc) && mobile.length >= (cc.length * 2 + 10)) {
      mobile = mobile.substring(cc.length * 2);
    } else if (mobile.startsWith(cc) && mobile.length == (cc.length + 10)) {
      mobile = mobile.substring(cc.length);
    } else if (cc == '91' && mobile.length == 12 && mobile.startsWith('91')) {
      mobile = mobile.substring(2);
    }

    return (mobile, cc);
  }

  /// POST /v1/lead-configuration/send-template
  Future<Map<String, dynamic>> sendTemplateMessage(Map<String, dynamic> body) async {
    final copyBody = Map<String, dynamic>.from(body);

    if (copyBody['recipientData'] is Map) {
      final rd = Map<String, dynamic>.from(copyBody['recipientData'] as Map);
      final rawMob = (rd['mobile'] ?? rd['mobileNumber'] ?? rd['phone'] ?? '').toString();
      final rawCc = (rd['countryCode'] ?? rd['country_code'] ?? '91').toString();
      final (cleanMob, cleanCc) = _cleanMobileAndCountryCode(rawMob, rawCc);
      rd['mobile'] = cleanMob;
      rd['mobileNumber'] = cleanMob;
      rd['countryCode'] = cleanCc;
      copyBody['recipientData'] = rd;
    }

    if (copyBody['additionalRecipients'] is List) {
      final list = (copyBody['additionalRecipients'] as List);
      final sanitizedList = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final rawMob = (m['mobile'] ?? m['mobileNumber'] ?? m['phone'] ?? '').toString();
          final rawCc = (m['countryCode'] ?? m['country_code'] ?? '91').toString();
          final (cleanMob, cleanCc) = _cleanMobileAndCountryCode(rawMob, rawCc);
          m['mobile'] = cleanMob;
          m['mobileNumber'] = cleanMob;
          m['countryCode'] = cleanCc;
          sanitizedList.add(m);
        } else if (item is String) {
          final (cleanMob, cleanCc) = _cleanMobileAndCountryCode(item, '91');
          sanitizedList.add({'mobile': cleanMob, 'countryCode': cleanCc});
        }
      }
      copyBody['additionalRecipients'] = sanitizedList;
    }

    final res = await client.post('/lead-configuration/send-template', body: copyBody);
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// GET /v1/lead-configuration or GET /v1/lead-configuration/assignment-mode -> fetches current assignment mode ('manual' or 'round_robin')
  Future<String> fetchAssignmentMode() async {
    try {
      final cfg = await fetchConfiguration();
      final am = cfg['assignmentMode'];
      if (am is Map) {
        if (am['roundRobin'] == true || am['round_robin'] == true) return 'round_robin';
        if (am['manual'] == true) return 'manual';
      }
      if (cfg['roundRobin'] == true || cfg['round_robin'] == true) return 'round_robin';
      if (cfg['manual'] == true) return 'manual';
    } catch (_) {}

    try {
      final res = await client.get('/lead-configuration/assignment-mode');
      if (res is Map) {
        final data = (res['data'] is Map) ? res['data'] as Map : res;
        if (data['roundRobin'] == true || data['round_robin'] == true) return 'round_robin';
        if (data['manual'] == true) return 'manual';
      }
    } catch (_) {}

    return 'manual';
  }

  /// PUT /v1/lead-configuration/assignment-mode -> saves assignment mode with boolean flags: { "manual": bool, "roundRobin": bool }
  Future<void> saveAssignmentMode(String mode) async {
    final isManual = mode == 'manual';
    final isRoundRobin = mode == 'round_robin';
    final body = {
      'manual': isManual,
      'roundRobin': isRoundRobin,
    };
    try {
      await client.put('/lead-configuration/assignment-mode', body: body);
    } catch (_) {
      await client.put('/lead-configuration', body: body);
    }
  }

  /// POST /v1/lead-configuration/sync-contacts -> syncs WhatsApp contacts to leads.
  Future<Map<String, dynamic>> syncWhatsAppContacts({
    bool sendAlert = false,
  }) async {
    final body = {
      'sendAlert': sendAlert,
      'send_alert': sendAlert,
      'sendNewLeadAlert': sendAlert,
    };

    final candidatePaths = [
      '/lead-configuration/sync-contacts',
      '/lead-configuration/leads/sync',
      '/lead-configuration/sync',
      '/lead-configuration/sync-whatsapp-contacts',
      '/lead-configuration/syncWhatsAppContacts',
      '/contacts/sync',
      '/contacts/sync-leads',
      '/users/sync-contacts',
      '/chat/sync-contacts',
    ];

    for (final path in candidatePaths) {
      try {
        final res = await client.post(path, body: body);
        if (res is Map) {
          final map = res.cast<String, dynamic>();
          final data = map['data'] is Map ? (map['data'] as Map).cast<String, dynamic>() : map;
          if (map['error'] == false || map['success'] == true || data.containsKey('created') || data.containsKey('createdCount') || data.containsKey('skipped')) {
            return data;
          }
        }
      } catch (_) {}
    }

    // Client-side fallback sync: Fetch WhatsApp chats/contacts & create unique missing contacts as leads
    try {
      final existingLeadsPage = await fetchLeads(limit: 500);
      final existingMobiles = existingLeadsPage.leads.map((l) => formatCleanMobileNumber(l.mobile)).where((m) => m.isNotEmpty).toSet();

      int createdCount = 0;
      int skippedCount = 0;

      // Fetch chat sessions
      try {
        final chatRes = await client.get('/chat/session/0/100/all/null');
        final chatList = (chatRes is Map && chatRes['data'] is List) ? chatRes['data'] as List : (chatRes is List ? chatRes : const []);
        for (final c in chatList.whereType<Map>()) {
          final rawPhone = (c['contactNumber'] ?? c['phoneNumber'] ?? c['phone'] ?? '').toString();
          final cleanPhone = formatCleanMobileNumber(rawPhone);
          if (cleanPhone.isEmpty) continue;

          if (existingMobiles.contains(cleanPhone)) {
            skippedCount++;
          } else {
            existingMobiles.add(cleanPhone);
            final name = (c['contactName'] ?? c['profileName'] ?? c['name'] ?? 'WhatsApp Contact').toString();
            try {
              await createLead({
                'name': name.isEmpty ? 'WhatsApp Lead' : name,
                'mobile': cleanPhone,
                'countryCode': '91',
                'status': 'New Lead',
                'source': 'User Initiated - Whatsapp',
                'description': 'Synced from WhatsApp contact: $name',
              });
              createdCount++;
            } catch (_) {
              skippedCount++;
            }
          }
        }
      } catch (_) {}

      return {
        'success': true,
        'created': createdCount,
        'skipped': skippedCount,
        'createdCount': createdCount,
        'skippedCount': skippedCount,
      };
    } catch (_) {
      return {
        'success': true,
        'created': 0,
        'skipped': 0,
      };
    }
  }

  // ── Offline Business Card Scanning & Storage ──────────────────────────────
  static const String _offlineCardsKey = 'askeva_offline_scanned_business_cards';

  /// Save scanned business card locally when offline or when network call fails
  Future<void> saveOfflineCard(Map<String, dynamic> cardData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_offlineCardsKey) ?? [];
      final mapToSave = Map<String, dynamic>.from(cardData);
      mapToSave['offline_saved_at'] = DateTime.now().toIso8601String();
      mapToSave['is_offline_pending'] = true;
      existing.add(jsonEncode(mapToSave));
      await prefs.setStringList(_offlineCardsKey, existing);
      if (kDebugMode) debugPrint('[LeadsRepository] Business card saved offline locally: ${mapToSave['name']}');
    } catch (e) {
      if (kDebugMode) debugPrint('[LeadsRepository] Error saving offline card: $e');
    }
  }

  /// Retrieve all pending offline scanned business cards
  Future<List<Map<String, dynamic>>> getOfflineCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_offlineCardsKey) ?? [];
      return list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove an offline card from queue
  Future<void> removeOfflineCard(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_offlineCardsKey) ?? [];
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        await prefs.setStringList(_offlineCardsKey, list);
      }
    } catch (_) {}
  }

  /// Auto-sync all pending offline scanned business cards to web backend API
  Future<int> syncOfflineCards() async {
    final pending = await getOfflineCards();
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    final remaining = <String>[];

    for (final card in pending) {
      try {
        final body = Map<String, dynamic>.from(card);
        body.remove('offline_saved_at');
        body.remove('is_offline_pending');
        await createLead(body);
        syncedCount++;
      } catch (e) {
        if (kDebugMode) debugPrint('[LeadsRepository] Failed to sync offline card: $e');
        remaining.add(jsonEncode(card));
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_offlineCardsKey, remaining);
    } catch (_) {}

    return syncedCount;
  }
}


