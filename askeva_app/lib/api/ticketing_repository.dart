import 'api_client.dart';
import 'dto.dart';
import 'session.dart';

/// Support tickets — against apiv2.askeva.io/v1/ticketing/*
class TicketingRepository {
  final ApiClient client;
  final Session session;
  TicketingRepository(this.client, this.session);

  static void Function(String message, {bool isError})? onApiCall;

  void _notify(String method, String endpoint, {Object? body, Object? query, bool isError = false}) {
    final buffer = StringBuffer('API: $method $endpoint');
    if (query != null) buffer.write('\nQuery: $query');
    if (body != null) buffer.write('\nBody: $body');
    onApiCall?.call(buffer.toString(), isError: isError);
  }

  static List<Map<String, dynamic>> _list(dynamic res) {
    if (res is Map) {
      final d = res['data'] ?? res['tickets'] ?? res['rows'] ?? res['responses'] ?? res['feedback'] ?? res['feedbacks'];
      if (d is List) return d.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (d is Map && d['tickets'] is List) return (d['tickets'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (d is Map && d['responses'] is List) return (d['responses'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (d is Map && d['rows'] is List) return (d['rows'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (d is Map && d['data'] is List) return (d['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    if (res is List) return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    return const [];
  }

  /// GET /v1/ticketing/?status=&priority=&search=&page=&limit=&department=&isSpam=&isStarred=
  Future<List<TicketDto>> fetchTickets({
    String? status,
    String? priority,
    String? search,
    int page = 1,
    int limit = 10000,
    String? department,
    bool? isSpam,
    bool? isStarred,
  }) async {
    final query = {
      'page': page,
      'limit': limit,
      if (status != null && status.isNotEmpty) 'status': status,
      if (priority != null && priority.isNotEmpty) 'priority': priority,
      if (search != null && search.isNotEmpty) 'search': search,
      if (department != null && department.isNotEmpty) 'department': department,
      if (isSpam != null) 'isSpam': isSpam,
      if (isStarred != null) 'isStarred': isStarred,
    };
    try {
      final res = await client.get('/ticketing/', query: query);
      _notify('GET', '/v1/ticketing/', query: query);
      return _list(res).map(TicketDto.fromJson).toList();
    } catch (e) {
      _notify('GET', '/v1/ticketing/', query: query, isError: true);
      rethrow;
    }
  }

  /// GET /v1/ticketing/tickets/{id}
  Future<Map<String, dynamic>> fetchTicket(String id) async {
    try {
      final res = await client.get('/ticketing/tickets/$id');
      _notify('GET', '/v1/ticketing/tickets/$id');
      if (res is Map && res['data'] is Map) return (res['data'] as Map).cast<String, dynamic>();
      if (res is Map) return res.cast<String, dynamic>();
    } catch (_) {
      try {
        final list = await fetchTickets();
        final match = list.firstWhere(
          (t) => t.id == id || t.dbId == id,
          orElse: () => TicketDto(dbId: id, id: id, customer: '', mobile: '', agent: '', department: '', subject: '', priority: 'Low', status: 'Pending'),
        );
        return match.toJson();
      } catch (_) {}
      _notify('GET', '/v1/ticketing/tickets/$id', isError: true);
    }
    return <String, dynamic>{};
  }

  /// GET /v1/ticketing/dashboard
  Future<Map<String, dynamic>> fetchDashboard() async {
    try {
      final res = await client.get('/ticketing/dashboard');
      _notify('GET', '/v1/ticketing/dashboard');
      if (res is Map && res['data'] is Map) return (res['data'] as Map).cast<String, dynamic>();
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (e) {
      _notify('GET', '/v1/ticketing/dashboard', isError: true);
      rethrow;
    }
  }

  /// GET /v1/ticketing/stats
  Future<Map<String, dynamic>> fetchStats() async {
    try {
      final res = await client.get('/ticketing/stats');
      _notify('GET', '/v1/ticketing/stats');
      if (res is Map && res['data'] is Map) return (res['data'] as Map).cast<String, dynamic>();
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (_) {
      _notify('GET', '/v1/ticketing/stats', isError: true);
      return {};
    }
  }

  /// GET /v1/ticketing/settings/sla-policies  → extract active department names
  Future<List<String>> fetchDepartments() async {
    try {
      final res = await client.get('/ticketing/settings/sla-policies');
      _notify('GET', '/v1/ticketing/settings/sla-policies');
      final list = _list(res);
      return list
          .where((m) => m['active'] == true && m['department'] != null)
          .map((m) => m['department'].toString())
          .toSet()
          .toList();
    } catch (_) {
      _notify('GET', '/v1/ticketing/settings/sla-policies', isError: true);
      return [];
    }
  }

  /// GET /v1/agents/agents?activeOnly=true
  Future<List<Map<String, dynamic>>> fetchAgents() async {
    try {
      final res = await client.get('/agents/agents', query: {'activeOnly': true});
      _notify('GET', '/v1/agents/agents', query: {'activeOnly': true});
      return _list(res);
    } catch (_) {
      _notify('GET', '/v1/agents/agents', query: {'activeOnly': true}, isError: true);
      return [];
    }
  }

  /// GET /v1/ticketing/settings/configuration  → custom fields
  Future<Map<String, dynamic>> fetchConfiguration() async {
    try {
      final res = await client.get('/ticketing/settings/configuration');
      _notify('GET', '/v1/ticketing/settings/configuration');
      if (res is Map && res['data'] is Map) return (res['data'] as Map).cast<String, dynamic>();
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (_) {
      _notify('GET', '/v1/ticketing/settings/configuration', isError: true);
      return {};
    }
  }

  /// GET /v1/whatsapp-flows/ticket-feedback/responses  → customer feedback
  Future<List<Map<String, dynamic>>> fetchFeedback({int page = 1, int limit = 50}) async {
    try {
      final res = await client.get('/whatsapp-flows/ticket-feedback/responses', query: {'page': page, 'limit': limit});
      _notify('GET', '/v1/whatsapp-flows/ticket-feedback/responses', query: {'page': page, 'limit': limit});
      return _list(res);
    } catch (_) {
      _notify('GET', '/v1/whatsapp-flows/ticket-feedback/responses', query: {'page': page, 'limit': limit}, isError: true);
      return [];
    }
  }

  /// GET /v1/ticketing/customers/suggestions
  Future<List<Map<String, dynamic>>> fetchCustomerSuggestions({
    required String type,
    required String value,
    String? department,
  }) async {
    try {
      final res = await client.get('/ticketing/customers/suggestions', query: {
        'type': type,
        'value': value,
        if (department != null && department.isNotEmpty) 'department': department,
      });
      print('SUGGESTIONS RESPONSE FOR type=$type, value=$value, dept=$department: $res');
      _notify('GET', '/v1/ticketing/customers/suggestions', query: {
        'type': type,
        'value': value,
        if (department != null && department.isNotEmpty) 'department': department,
      });
      return _list(res);
    } catch (_) {
      _notify('GET', '/v1/ticketing/customers/suggestions', query: {
        'type': type,
        'value': value,
        if (department != null && department.isNotEmpty) 'department': department,
      }, isError: true);
      return [];
    }
  }

  /// POST /v1/filehandler/upload/chatbot
  Future<String> uploadDocument(List<int> bytes, String filename) async {
    try {
      final res = await client.uploadFile('/filehandler/upload/chatbot', field: 'file', bytes: bytes, filename: filename);
      if (res is Map) {
        final url = res['fileUrl'] ?? (res['data'] is Map ? res['data']['url'] : null);
        if (url != null) return url.toString();
      }
      throw Exception('URL not found in response');
    } catch (_) {
      rethrow;
    }
  }

  /// POST /v1/ticketing/tickets — body: { ticketData: {...}, leadUpdate: {} }
  Future<void> createTicket(Map<String, dynamic> ticketData) async {
    final rawMobile = (ticketData['mobileNumber'] ?? ticketData['mobile'] ?? ticketData['phone'] ?? '').toString();
    if (rawMobile.isNotEmpty) {
      final sanitized = formatCleanMobileNumber(rawMobile);
      ticketData['mobileNumber'] = sanitized;
      ticketData['mobile'] = sanitized;
    }

    final body = {
      'ticketData': ticketData,
      'leadUpdate': {}, // Do NOT create or save a duplicate lead entry when ticket is created
    };
    try {
      await client.post('/ticketing/tickets', body: body);
      _notify('POST', '/v1/ticketing/tickets', body: body);
    } catch (e) {
      _notify('POST', '/v1/ticketing/tickets', body: body, isError: true);
      rethrow;
    }
  }

  /// PATCH / PUT /v1/ticketing/tickets/{id}/status
  Future<void> updateTicketStatus(String id, String status, {String description = '', String reason = 'Status updated', String? mongoId}) async {
    final body = {
      'status': status,
      'description': description,
      'reason': reason,
    };
    final targetId = (mongoId != null && mongoId.isNotEmpty) ? mongoId : id;
    final ids = [targetId, if (targetId != id) id];

    for (final tid in ids) {
      final endpoints = [
        ('/ticketing/tickets/$tid/status', 'PATCH'),
        ('/ticketing/tickets/$tid/status', 'PUT'),
        ('/ticketing/tickets/$tid', 'PATCH'),
        ('/ticketing/tickets/$tid', 'PUT'),
      ];
      for (final (ep, method) in endpoints) {
        try {
          if (method == 'PATCH') {
            await client.patch(ep, body: body);
          } else {
            await client.put(ep, body: body);
          }
          _notify(method, '/v1$ep', body: body);
          return;
        } catch (_) {}
      }
    }
    _notify('PATCH', '/v1/ticketing/tickets/$targetId/status', body: body, isError: true);
  }

  /// PATCH / PUT /v1/ticketing/tickets/{id}/priority
  Future<void> updateTicketPriority(String id, String priority, {String reason = '', String? mongoId}) async {
    final body = {
      'priority': priority,
      'reason': reason,
    };
    final targetId = (mongoId != null && mongoId.isNotEmpty) ? mongoId : id;
    final ids = [targetId, if (targetId != id) id];

    for (final tid in ids) {
      final endpoints = [
        ('/ticketing/tickets/$tid/priority', 'PATCH'),
        ('/ticketing/tickets/$tid/priority', 'PUT'),
        ('/ticketing/tickets/$tid', 'PATCH'),
        ('/ticketing/tickets/$tid', 'PUT'),
      ];
      for (final (ep, method) in endpoints) {
        try {
          if (method == 'PATCH') {
            await client.patch(ep, body: body);
          } else {
            await client.put(ep, body: body);
          }
          _notify(method, '/v1$ep', body: body);
          return;
        } catch (_) {}
      }
    }
    _notify('PATCH', '/v1/ticketing/tickets/$targetId/priority', body: body, isError: true);
  }

  /// PATCH / PUT /v1/ticketing/tickets/{id}  (star / spam / agent / priority)
  Future<void> updateTicket(String id, Map<String, dynamic> body, {String? mongoId}) async {
    final targetId = (mongoId != null && mongoId.isNotEmpty) ? mongoId : id;
    final ids = [targetId, if (targetId != id) id];

    for (final tid in ids) {
      final endpoints = [
        ('/ticketing/tickets/$tid', 'PATCH'),
        ('/ticketing/tickets/$tid', 'PUT'),
      ];
      for (final (ep, method) in endpoints) {
        try {
          if (method == 'PATCH') {
            await client.patch(ep, body: body);
          } else {
            await client.put(ep, body: body);
          }
          _notify(method, '/v1$ep', body: body);
          return;
        } catch (_) {}
      }
    }
    _notify('PATCH', '/v1/ticketing/tickets/$targetId', body: body, isError: true);
  }

  /// POST /v1/ticketing/tickets/{id}/notes or /v1/ticketing/notes
  Future<void> addTicketNote(String id, String content, {String? mongoId}) async {
    final body = {
      'content': content,
      'note': content,
      'text': content,
      'description': content,
      'ticketId': mongoId ?? id,
    };
    final targetId = (mongoId != null && mongoId.isNotEmpty) ? mongoId : id;
    final ids = [targetId, if (targetId != id) id];

    for (final tid in ids) {
      final endpoints = [
        '/ticketing/tickets/$tid/notes',
        '/ticketing/tickets/$tid/personal-notes',
        '/ticketing/notes',
      ];
      for (final ep in endpoints) {
        try {
          await client.post(ep, body: body);
          _notify('POST', '/v1$ep', body: body);
          return;
        } catch (_) {}
      }
    }
    _notify('POST', '/v1/ticketing/tickets/$targetId/notes', body: body, isError: true);
  }

  /// GET /v1/ticketing/tickets/{id}/notes
  Future<List<Map<String, dynamic>>> fetchTicketNotes(String id, {String? mongoId}) async {
    final targetId = (mongoId != null && mongoId.isNotEmpty) ? mongoId : id;
    final ids = [targetId, if (targetId != id) id];

    for (final tid in ids) {
      final endpoints = [
        '/ticketing/tickets/$tid/notes',
        '/ticketing/tickets/$tid/personal-notes',
        '/ticketing/notes?ticketId=$tid',
      ];
      for (final ep in endpoints) {
        try {
          final res = await client.get(ep);
          if (res is Map && res['data'] is List) {
            return (res['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          } else if (res is List) {
            return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          }
        } catch (_) {}
      }
    }
    return [];
  }

  /// GET /v1/ticketing/settings/quick-replies
  Future<List<Map<String, dynamic>>> fetchQuickReplies() async {
    final endpoints = [
      '/ticketing/settings/quick-replies',
      '/ticketing/quick-replies',
      '/ticketing/settings/canned-responses',
    ];
    for (final ep in endpoints) {
      try {
        final res = await client.get(ep);
        if (res is Map && res['data'] is List) {
          return (res['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        } else if (res is List) {
          return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// GET /v1/ticketing/settings/video-notes
  Future<List<Map<String, dynamic>>> fetchVideoNotes() async {
    final endpoints = [
      '/ticketing/settings/video-notes',
      '/ticketing/video-notes',
    ];
    for (final ep in endpoints) {
      try {
        final res = await client.get(ep);
        if (res is Map && res['data'] is List) {
          return (res['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        } else if (res is List) {
          return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// POST /v1/ticketing/tickets/{id}/replies
  Future<void> sendTicketReply(String id, String reply, {String? videoUrl, String? mongoId}) async {
    final body = {
      'reply': reply,
      'content': reply,
      'message': reply,
      'text': reply,
      if (videoUrl != null && videoUrl.isNotEmpty) 'videoUrl': videoUrl,
    };
    final targetId = (mongoId != null && mongoId.isNotEmpty) ? mongoId : id;
    final ids = [targetId, if (targetId != id) id];

    for (final tid in ids) {
      final endpoints = [
        '/ticketing/tickets/$tid/replies',
        '/ticketing/tickets/$tid/reply',
        '/ticketing/tickets/$tid/comments',
      ];
      for (final ep in endpoints) {
        try {
          await client.post(ep, body: body);
          _notify('POST', '/v1$ep', body: body);
          return;
        } catch (_) {}
      }
    }
    _notify('POST', '/v1/ticketing/tickets/$targetId/replies', body: body, isError: true);
  }

  /// GET /v1/ticketing/tickets/{id}/replies
  Future<List<Map<String, dynamic>>> fetchTicketReplies(String id, {String? mongoId}) async {
    final targetId = (mongoId != null && mongoId.isNotEmpty) ? mongoId : id;
    final ids = [targetId, if (targetId != id) id];

    for (final tid in ids) {
      final endpoints = [
        '/ticketing/tickets/$tid/replies',
        '/ticketing/tickets/$tid/reply',
        '/ticketing/tickets/$tid/comments',
        '/ticketing/tickets/$tid/messages',
      ];
      for (final ep in endpoints) {
        try {
          final res = await client.get(ep);
          if (res is Map && res['data'] is List) {
            return (res['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          } else if (res is List) {
            return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          }
        } catch (_) {}
      }
    }
    return [];
  }

  /// POST /v1/contacts/block or /v1/customers/block or /v1/lead-configuration/block-customer
  Future<void> blockCustomer(String mobile) async {
    if (mobile.isEmpty) return;
    final sanitized = formatCleanMobileNumber(mobile);
    final body = {
      'mobile': sanitized,
      'mobileNumber': sanitized,
      'customerMobile': sanitized,
      'reason': 'Blocked via Ticketing Spam Action',
    };
    final endpoints = [
      '/contacts/block',
      '/customers/block',
      '/lead-configuration/block-customer',
      '/ticketing/block-customer',
    ];
    for (final ep in endpoints) {
      try {
        await client.post(ep, body: body);
        _notify('POST', '/v1$ep', body: body);
        return;
      } catch (_) {}
    }
    _notify('POST', '/v1/contacts/block', body: body, isError: true);
  }

  /// GET /v1/ticketing/tickets/{id}/activity-logs  or  /audit-logs  or  /logs
  Future<List<Map<String, dynamic>>> fetchTicketAuditLogs(String id, {String? mongoId}) async {
    final ids = [id, if (mongoId != null && mongoId.isNotEmpty && mongoId != id) mongoId];
    for (final targetId in ids) {
      final endpoints = [
        '/ticketing/tickets/$targetId/activity-logs',
        '/ticketing/tickets/$targetId/audit-logs',
        '/ticketing/tickets/$targetId/activities',
        '/ticketing/tickets/$targetId/logs',
      ];
      for (final ep in endpoints) {
        try {
          final res = await client.get(ep);
          _notify('GET', '/v1$ep');
          final list = (res is Map && res['data'] is List)
              ? res['data'] as List
              : ((res is Map && res['logs'] is List) ? res['logs'] as List : (res is List ? res : const []));
          final parsed = list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          if (parsed.isNotEmpty) return parsed;
        } catch (_) {}
      }
    }
    _notify('GET', '/v1/ticketing/tickets/$id/activity-logs', isError: true);
    return [];
  }

  /// GET /v1/ticketing/tickets/{id}/history  or  /history/{mobile}  or  /tickets?search={mobile}
  Future<List<TicketDto>> fetchCustomerTicketHistory(String ticketId, {String? mobile, String? mongoId}) async {
    final cleanMobile = mobile != null ? formatCleanMobileNumber(mobile) : '';
    final ids = [ticketId, if (mongoId != null && mongoId.isNotEmpty && mongoId != ticketId) mongoId];
    final endpoints = [
      for (final tid in ids) '/ticketing/tickets/$tid/history',
      if (cleanMobile.isNotEmpty) '/ticketing/tickets/history/$cleanMobile',
      if (cleanMobile.isNotEmpty) '/ticketing/tickets?search=$cleanMobile',
      if (cleanMobile.isNotEmpty) '/ticketing/tickets?mobile=$cleanMobile',
    ];

    for (final ep in endpoints) {
      try {
        final res = await client.get(ep);
        _notify('GET', '/v1$ep');
        final list = _list(res);
        if (list.isNotEmpty) {
          return list.map(TicketDto.fromJson).toList();
        }
      } catch (_) {}
    }
    _notify('GET', '/v1/ticketing/tickets/$ticketId/history', isError: true);
    return [];
  }

  /// GET /v1/ticketing/tickets/{id}/sent-templates
  Future<List<Map<String, dynamic>>> fetchSentTemplatesHistory(String ticketId, {String? mongoId}) async {
    final ids = [ticketId, if (mongoId != null && mongoId.isNotEmpty && mongoId != ticketId) mongoId];
    for (final tid in ids) {
      try {
        final res = await client.get('/ticketing/tickets/$tid/sent-templates');
        _notify('GET', '/v1/ticketing/tickets/$tid/sent-templates');
        final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
        if (list.isNotEmpty) return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      } catch (_) {
        try {
          final res = await client.get('/ticketing/tickets/$tid/templates-history');
          _notify('GET', '/v1/ticketing/tickets/$tid/templates-history');
          final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
          if (list.isNotEmpty) return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        } catch (_) {}
      }
    }
    _notify('GET', '/v1/ticketing/tickets/$ticketId/sent-templates', isError: true);
    return [];
  }

  /// POST /v1/ticketing/tickets/{id}/send-template
  Future<Map<String, dynamic>> sendTicketTemplate(String ticketId, Map<String, dynamic> data) async {
    final templateName = (data['templateName'] ?? 'test_with_three_actions').toString();
    final templateId = (data['templateId'] ?? data['templateName'] ?? 'test_with_three_actions').toString();
    final mobile = formatCleanMobileNumber((data['mobileNumber'] ?? data['mobile'] ?? '').toString());

    final body = {
      'templateId': templateId,
      'templateName': templateName,
      'mobileNumber': mobile,
      'ticketStatus': data['ticketStatus'] ?? 'Pending',
      'description': data['description'] ?? '',
      'recipientData': {
        'name': data['customerName'] ?? 'Customer',
        'countryCode': '91',
        'mobile': mobile,
        'ticketId': ticketId,
      },
      ...data,
    };

    try {
      final res = await client.post('/lead-configuration/send-template', body: body);
      _notify('POST', '/v1/lead-configuration/send-template', body: body);
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (_) {
      try {
        final res = await client.post('/ticketing/tickets/$ticketId/send-template', body: body);
        _notify('POST', '/v1/ticketing/tickets/$ticketId/send-template', body: body);
        return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
      } catch (e) {
        _notify('POST', '/v1/lead-configuration/send-template', body: body, isError: true);
        rethrow;
      }
    }
  }

  /// DELETE /v1/ticketing/tickets/{id}/sent-templates/{templateId}
  Future<void> deleteSentTemplate(String ticketId, String templateId) async {
    try {
      await client.delete('/ticketing/tickets/$ticketId/sent-templates/$templateId');
      _notify('DELETE', '/v1/ticketing/tickets/$ticketId/sent-templates/$templateId');
    } catch (e) {
      _notify('DELETE', '/v1/ticketing/tickets/$ticketId/sent-templates/$templateId', isError: true);
    }
  }

  // ── SLA Policies ──────────────────────────────────────────────────────────

  /// GET /v1/ticketing/settings/sla-policies
  Future<List<Map<String, dynamic>>> fetchSlaPolicies() async {
    try {
      final res = await client.get('/ticketing/settings/sla-policies');
      _notify('GET', '/v1/ticketing/settings/sla-policies');
      return _list(res);
    } catch (e) {
      _notify('GET', '/v1/ticketing/settings/sla-policies', isError: true);
      rethrow;
    }
  }

  /// POST /v1/ticketing/settings/sla-policies
  Future<void> createSlaPolicy(Map<String, dynamic> policy) async {
    try {
      await client.post('/ticketing/settings/sla-policies', body: policy);
      _notify('POST', '/v1/ticketing/settings/sla-policies', body: policy);
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/sla-policies', body: policy, isError: true);
      rethrow;
    }
  }

  /// PUT /v1/ticketing/settings/sla-policies/{id}
  Future<void> updateSlaPolicy(String id, Map<String, dynamic> policy) async {
    try {
      await client.put('/ticketing/settings/sla-policies/$id', body: policy);
      _notify('PUT', '/v1/ticketing/settings/sla-policies/$id', body: policy);
    } catch (e) {
      _notify('PUT', '/v1/ticketing/settings/sla-policies/$id', body: policy, isError: true);
      rethrow;
    }
  }

  /// DELETE /v1/ticketing/settings/sla-policies/{id}
  Future<void> deleteSlaPolicy(String id) async {
    try {
      await client.delete('/ticketing/settings/sla-policies/$id');
      _notify('DELETE', '/v1/ticketing/settings/sla-policies/$id');
    } catch (e) {
      _notify('DELETE', '/v1/ticketing/settings/sla-policies/$id', isError: true);
      rethrow;
    }
  }

  /// PATCH /v1/ticketing/settings/sla-policies/{id}/toggle
  Future<void> toggleSlaPolicyStatus(String id) async {
    try {
      await client.patch('/ticketing/settings/sla-policies/$id/toggle');
      _notify('PATCH', '/v1/ticketing/settings/sla-policies/$id/toggle');
    } catch (e) {
      _notify('PATCH', '/v1/ticketing/settings/sla-policies/$id/toggle', isError: true);
      rethrow;
    }
  }

  // ── Quick Replies ─────────────────────────────────────────────────────────

  /// POST /v1/ticketing/settings/quick-replies
  Future<void> createQuickReply(Map<String, dynamic> data) async {
    try {
      await client.post('/ticketing/settings/quick-replies', body: data);
      _notify('POST', '/v1/ticketing/settings/quick-replies', body: data);
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/quick-replies', body: data, isError: true);
      rethrow;
    }
  }

  /// PUT /v1/ticketing/settings/quick-replies/{id}
  Future<void> updateQuickReply(String id, Map<String, dynamic> data) async {
    try {
      await client.put('/ticketing/settings/quick-replies/$id', body: data);
      _notify('PUT', '/v1/ticketing/settings/quick-replies/$id', body: data);
    } catch (e) {
      _notify('PUT', '/v1/ticketing/settings/quick-replies/$id', body: data, isError: true);
      rethrow;
    }
  }

  /// DELETE /v1/ticketing/settings/quick-replies/{id}
  Future<void> deleteQuickReply(String id) async {
    try {
      await client.delete('/ticketing/settings/quick-replies/$id');
      _notify('DELETE', '/v1/ticketing/settings/quick-replies/$id');
    } catch (e) {
      _notify('DELETE', '/v1/ticketing/settings/quick-replies/$id', isError: true);
      rethrow;
    }
  }

  // ── Video Notes ───────────────────────────────────────────────────────────

  /// POST /v1/ticketing/settings/video-notes
  Future<void> createVideoNote(Map<String, dynamic> data) async {
    try {
      await client.post('/ticketing/settings/video-notes', body: data);
      _notify('POST', '/v1/ticketing/settings/video-notes', body: data);
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/video-notes', body: data, isError: true);
      rethrow;
    }
  }

  /// PUT /v1/ticketing/settings/video-notes/{id}
  Future<void> updateVideoNote(String id, Map<String, dynamic> data) async {
    try {
      await client.put('/ticketing/settings/video-notes/$id', body: data);
      _notify('PUT', '/v1/ticketing/settings/video-notes/$id', body: data);
    } catch (e) {
      _notify('PUT', '/v1/ticketing/settings/video-notes/$id', body: data, isError: true);
      rethrow;
    }
  }

  /// DELETE /v1/ticketing/settings/video-notes/{id}
  Future<void> deleteVideoNote(String id) async {
    try {
      await client.delete('/ticketing/settings/video-notes/$id');
      _notify('DELETE', '/v1/ticketing/settings/video-notes/$id');
    } catch (e) {
      _notify('DELETE', '/v1/ticketing/settings/video-notes/$id', isError: true);
      rethrow;
    }
  }

  // ── Webhook Configuration ──────────────────────────────────────────────────

  /// GET /v1/ticketing/settings/webhook
  Future<Map<String, dynamic>> fetchWebhookSettings() async {
    try {
      final res = await client.get('/ticketing/settings/webhook');
      _notify('GET', '/v1/ticketing/settings/webhook');
      if (res is Map && res['data'] is Map) return (res['data'] as Map).cast<String, dynamic>();
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (e) {
      _notify('GET', '/v1/ticketing/settings/webhook', isError: true);
      rethrow;
    }
  }

  /// PUT /v1/ticketing/settings/webhook
  Future<void> updateWebhookSettings(Map<String, dynamic> data) async {
    try {
      await client.put('/ticketing/settings/webhook', body: data);
      _notify('PUT', '/v1/ticketing/settings/webhook', body: data);
    } catch (e) {
      _notify('PUT', '/v1/ticketing/settings/webhook', body: data, isError: true);
      rethrow;
    }
  }

  /// POST /v1/ticketing/settings/webhook/test
  Future<Map<String, dynamic>> testWebhook(Map<String, dynamic> data) async {
    try {
      final res = await client.post('/ticketing/settings/webhook/test', body: data);
      _notify('POST', '/v1/ticketing/settings/webhook/test', body: data);
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/webhook/test', body: data, isError: true);
      rethrow;
    }
  }

  // ── Departments ────────────────────────────────────────────────────────────

  /// GET /v1/ticketing/settings/departments
  Future<List<Map<String, dynamic>>> fetchAllDepartments() async {
    try {
      final res = await client.get('/ticketing/settings/departments');
      _notify('GET', '/v1/ticketing/settings/departments');
      return _list(res);
    } catch (e) {
      _notify('GET', '/v1/ticketing/settings/departments', isError: true);
      rethrow;
    }
  }

  /// POST /v1/ticketing/settings/departments
  Future<void> createDepartment(Map<String, dynamic> data) async {
    try {
      await client.post('/ticketing/settings/departments', body: data);
      _notify('POST', '/v1/ticketing/settings/departments', body: data);
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/departments', body: data, isError: true);
      rethrow;
    }
  }

  /// PUT /v1/ticketing/settings/departments/{id}
  Future<void> updateDepartment(String id, Map<String, dynamic> data) async {
    try {
      await client.put('/ticketing/settings/departments/$id', body: data);
      _notify('PUT', '/v1/ticketing/settings/departments/$id', body: data);
    } catch (e) {
      _notify('PUT', '/v1/ticketing/settings/departments/$id', body: data, isError: true);
      rethrow;
    }
  }

  /// DELETE /v1/ticketing/settings/departments/{id}
  Future<void> deleteDepartment(String id) async {
    try {
      await client.delete('/ticketing/settings/departments/$id');
      _notify('DELETE', '/v1/ticketing/settings/departments/$id');
    } catch (e) {
      _notify('DELETE', '/v1/ticketing/settings/departments/$id', isError: true);
      rethrow;
    }
  }

  // ── Ticket Settings / Business Hours ───────────────────────────────────────

  /// GET /v1/ticketing/settings/configuration
  Future<Map<String, dynamic>> fetchTicketSettings() async {
    try {
      final res = await client.get('/ticketing/settings/configuration');
      _notify('GET', '/v1/ticketing/settings/configuration');
      if (res is Map && res['data'] is Map) return (res['data'] as Map).cast<String, dynamic>();
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (e) {
      _notify('GET', '/v1/ticketing/settings/configuration', isError: true);
      rethrow;
    }
  }

  /// PUT /v1/ticketing/settings/configuration
  Future<void> updateTicketSettings(Map<String, dynamic> data) async {
    try {
      await client.put('/ticketing/settings/configuration', body: data);
      _notify('PUT', '/v1/ticketing/settings/configuration', body: data);
    } catch (e) {
      _notify('PUT', '/v1/ticketing/settings/configuration', body: data, isError: true);
      rethrow;
    }
  }

  // ── Ticketing Fields Configuration ─────────────────────────────────────────

  Future<void> addCustomField(Map<String, dynamic> data) async {
    try {
      await client.post('/ticketing/settings/fields', body: data);
      _notify('POST', '/v1/ticketing/settings/fields', body: data);
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/fields', body: data, isError: true);
      rethrow;
    }
  }

  Future<void> updateField(String fieldKey, Map<String, dynamic> data) async {
    final body = {'updates': data};
    try {
      await client.put('/ticketing/settings/fields/$fieldKey', body: body);
      _notify('PUT', '/v1/ticketing/settings/fields/$fieldKey', body: body);
    } catch (e) {
      _notify('PUT', '/v1/ticketing/settings/fields/$fieldKey', body: body, isError: true);
      rethrow;
    }
  }

  Future<void> deleteField(String fieldKey) async {
    try {
      await client.delete('/ticketing/settings/fields/$fieldKey');
      _notify('DELETE', '/v1/ticketing/settings/fields/$fieldKey');
    } catch (e) {
      _notify('DELETE', '/v1/ticketing/settings/fields/$fieldKey', isError: true);
      rethrow;
    }
  }

  Future<void> updateFieldOrder(List<dynamic> fields) async {
    final body = {'fields': fields};
    try {
      await client.patch('/ticketing/settings/fields/order', body: body);
      _notify('PATCH', '/v1/ticketing/settings/fields/order', body: body);
    } catch (e) {
      _notify('PATCH', '/v1/ticketing/settings/fields/order', body: body, isError: true);
      rethrow;
    }
  }

  Future<void> updateAndPublishFlow(List<dynamic> fields) async {
    final body = {'fields': fields};
    try {
      await client.post('/ticketing/settings/flow/publish', body: body);
      _notify('POST', '/v1/ticketing/settings/flow/publish', body: body);
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/flow/publish', body: body, isError: true);
      rethrow;
    }
  }

  // ── Customer Response Fields Configuration ─────────────────────────────────

  Future<Map<String, dynamic>> fetchCustomerResponseConfiguration() async {
    try {
      final res = await client.get('/ticketing/settings/customer-response/configuration');
      _notify('GET', '/v1/ticketing/settings/customer-response/configuration');
      if (res is Map && res['data'] is Map) return (res['data'] as Map).cast<String, dynamic>();
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (e) {
      _notify('GET', '/v1/ticketing/settings/customer-response/configuration', isError: true);
      rethrow;
    }
  }

  Future<void> saveCustomerResponseConfiguration(Map<String, dynamic> data) async {
    try {
      await client.put('/ticketing/settings/customer-response/configuration', body: data);
      _notify('PUT', '/v1/ticketing/settings/customer-response/configuration', body: data);
    } catch (e) {
      _notify('PUT', '/v1/ticketing/settings/customer-response/configuration', body: data, isError: true);
      rethrow;
    }
  }

  Future<void> addCustomerResponseField(Map<String, dynamic> data) async {
    try {
      await client.post('/ticketing/settings/customer-response/fields', body: data);
      _notify('POST', '/v1/ticketing/settings/customer-response/fields', body: data);
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/customer-response/fields', body: data, isError: true);
      rethrow;
    }
  }

  Future<void> updateCustomerResponseField(String fieldKey, Map<String, dynamic> data) async {
    final body = {'updates': data};
    try {
      await client.put('/ticketing/settings/customer-response/fields/$fieldKey', body: body);
      _notify('PUT', '/v1/ticketing/settings/customer-response/fields/$fieldKey', body: body);
    } catch (e) {
      _notify('PUT', '/v1/ticketing/settings/customer-response/fields/$fieldKey', body: body, isError: true);
      rethrow;
    }
  }

  Future<void> deleteCustomerResponseField(String fieldKey) async {
    try {
      await client.delete('/ticketing/settings/customer-response/fields/$fieldKey');
      _notify('DELETE', '/v1/ticketing/settings/customer-response/fields/$fieldKey');
    } catch (e) {
      _notify('DELETE', '/v1/ticketing/settings/customer-response/fields/$fieldKey', isError: true);
      rethrow;
    }
  }

  Future<void> updateCustomerResponseFieldOrder(List<dynamic> fields) async {
    final body = {'fields': fields};
    try {
      await client.patch('/ticketing/settings/customer-response/fields/order', body: body);
      _notify('PATCH', '/v1/ticketing/settings/customer-response/fields/order', body: body);
    } catch (e) {
      _notify('PATCH', '/v1/ticketing/settings/customer-response/fields/order', body: body, isError: true);
      rethrow;
    }
  }

  Future<void> updateAndPublishCustomerResponseFlow(List<dynamic> fields) async {
    final body = {'fields': fields};
    try {
      await client.post('/ticketing/settings/customer-response/flow/publish', body: body);
      _notify('POST', '/v1/ticketing/settings/customer-response/flow/publish', body: body);
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/customer-response/flow/publish', body: body, isError: true);
      rethrow;
    }
  }

  // -- Notification / Reminder Configuration --------------------------------

  /// GET /v1/ticketing/settings/reminders/{eventType}
  Future<Map<String, dynamic>> fetchReminderConfiguration(String eventType) async {
    try {
      final res = await client.get('/ticketing/settings/reminders/${Uri.encodeComponent(eventType)}');
      _notify('GET', '/v1/ticketing/settings/reminders/$eventType');
      if (res is Map && res['data'] is Map) return (res['data'] as Map).cast<String, dynamic>();
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (e) {
      _notify('GET', '/v1/ticketing/settings/reminders/$eventType', isError: true);
      rethrow;
    }
  }

  /// POST /v1/ticketing/settings/reminders
  Future<void> saveReminderConfiguration(Map<String, dynamic> data) async {
    try {
      await client.post('/ticketing/settings/reminders', body: data);
      _notify('POST', '/v1/ticketing/settings/reminders', body: data);
    } catch (e) {
      _notify('POST', '/v1/ticketing/settings/reminders', body: data, isError: true);
      rethrow;
    }
  }

  /// DELETE /v1/ticketing/settings/reminders/{eventType}/{alertType}
  Future<void> resetReminderConfiguration(String eventType, String alertType) async {
    try {
      await client.delete('/ticketing/settings/reminders/${Uri.encodeComponent(eventType)}/$alertType');
      _notify('DELETE', '/v1/ticketing/settings/reminders/$eventType/$alertType');
    } catch (e) {
      _notify('DELETE', '/v1/ticketing/settings/reminders/$eventType/$alertType', isError: true);
      rethrow;
    }
  }
}

