import 'api_client.dart';
import 'dto.dart';
import 'session.dart';

/// Contacts groups + per-contact update/tags + number lookup, against
/// apiv2.askeva.io/v1/contacts/* (mirrors the web app's chat_service contacts calls).
/// Note: the backend has no "list all contacts" GET — the Contacts list is
/// derived from the leads API; these endpoints cover groups + per-contact ops.
class ContactsRepository {
  final ApiClient client;
  final Session session;
  ContactsRepository(this.client, this.session);

  /// GET /v1/contacts/groups -> { data:[ { _id, name, count } ] }
  Future<List<Map<String, dynamic>>> fetchGroups() async {
    final res = await client.get('/contacts/groups');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// POST /v1/contacts/groups  { name }
  Future<void> createGroup(String name) async {
    await client.post('/contacts/groups', body: {'name': name});
  }

  /// DELETE /v1/contacts/groups  { id }
  Future<void> deleteGroup(String id) async {
    await client.delete('/contacts/groups', body: {'id': id});
  }

  /// POST /v1/contacts/searchByNumber  { contactNumber }
  Future<Map<String, dynamic>?> searchByNumber(String number) async {
    final res = await client.post('/contacts/searchByNumber', body: {'contactNumber': number});
    if (res is Map) {
      final map = res.cast<String, dynamic>();
      if (map.containsKey('contact') || map.containsKey('session')) {
        return map;
      }
      if (map['data'] is Map) {
        return (map['data'] as Map).cast<String, dynamic>();
      }
      return map;
    }
    return null;
  }

  /// PATCH /v1/contacts/id/{id}  (full contact update)
  Future<void> updateContact(String id, Map<String, dynamic> body) async {
    await client.patch('/contacts/id/$id', body: {
      ...body,
      'id': id,
    });
  }

  /// PATCH /v1/contacts/id/{id}/tags  { tag }
  Future<void> updateTags(String id, List<String> tags) async {
    await client.patch('/contacts/id/$id/tags', body: {'tag': tags});
  }

  /// GET /v1/users/uicontacts
  Future<UiContactsPage> fetchUiContacts({
    int limit = 10,
    int offset = 0,
    String? search,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = {
      'limit': limit,
      'offset': offset,
      if (search != null && search.isNotEmpty) 'search': search,
      if (startDate != null) 'startDate': startDate.millisecondsSinceEpoch,
      if (endDate != null) 'endDate': endDate.millisecondsSinceEpoch,
    };
    final res = await client.get('/users/uicontacts', query: query);
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    final list = (map['data'] as List?) ?? const [];
    final contacts = list.whereType<Map>().map((m) => UiContactDto.fromJson(m.cast<String, dynamic>())).toList();
    final total = (map['total'] as num?)?.toInt() ?? contacts.length;
    return UiContactsPage(contacts, total);
  }

  /// GET /v1/users/unsubscribed
  Future<List<UnsubscribedContactDto>> fetchUnsubscribedContacts() async {
    final res = await client.get('/users/unsubscribed');
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    final list = (map['data'] as List?) ?? (res is List ? res : const []);
    return list.whereType<Map>().map((m) => UnsubscribedContactDto.fromJson(m.cast<String, dynamic>())).toList();
  }

  /// POST /v1/users/addTag
  Future<void> addUiTag(String contactNumber, String tag) async {
    await client.post('/users/addTag', body: {
      'contactnumber': contactNumber,
      'tag': tag,
    });
  }

  /// POST /v1/users/deleteTag
  Future<void> deleteUiTag(String contactNumber, String tag) async {
    await client.post('/users/deleteTag', body: {
      'contactnumber': contactNumber,
      'tag': tag,
    });
  }

  /// POST /v1/contacts/addToGroup  { contactIds, groupName }
  Future<void> addToGroup({required List<String> contactIds, required String groupName}) async {
    await client.post('/contacts/addToGroup', body: {
      'contactIds': contactIds,
      'groupName': groupName,
    });
  }

  /// GET /v1/contacts/search
  Future<ContactsPage> fetchContacts({
    int limit = 10,
    int offset = 0,
    String? search,
    String searchType = 'all',
  }) async {
    final query = {
      'limit': limit,
      'offset': offset,
      if (search != null && search.isNotEmpty) 'search': search,
      'searchType': searchType,
    };
    final res = await client.get('/contacts/search', query: query);
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    final list = (map['data'] as List?) ?? const [];
    final contacts = list.whereType<Map>().map((m) => ContactDto.fromJson(m.cast<String, dynamic>())).toList();
    final total = (map['total'] as num?)?.toInt() ?? contacts.length;
    return ContactsPage(contacts, total);
  }

  /// POST /v1/contacts/
  Future<void> createContact(Map<String, dynamic> body) async {
    await client.post('/contacts/', body: body);
  }

  /// DELETE /v1/contacts/id/{id}
  Future<void> deleteContact(String id) async {
    await client.delete('/contacts/id/$id');
  }

  /// POST /v1/contacts/moveContact
  Future<void> moveContactToGroup({
    required String contactId,
    required List<String> currentGroups,
    required String targetGroup,
  }) async {
    await client.post('/contacts/moveContact', body: {
      'contactId': contactId,
      'currentGroups': currentGroups,
      'targetGroup': targetGroup,
    });
  }

  /// POST /v1/contacts/copyContact
  Future<void> copyContact({
    required String contactId,
    required List<String> currentGroups,
    required String targetGroup,
  }) async {
    await client.post('/contacts/copyContact', body: {
      'contactId': contactId,
      'currentGroups': currentGroups,
      'targetGroup': targetGroup,
    });
  }

  /// POST /v1/contacts/exportOneContact
  Future<Map<String, dynamic>> exportOneContact(String id) async {
    final res = await client.post('/contacts/exportOneContact', body: {'id': id});
    if (res is Map && res['data'] is Map) {
      return (res['data'] as Map).cast<String, dynamic>();
    }
    if (res is Map) {
      return res.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  /// POST /v1/contacts/bulk or /v1/contacts/import -> import bulk contacts with required groups
  Future<Map<String, dynamic>> importContacts({
    required List<Map<String, dynamic>> contacts,
    required List<String> groups,
  }) async {
    final body = {
      'contacts': contacts,
      'groups': groups,
    };
    try {
      final res = await client.post('/contacts/bulk', body: body);
      return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    } catch (_) {
      try {
        final res = await client.post('/contacts/import', body: body);
        return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
      } catch (_) {
        int success = 0;
        for (final c in contacts) {
          try {
            await createContact(c);
            success++;
          } catch (_) {}
        }
        return {'imported': success, 'total': contacts.length};
      }
    }
  }
}

