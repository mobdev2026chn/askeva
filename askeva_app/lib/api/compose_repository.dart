import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'dto.dart';
import 'session.dart';

/// Compose Message / broadcast against the same endpoints my.askeva.io's
/// Compose page uses: /templates, /contacts/groups, /general/countries,
/// /users/userattr and /filehandler. Mirrors askeva-react Compose/index.jsx.
class ComposeRepository {
  final ApiClient client;
  final Session session;
  ComposeRepository(this.client, this.session);

  List<Map<String, dynamic>> _list(dynamic res) {
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  String? _fileUrl(dynamic res) {
    if (res == null) return null;
    if (res is String && res.startsWith('http')) return res;
    if (res is Map) {
      // Try direct keys first
      final direct = res['fileUrl'] ?? res['url'] ?? res['file_url'];
      if (direct != null) return direct.toString();
      // Try nested under data
      final data = res['data'];
      if (data is String && data.startsWith('http')) return data;
      if (data is Map) {
        final nested = data['fileUrl'] ?? data['url'] ?? data['file_url'];
        if (nested != null) return nested.toString();
      }
    }
    return null;
  }

  /// GET /v1/general/countries -> [ { dial_code, name } ]
  Future<List<CountryDto>> fetchCountries() async {
    final res = await client.get('/general/countries');
    return _list(res).map(CountryDto.fromJson).toList();
  }

  /// GET /v1/contacts/groups -> [ { name } ]  (returns the group names)
  Future<List<String>> fetchContactGroups() async {
    final res = await client.get('/contacts/groups');
    return _list(res).map((m) => (m['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
  }

  /// GET /v1/templates/approved -> [ template ]
  Future<List<TemplateDto>> fetchApprovedTemplates() async {
    final res = await client.get('/templates/approved');
    return _list(res).map(TemplateDto.fromJson).toList();
  }

  /// GET /v1/users/userattr -> { data: { userAttr: { key: val } } }.
  /// Returns the attribute names used to map template variables for group sends.
  Future<List<String>> fetchUserAttributes() async {
    final res = await client.get('/users/userattr');
    final data = (res is Map) ? res['data'] : null;
    final attr = (data is Map) ? data['userAttr'] : null;
    final keys = (attr is Map) ? attr.keys.map((e) => e.toString()).toList() : <String>[];
    if (!keys.contains('contactName')) keys.add('contactName');
    return keys;
  }

  /// POST /v1/templates/checkIfCampaignExists — guards against duplicate
  /// campaign names. Throws [ApiException] (non-2xx) when the name is taken.
  Future<void> checkCampaign({
    required String campaignId,
    required String templateId,
    String? filename,
    required String method,
    Map<String, dynamic> attributesMap = const {},
    List<String> groups = const [],
    bool trigger = false,
  }) async {
    await client.post('/templates/checkIfCampaignExists', body: {
      'campaignId': campaignId,
      'templateId': templateId,
      'filename': filename ?? '',
      'method': method,
      'attributesMap': attributesMap,
      'groups': groups.isNotEmpty ? groups : ['default-group'],
      'limit': 20,
      'trigger': trigger,
      'cards': const [],
    });
  }

  /// POST /v1/templates/send/{templateId}/broadcast — the actual send.
  Future<void> sendBroadcast(String templateId, Map<String, dynamic> body) async {
    await client.post('/templates/send/$templateId/broadcast', body: body);
  }

  /// Upload a CSV to /v1/filehandler/upload/temp -> fileUrl.
  Future<String?> uploadCsv(List<int> bytes, String filename) async {
    final res = await client.uploadFile(
      '/filehandler/upload/temp',
      field: 'file',
      bytes: bytes,
      filename: filename,
      contentType: 'text/csv',
    );
    final url = _fileUrl(res);
    if (kDebugMode) debugPrint('[ComposeRepo] uploadCsv response=$res  parsed url=$url');
    return url;
  }

  /// Upload header media (image/video/document) to /v1/filehandler/upload/chat -> fileUrl.
  Future<String?> uploadMedia(List<int> bytes, String filename) async {
    final res = await client.uploadFile('/filehandler/upload/chat', field: 'file', bytes: bytes, filename: filename);
    return _fileUrl(res);
  }

  /// POST /v1/filehandler/csvheaders { url } -> column headers.
  Future<List<String>> fetchCsvHeaders(String url) async {
    final res = await client.post('/filehandler/csvheaders', body: {'url': url});
    List<dynamic>? list;
    if (res is List) {
      list = res;
    } else if (res is Map) {
      final d = res['data'] ?? res['headers'] ?? res['columns'] ?? res['result'];
      if (d is List) {
        list = d;
      } else if (d is Map) {
        final nested = d['headers'] ?? d['columns'] ?? d['data'] ?? d['keys'];
        if (nested is List) list = nested;
      } else {
        final direct = res['headers'] ?? res['columns'] ?? res['keys'];
        if (direct is List) list = direct;
      }
    }
    if (list != null) {
      return list.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }
}
