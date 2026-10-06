import 'api_client.dart';
import 'dto.dart';
import 'session.dart';

/// Appointments / bookings — against apiv2.askeva.io/v1/booking-configuration/*
/// (contract from the askeva-react client).
class AppointmentsRepository {
  final ApiClient client;
  final Session session;
  AppointmentsRepository(this.client, this.session);

  static List<Map<String, dynamic>> _list(dynamic res) {
    if (res is Map) {
      final d = res['data'] ?? res['appointments'] ?? res['rows'];
      if (d is List) return d.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (d is Map && d['appointments'] is List) return (d['appointments'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    if (res is List) return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    return const [];
  }

  /// GET /v1/booking-configuration/appointments?status=&startDate=&endDate=&agentId=&mobile=&limit=
  Future<List<AppointmentDto>> fetchAppointments({String? status, String? startDate, String? endDate, String? agentId, String? mobile, int? limit}) async {
    final res = await client.get('/booking-configuration/appointments', query: {
      'status': (status != null && status.isNotEmpty) ? status : 'all',
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
      if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      if (limit != null) 'limit': limit.toString(),
    });
    return _list(res).map(AppointmentDto.fromJson).toList();
  }

  /// GET /v1/booking-configuration/appointments/status-all?startDate=&endDate=&agentId=
  /// Returns pre-computed dashboard stats as the web app's Appointment Dashboard uses.
  /// Response shape: { data: { today, total, pending, completed, rescheduled, cancelled,
  ///                           earnedRevenue, totalRevenue, avgRevenue, successRate, ... } }
  Future<Map<String, dynamic>> fetchDashboardStats({String? startDate, String? endDate, String? agentId}) async {
    final paths = [
      '/booking-configuration/appointments/status-all',
      '/booking-configuration/appointments/stats',
      '/booking-configuration/dashboard',
      '/booking-configuration/appointments/dashboard',
    ];
    for (final path in paths) {
      try {
        final res = await client.get(path, query: {
          if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
          if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
          if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
        });
        if (res is Map) {
          final data = (res['data'] is Map) ? (res['data'] as Map).cast<String, dynamic>() : res.cast<String, dynamic>();
          // Validate that we got meaningful stats back (at least one numeric field)
          final hasStats = data.values.any((v) => v is num);
          if (hasStats) return data;
        }
      } catch (_) {}
    }
    return const {};
  }


  /// GET /v1/booking-configuration/appointments/{id}
  Future<Map<String, dynamic>> fetchAppointment(String id) async {
    final res = await client.get('/booking-configuration/appointments/$id');
    if (res is Map && res['data'] is Map) return (res['data'] as Map).cast<String, dynamic>();
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// POST /v1/booking-configuration/appointments
  Future<void> createAppointment(Map<String, dynamic> body) async {
    await client.post('/booking-configuration/appointments', body: body);
  }

  /// PATCH /v1/booking-configuration/appointments/{id} (status / reschedule / complete)
  Future<void> updateAppointment(String id, Map<String, dynamic> body) async {
    await client.patch('/booking-configuration/appointments/$id', body: body);
  }

  /// GET /v1/booking-configuration/
  Future<Map<String, dynamic>> fetchBookingConfiguration() async {
    final res = await client.get('/booking-configuration');
    return (res is Map && res['data'] is Map) ? (res['data'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  }

  /// POST /v1/booking-configuration/
  Future<void> saveBookingConfiguration(Map<String, dynamic> body) async {
    await client.post('/booking-configuration', body: body);
  }

  /// GET /v1/booking-configuration/notifications?type=user|business
  Future<Map<String, dynamic>> fetchNotificationConfigurations(String type) async {
    final res = await client.get('/booking-configuration/notifications', query: {'type': type});
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// PUT /v1/booking-configuration/notifications/{cardType}/status
  Future<void> updateNotificationConfigStatus(String cardType, bool enabled, String type) async {
    await client.put('/booking-configuration/notifications/${Uri.encodeComponent(cardType)}/status', body: {
      'enabled': enabled,
      'type': type,
    });
  }

  /// GET /v1/booking-configuration/webhook
  Future<Map<String, dynamic>> fetchWebhookConfiguration() async {
    final res = await client.get('/booking-configuration/webhook');
    return (res is Map && res['data'] is Map) ? (res['data'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  }

  /// PUT /v1/booking-configuration/webhook
  Future<void> updateWebhookConfiguration(Map<String, dynamic> body) async {
    await client.put('/booking-configuration/webhook', body: body);
  }

  /// POST /v1/booking-configuration/webhook/test
  Future<void> testWebhook() async {
    await client.post('/booking-configuration/webhook/test');
  }

  /// POST /v1/booking-configuration/appointments/publish/bookingForm
  Future<void> publishBookingForm(List<dynamic> fields) async {
    await client.post('/booking-configuration/appointments/publish/bookingForm', body: fields);
  }

  /// PUT /v1/booking-configuration/options/department
  Future<void> updateDepartmentOptions(List<String> options) async {
    await client.put('/booking-configuration/options/department', body: {'options': options});
  }

  /// POST /v1/booking-configuration/fields
  Future<void> addCustomField(Map<String, dynamic> body) async {
    await client.post('/booking-configuration/fields', body: body);
  }

  /// PUT /v1/booking-configuration/fields/{fieldKey}
  Future<void> updateField(String fieldKey, Map<String, dynamic> body) async {
    await client.put('/booking-configuration/fields/$fieldKey', body: body);
  }

  /// DELETE /v1/booking-configuration/fields/{fieldKey}
  Future<void> deleteField(String fieldKey) async {
    await client.delete('/booking-configuration/fields/$fieldKey');
  }

  /// GET /v1/whatsapp-flows/appointment-feedback/responses
  Future<List<Map<String, dynamic>>> fetchFeedbackResponses() async {
    final res = await client.get('/whatsapp-flows/appointment-feedback/responses');
    if (res is Map && res['data'] is List) {
      return (res['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    if (res is List) {
      return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  /// GET /v1/appointments/by-agent-date?agentId={agentId}&date={date}
  Future<List<Map<String, dynamic>>> fetchAppointmentsByAgentAndDate({required String agentId, required String date}) async {
    final res = await client.get('/appointments/by-agent-date', query: {
      'agentId': agentId,
      'date': date,
    });
    if (res is Map && res['data'] is List) {
      return (res['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    if (res is List) {
      return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  /// GET /v1/customers/suggestions?type={type}&value={value}
  Future<List<Map<String, dynamic>>> fetchCustomerSuggestions({required String type, required String value}) async {
    final paths = [
      '/customers/suggestions',
      '/booking-configuration/customers/suggestions',
      '/ticketing/customers/suggestions',
      '/leads/suggestions',
      '/customers/search',
    ];
    for (final path in paths) {
      try {
        final res = await client.get(path, query: {
          'type': type,
          'value': value,
        });
        List<Map<String, dynamic>> items = [];
        if (res is Map && res['data'] is List) {
          items = (res['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        } else if (res is List) {
          items = res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        }
        if (items.isNotEmpty) return items;
      } catch (_) {}
    }
    return const [];
  }

  /// PUT /v1/booking-configuration/appointments/{id}/reschedule
  Future<void> rescheduleAppointment(String id, Map<String, dynamic> body) async {
    await client.put('/booking-configuration/appointments/$id/reschedule', body: body);
  }

  /// PUT /v1/booking-configuration/appointments/{id}/complete
  Future<void> completeAppointment(String id, Map<String, dynamic> body) async {
    await client.put('/booking-configuration/appointments/$id/complete', body: body);
  }

  /// GET /v1/booking-configuration/appointments/{id}/audit-logs
  Future<List<Map<String, dynamic>>> fetchAuditLogs(String id) async {
    final res = await client.get('/booking-configuration/appointments/$id/audit-logs');
    if (res is Map && res['data'] is List) {
      return (res['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    if (res is List) {
      return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  /// POST /v1/booking-configuration/appointments/{id}/notes
  Future<void> addAppointmentNote(String id, Map<String, dynamic> body, {String? mongoId}) async {
    final targetIds = [
      if (mongoId != null && mongoId.isNotEmpty) mongoId,
      id,
    ];

    Object? lastError;
    for (final tid in targetIds) {
      final endpoints = [
        '/booking-configuration/appointments/$tid/notes',
        '/booking-configuration/appointments/$tid/note',
        '/appointments/$tid/notes',
        '/appointments/$tid/note',
      ];
      for (final endpoint in endpoints) {
        try {
          await client.post(endpoint, body: body);
          return;
        } catch (e) {
          lastError = e;
        }
      }
    }

    // Fallback: update appointment note via PATCH /booking-configuration/appointments/{id}
    for (final tid in targetIds) {
      try {
        await client.patch('/booking-configuration/appointments/$tid', body: {
          'note': body['content'] ?? body['text'] ?? body,
          'notes': [body],
        });
        return;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
  }

  /// GET /v1/appointments/stats-by-mobile?mobile={mobile}
  Future<Map<String, dynamic>> fetchStatsByMobile(String mobile) async {
    final cleanMob = mobile.replaceAll(RegExp(r'\D'), '');
    var with91 = cleanMob;
    if (with91.length == 10) with91 = '91$with91';
    final without91 = with91.startsWith('91') ? with91.substring(2) : with91;

    final queryVariants = [
      mobile.trim(),
      with91,
      without91,
    ].where((s) => s.isNotEmpty).toSet();

    final paths = [
      '/booking-configuration/appointments/stats-by-mobile',
      '/booking-configuration/stats-by-mobile',
      '/appointments/stats-by-mobile',
      '/bookings/stats-by-mobile',
      '/users/stats-by-mobile',
      '/leads/stats-by-mobile',
    ];

    for (final q in queryVariants) {
      for (final path in paths) {
        try {
          final res = await client.get(path, query: {'mobile': q});
          if (res is Map) {
            final data = res['data'] ?? res['stats'] ?? res['result'] ?? res['visitStats'] ?? res['summary'] ?? res;
            if (data is Map && data.isNotEmpty) {
              final mapData = data.cast<String, dynamic>();
              return mapData;
            }
          }
        } catch (_) {}
      }
    }
    return const {};
  }

  /// POST /v1/booking-configuration/alerts/template-config
  Future<void> saveAlertTemplateConfig(Map<String, dynamic> body) async {
    try {
      await client.post('/booking-configuration/alerts/template-config', body: body);
    } catch (_) {
      try {
        await client.post('/booking-configuration/template-config', body: body);
      } catch (_) {}
    }
  }
}
