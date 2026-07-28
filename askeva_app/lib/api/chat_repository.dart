import 'dart:developer' as dev;

import 'api_client.dart';
import 'dto.dart';
import 'session.dart';

/// WhatsApp chat read/send against apiv2.askeva.io/v1/chat/*.
class ChatRepository {
  final ApiClient client;
  final Session session;
  ChatRepository(this.client, this.session);

  /// GET /v1/chat/session/{offset}/{limit}/{filter}/{search} -> { rooms:[], total }
  Future<List<ChatRoomDto>> fetchRooms({
    int offset = 0,
    int limit = 1000,
    String filter = 'live',
    String? search,
    String? agent,
    String? tag,
  }) async {
    final hasSearch = search != null && search.trim().isNotEmpty && search.trim().toLowerCase() != 'null';
    final s = hasSearch ? Uri.encodeComponent(search.trim()) : 'null';
    final query = <String, String>{};
    if (agent != null && agent.isNotEmpty) {
      query['agent'] = agent;
    }
    if (tag != null && tag.isNotEmpty) {
      query['tag'] = tag;
    }

    List<ChatRoomDto> parseRooms(List<dynamic> rawList) {
      final List<ChatRoomDto> result = [];
      for (final item in rawList) {
        if (item is Map) {
          try {
            result.add(ChatRoomDto.fromJson(item.cast<String, dynamic>()));
          } catch (e) {
            dev.log('[Rooms] Error parsing room item: $e');
          }
        }
      }
      return result;
    }

    final endpoints = <String>[
      '/chat/session/$offset/$limit/$filter/$s',
      '/chat/session/$offset/$limit/live/$s',
    ];

    for (final ep in endpoints) {
      try {
        final res = await client.get(ep, query: query);
        final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
        final dataMap = (map['data'] is Map) ? (map['data'] as Map).cast<String, dynamic>() : null;
        final rooms = (map['rooms'] as List?) ??
            (map['data'] as List?) ??
            (map['result'] as List?) ??
            (map['sessions'] as List?) ??
            (map['chats'] as List?) ??
            (map['liveChats'] as List?) ??
            (map['activeSessions'] as List?) ??
            (map['live'] as List?) ??
            (dataMap?['rooms'] as List?) ??
            (dataMap?['chats'] as List?) ??
            (dataMap?['sessions'] as List?) ??
            (res is List ? res : const []);
        dev.log('[Rooms] $ep -> ${rooms.length} rooms');
        if (rooms.isNotEmpty) {
          return parseRooms(rooms);
        }
      } catch (e) {
        dev.log('[Rooms] $ep error: $e');
      }
    }

    return const [];
  }

  /// GET /v1/chat/history/{offset}/{limit}/{filter}/{search}
  /// GET /v1/chat/session/{offset}/{limit}/history/{search}
  Future<List<ChatRoomDto>> fetchHistoryRooms({
    int offset = 0,
    int limit = 1000,
    String? filter,
    String? search,
    String? agent,
  }) async {
    final hasSearch = search != null && search.trim().isNotEmpty && search.trim().toLowerCase() != 'null';
    final s = hasSearch ? Uri.encodeComponent(search.trim()) : 'null';
    final filterPath = (filter != null && filter.isNotEmpty) ? filter : 'history';
    final query = <String, String>{};
    if (agent != null && agent.isNotEmpty) {
      query['agent'] = agent;
    }
    if (filter != null && filter.isNotEmpty && filter != 'all') {
      query['filter'] = filter;
    }

    dev.log('[History] Fetching history rooms: offset=$offset limit=$limit filter=$filter search=$s agent=$agent');

    List<ChatRoomDto> parseRooms(List<dynamic> rawList) {
      final List<ChatRoomDto> result = [];
      for (final item in rawList) {
        if (item is Map) {
          try {
            result.add(ChatRoomDto.fromJson(item.cast<String, dynamic>()));
          } catch (e) {
            dev.log('[History] Error parsing room item: $e');
          }
        }
      }
      return result;
    }

    final endpoints = <String>[
      '/chat/history/$offset/$limit/$filterPath/$s',
      '/chat/history/$offset/$limit/history/$s',
    ];

    for (final ep in endpoints) {
      try {
        final res = await client.get(ep, query: query);
        final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
        final dataMap = (map['data'] is Map) ? (map['data'] as Map).cast<String, dynamic>() : null;
        final rooms = (map['rooms'] as List?) ??
            (map['data'] as List?) ??
            (map['result'] as List?) ??
            (map['history'] as List?) ??
            (map['sessions'] as List?) ??
            (map['chatHistory'] as List?) ??
            (dataMap?['rooms'] as List?) ??
            (dataMap?['history'] as List?) ??
            (dataMap?['sessions'] as List?) ??
            (res is List ? res : const []);
        dev.log('[History] $ep -> ${rooms.length} rooms');
        if (rooms.isNotEmpty) {
          return parseRooms(rooms);
        }
      } catch (e) {
        dev.log('[History] $ep error: $e');
      }
    }

    return const [];
  }

  /// GET /v1/chat/{contactNumber}/{offset}/{limit} -> { messages:[], total }
  Future<List<MessageDto>> fetchMessages(String contactNumber, {int offset = 0, int limit = 100}) async {
    final cleanNum = formatCleanMobileNumber(contactNumber);
    final rawClean = contactNumber.replaceAll(RegExp(r'\D'), '');
    final endpoints = [
      if (rawClean.isNotEmpty) '/chat/$rawClean/$offset/$limit',
      if (cleanNum.isNotEmpty && cleanNum != rawClean) '/chat/$cleanNum/$offset/$limit',
      '/chat/$contactNumber/$offset/$limit',
      '/chat/messages/$rawClean/$offset/$limit',
    ];

    for (final ep in endpoints) {
      try {
        final res = await client.get(ep);
        final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
        final msgs = (map['data'] as List?) ??
            (map['messages'] as List?) ??
            (map['result'] as List?) ??
            (map['history'] as List?) ??
            (res is List ? res : const []);
        if (msgs.isNotEmpty) {
          return msgs
              .whereType<Map>()
              .map((m) => MessageDto.fromJson(
                    m.cast<String, dynamic>(),
                    selfNumber: session.roomId,
                    customerNumber: contactNumber,
                  ))
              .toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  /// POST /v1/chat/sendchat  { toNumber, type, data:{ text } }
  Future<void> sendText(String toNumber, String text) async {
    await client.post('/chat/sendchat', body: {
      'toNumber': toNumber,
      'type': 'text',
      'data': {'body': text},
    });
  }

  /// GET /v1/chat/customer-journey -> { data:[ events ] }
  /// The web app fetches ALL events (no query params) then filters client-side
  /// by userNumber. We do the same to match the backend contract exactly.
  Future<List<Map<String, dynamic>>> fetchCustomerJourney(String userNumber) async {
    final res = await client.get('/chat/customer-journey');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    final all = list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    // Filter by userNumber client-side (matches web ChatSideStatus.jsx behaviour)
    if (userNumber.isNotEmpty) {
      return all.where((e) => e['userNumber']?.toString() == userNumber).toList();
    }
    return all;
  }

  /// GET /v1/chat/intervene/{userNumber} -> { data: bool }
  Future<bool> fetchInterveneStatus(String userNumber) async {
    final res = await client.get('/chat/intervene/$userNumber');
    if (res is Map) return res['data'] == true;
    return res == true;
  }

  /// POST /v1/chat/intervene  { userNumber, interveneState }
  Future<void> setIntervene(String userNumber, bool intervene) async {
    await client.post('/chat/intervene', body: {
      'userNumber': userNumber,
      'interveneState': intervene,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'mode': 'intervene',
    });
  }

  /// POST /v1/chat/userRemove  { userNumber } — hand the conversation back to AI.
  Future<void> closeConversation(String userNumber) async {
    await client.post('/chat/userRemove', body: {'userNumber': userNumber});
  }

  /// PATCH /v1/chat/blockuser  { number, action }  (action: 'block' | 'unblock')
  Future<void> blockUser(String number, {bool block = true}) async {
    await client.patch('/chat/blockuser', body: {'number': number, 'action': block ? 'block' : 'unblock'});
  }

  /// POST /v1/chat/bulk-block  { contacts: [{ countryCode, mobile }] }
  Future<void> bulkBlock(List<Map<String, String>> contacts) async {
    await client.post('/chat/bulk-block', body: {'contacts': contacts});
  }

  /// POST /v1/chat/addnotes  { number, note: { note, username, email } }
  Future<void> addNote(String number, String note) async {
    final name = session.username ?? (session.profile is Map ? (session.profile!['name'] ?? session.profile!['username']) : null);
    final userNameStr = (name != null && name.toString().isNotEmpty) ? name.toString() : null;
    await client.post('/chat/addnotes', body: {
      'number': number,
      'note': {
        'note': note,
        if (userNameStr != null) 'username': userNameStr,
        if (userNameStr != null) 'by': userNameStr,
        if (userNameStr != null) 'agentName': userNameStr,
        if (session.email != null) 'email': session.email,
      }
    });
  }

  /// DELETE /v1/chat/notes  { number, note }
  Future<void> deleteNote(String number, String note) async {
    await client.delete('/chat/notes', body: {'number': number, 'note': note});
  }

  /// GET /v1/chat/assignedagents/{number}
  ///
  /// Web app:  allAsignedAgents.data.assignedAgents → IDs or full objects
  ///           allAsignedAgents.data.notes           → Notes array
  ///
  /// Handles both response shapes:
  ///   { data: { assignedAgents: ["id1","id2"], notes: [...] } }   ← IDs
  ///   { data: { assignedAgents: [{_id,username,…}], notes: [...] } }  ← objects
  ///
  /// If IDs are returned, pass [allAgents] to resolve them.
  Future<({List<Map<String, dynamic>> agents, List<Map<String, dynamic>> notes})>
      fetchAssignedAgentsWithNotes(String number, {List<Map<String, dynamic>>? allAgents}) async {
    final res = await client.get('/chat/assignedagents/$number');

    List<Map<String, dynamic>> agents = [];
    List<Map<String, dynamic>> notes = [];

    // Build agent lookup map from the pre-fetched all-agents list
    final agentMap = allAgents != null
        ? {for (final a in allAgents) (a['_id'] ?? a['id'] ?? '').toString(): a}
        : <String, Map<String, dynamic>>{};

    /// Parse a raw list that is either [{_id,username,…}] or ["id1","id2"]
    void parseAssignedList(dynamic rawList) {
      if (rawList is! List || rawList.isEmpty) return;

      final directObjects = <Map<String, dynamic>>[];
      final idStrings = <String>[];

      for (final item in rawList) {
        if (item is Map) {
          // Full agent object — use directly (preferred path)
          directObjects.add(item.cast<String, dynamic>());
        } else if (item is String && item.isNotEmpty) {
          idStrings.add(item);
        }
      }

      if (directObjects.isNotEmpty) {
        // API returned full objects → use them directly (no ID resolution needed)
        agents = directObjects;
      } else if (idStrings.isNotEmpty) {
        // API returned IDs → resolve against allAgents
        if (agentMap.isNotEmpty) {
          for (final id in idStrings) {
            if (agentMap.containsKey(id)) {
              agents.add(agentMap[id]!);
            }
          }
        }
        // Fallback: if no match found still show placeholders so UI isn't blank
        if (agents.isEmpty) {
          agents = idStrings
              .map((id) => <String, dynamic>{
                    '_id': id,
                    'username': 'Agent',
                    'email': '',
                  })
              .toList();
        }
      }
    }

    if (res is Map) {
      final data = res['data'];
      if (data is Map) {
        // Shape: { data: { assignedAgents: [...], notes: [...] } }
        final rawAssigned = data['assignedAgents'] ?? data['assignedAgent'] ??
            data['agents'] ?? data['agent'];
        parseAssignedList(rawAssigned);
        final rawNotes = data['notes'];
        if (rawNotes is List) {
          notes = rawNotes
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList();
        }
      } else if (data is List) {
        // Shape: { data: [...] } — data is the assigned list directly
        parseAssignedList(data);
        if (res['notes'] is List) {
          notes = (res['notes'] as List)
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList();
        }
      } else {
        // data is null or scalar — try top-level keys as fallback
        final rawAssigned = res['assignedAgents'] ?? res['assignedAgent'] ??
            res['agents'] ?? res['agent'];
        parseAssignedList(rawAssigned);
        if (res['notes'] is List) {
          notes = (res['notes'] as List)
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList();
        }
      }
    } else if (res is List) {
      // Entire response is the agents list
      parseAssignedList(res);
    }

    return (agents: agents, notes: notes);
  }

  /// GET /v1/chat/assignedagents/{number} → agents list only (backward compat)
  Future<List<Map<String, dynamic>>> fetchAssignedAgents(String number) async {
    final result = await fetchAssignedAgentsWithNotes(number);
    return result.agents;
  }

  /// Notes are returned by the assignedagents endpoint (web: allAsignedAgents?.data.notes).
  Future<List<Map<String, dynamic>>> fetchNotes(String number) async {
    final result = await fetchAssignedAgentsWithNotes(number);
    return result.notes;
  }


  /// POST /v1/chat/assignagent  { userNumber, agentIds }
  Future<void> assignAgents(String userNumber, List<String> agentIds) async {
    await client.post('/chat/assignagent', body: {'userNumber': userNumber, 'agentIds': agentIds});
  }

  /// POST /v1/chat/switchAgent  { userNumber, agentId }
  Future<void> switchAgent(String userNumber, String agentId) async {
    await client.post('/chat/switchAgent', body: {'userNumber': userNumber, 'agentId': agentId});
  }

  /// GET /v1/chat/quick-reply -> [ { title, message } ]
  Future<List<Map<String, dynamic>>> fetchQuickReplies() async {
    final res = await client.get('/chat/quick-reply');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// GET /v1/payments/get-wallet-transactions  (matches web PaymentsApis.js)
  Future<List<PaymentTransactionDto>> fetchTransactions() async {
    final res = await client.get('/payments/get-wallet-transactions');
    if (res is List) {
      return res.whereType<Map>().map((m) => PaymentTransactionDto.fromJson(m.cast<String, dynamic>())).toList();
    }
    if (res is Map && res['data'] is List) {
      return (res['data'] as List).whereType<Map>().map((m) => PaymentTransactionDto.fromJson(m.cast<String, dynamic>())).toList();
    }
    return const [];
  }

  /// GET /v1/templates/approved -> approved WhatsApp templates.
  Future<List<Map<String, dynamic>>> fetchApprovedTemplates() async {
    final res = await client.get('/templates/approved');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// POST /v1/templates/send/{templateId}/{method}  { toNumber, ... }
  Future<void> sendTemplate(String templateId, Map<String, dynamic> data, {String method = 'intervene'}) async {
    final rawNumber = (data['contactNumber'] ?? data['mobile'] ?? data['toNumber'] ?? '').toString();
    final cleanDigits = rawNumber.replaceAll(RegExp(r'\D'), '');

    String countryCode = (data['countryCode'] ?? '91').toString();
    String mobile = cleanDigits;

    if (cleanDigits.startsWith('91') && cleanDigits.length == 12) {
      countryCode = '91';
      mobile = cleanDigits.substring(2);
    } else if (cleanDigits.startsWith('1') && cleanDigits.length == 11) {
      countryCode = '1';
      mobile = cleanDigits.substring(1);
    } else if (cleanDigits.length == 10) {
      countryCode = '91';
      mobile = cleanDigits;
    }

    final fullMobile = cleanDigits.length == 10 ? '$countryCode$mobile' : cleanDigits;

    final body = Map<String, dynamic>.from(data);
    body['templateId'] = templateId;
    body['countryCode'] = countryCode;
    body['contactNumber'] = mobile;
    body['mobile'] = mobile;
    body['toNumber'] = fullMobile;
    body['fullMobile'] = fullMobile;
    body['userNumber'] = fullMobile;

    final endpoints = [
      '/lead-configuration/send-template',
      '/templates/send/$templateId/$method',
      '/templates/send/$templateId/single',
      '/templates/send/$templateId/intervene',
      '/templates/send/$templateId/broadcast',
    ];

    Object? lastErr;
    for (final ep in endpoints) {
      try {
        await client.post(ep, body: body);
        return;
      } catch (e) {
        lastErr = e;
      }
    }
    if (lastErr != null) throw lastErr;
  }

  /// GET /v1/exotel/call-logs?page=&limit= -> { data:[] }
  Future<List<Map<String, dynamic>>> fetchCallLogs({int page = 1, int limit = 20}) async {
    final res = await client.get('/exotel/call-logs', query: {'page': page, 'limit': limit});
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// POST /v1/chat/send-catalog
  Future<void> sendCatalog({required String catalogId, required List<String> productItems, required String userNumber}) async {
    await client.post('/chat/send-catalog', body: {
      'catalogId': catalogId,
      'productItems': productItems,
      'userNumber': userNumber,
    });
  }

  /// POST /v1/chat/sendchat  { toNumber, type, data: { link, filename, caption } }
  Future<void> sendAttachment(String toNumber, String type, String link, {String? filename, String? caption}) async {
    await client.post('/chat/sendchat', body: {
      'toNumber': toNumber,
      'type': type,
      'data': {
        'link': link,
        if (filename != null) 'filename': filename,
        if (caption != null) 'caption': caption,
      },
    });
  }

  /// POST /v1/filehandler/upload/chat
  Future<String> uploadChatFile(List<int> bytes, String filename, String contentType) async {
    final res = await client.uploadFile(
      '/filehandler/upload/chat',
      field: 'file',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    return (res['fileUrl'] ?? res['data']?['fileUrl'] ?? '').toString();
  }
}
