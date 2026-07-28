import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ChatService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<Map<String, dynamic>> getLiveChatRooms({
    int offset = 0,
    int limit = 500,
    String filter = 'all',
    String search = 'null',
    String? agentId,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    // Build URL with optional agentId parameter
    String urlPath = '$baseUrl/v1/chat/session/$offset/$limit/$filter/$search';
    if (agentId != null && agentId.isNotEmpty) {
      urlPath += '?agent=$agentId';
    }

    final url = Uri.parse(urlPath);
    if (kDebugMode) {
      print('ChatService.getLiveChatRooms -> GET $url');
    }

    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to load live chat rooms');
  }

  static Future<Map<String, dynamic>> getHistoryChatRooms({
    int offset = 0,
    int limit = 20,
    String search = 'all',
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/history/$offset/$limit/$search');
    if (kDebugMode) {
      print('ChatService.getHistoryChatRooms -> GET $url');
    }

    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to load history chat rooms');
  }

  static Future<Map<String, dynamic>> getChatMessages(
    String contactNumber, {
    int offset = 0,
    int limit = 50,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/$contactNumber/$offset/$limit');
    if (kDebugMode) {
      print('ChatService.getChatMessages -> GET $url');
    }

    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to load messages for $contactNumber');
  }

  static Future<List<dynamic>> getCustomerJourney(String userNumber) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final url = Uri.parse(
        '$baseUrl/v1/chat/customer-journey?userNumber=$userNumber',
      );
      if (kDebugMode) print('ChatService.getCustomerJourney -> GET $url');

      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final resBody = jsonDecode(resp.body);
        return resBody['data'] ?? [];
      }
    } catch (e) {
      if (kDebugMode) print('ChatService.getCustomerJourney -> Exception: $e');
    }
    return [];
  }

  static Future<void> sendMessage({
    required String toNumber,
    required String type,
    required Map<String, dynamic> data,
    String? replyTo,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/sendchat');
    final bodyData = {
      'toNumber': toNumber,
      'type': type,
      'data': data,
      if (replyTo != null) 'replyTo': replyTo,
    };

    if (kDebugMode) {
      print('ChatService.sendMessage -> POST $url');
      print('ChatService.sendMessage -> body: ${jsonEncode(bodyData)}');
    }

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      if (resBody['error'] == true) {
        throw Exception(resBody['msg'] ?? 'Failed to send message');
      }
      return;
    }

    throw Exception('Failed to send message (Status: ${resp.statusCode})');
  }

  static Future<bool> getInterveneStatus(String userNumber) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/intervene/$userNumber');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      return resBody['data'] == true;
    }
    return false;
  }

  static Future<void> updateIntervene(
    String userNumber,
    bool interveneState,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/intervene');
    final bodyData = {
      'userNumber': userNumber,
      'interveneState': interveneState,
    };

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to update intervene status');
    }
  }

  static Future<void> intervene(String userNumber) =>
      updateIntervene(userNumber, true);
  static Future<void> disintervene(String userNumber) =>
      updateIntervene(userNumber, false);

  static Future<void> closeChat(String userNumber) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/userRemove');
    final bodyData = {'userNumber': userNumber};

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to close chat');
    }
  }

  static Future<String?> uploadFile(
    String filePath,
    String foldername, {
    bool isVoice = false,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/filehandler/upload/$foldername');
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['isVoiceRecording'] = isVoice.toString();

    final file = await http.MultipartFile.fromPath('file', filePath);
    request.files.add(file);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final resBody = jsonDecode(response.body);
      return resBody['fileUrl'];
    }
    return null;
  }

  static Future<void> blockUser(String userNumber, String action) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/blockuser');
    final bodyData = {'number': userNumber, 'action': action};

    final resp = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode != 200) {
      final resBody = jsonDecode(resp.body);
      throw Exception(resBody['message'] ?? 'Failed to block/unblock user');
    }
  }

  static Future<List<dynamic>> getAllAgents() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/agents');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      return resBody['data'] ?? [];
    }
    throw Exception('Failed to load agents');
  }

  static Future<Map<String, dynamic>> getActiveAgents() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    // Use the same endpoint as web: /agents/agents with activeOnly=true
    final url = Uri.parse('$baseUrl/v1/agents/agents?activeOnly=true');
    if (kDebugMode) {
      print('ChatService.getActiveAgents -> GET $url');
    }

    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (kDebugMode) {
      print('ChatService.getActiveAgents -> Status: ${resp.statusCode}');
      print('ChatService.getActiveAgents -> Body: ${resp.body}');
    }

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body) as Map<String, dynamic>;
      // Filter agents to only include agent, superagent, and admin roles
      final allAgents = resBody['data'] as List<dynamic>? ?? [];
      final filteredAgents = allAgents.where((agent) {
        final role = agent['role'] as String?;
        return role == 'agent' || role == 'superagent' || role == 'admin';
      }).toList();

      if (kDebugMode) {
        print(
          'ChatService.getActiveAgents -> Filtered ${filteredAgents.length} agents',
        );
      }

      return {'data': filteredAgents};
    }

    if (kDebugMode) {
      print('ChatService.getActiveAgents -> Error: ${resp.body}');
    }
    throw Exception('Failed to load active agents');
  }

  static Future<Map<String, dynamic>> getAssignedAgents(String number) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/assignedagents/$number');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      return resBody['data'] ?? {};
    }
    throw Exception('Failed to load assigned agents');
  }

  static Future<void> assignAgent(String number, List<String> agentIds) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/assignagent');
    final bodyData = {'userNumber': number, 'agentIds': agentIds};

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode != 200) {
      final errorBody = jsonDecode(resp.body);
      throw Exception(errorBody['msg'] ?? 'Failed to assign agent');
    }
  }

  static Future<void> addNote(
    String number,
    String note,
    String username,
    String email, {
    bool isEdited = false,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/addnotes');
    final noteObj = {
      'note': note,
      'username': username,
      'email': email,
      'createdAt': DateTime.now().toIso8601String(),
      if (isEdited) 'edited': true,
    };

    final bodyData = {'number': number, 'note': noteObj};

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to add note');
    }
  }

  static Future<void> deleteNote(String number, String note) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/notes');
    final bodyData = {'number': number, 'note': note};

    final resp = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to delete note');
    }
  }

  static Future<void> switchAgent({
    required String agentId,
    required String email,
    required String userNumber,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/switchAgent');
    final bodyData = {
      'agentId': agentId,
      'email': email,
      'userNumber': userNumber,
    };

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to switch agent');
    }
  }

  static Future<List<dynamic>> getCatalogs() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/commerce/catalogs');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      return resBody['data'] ?? [];
    }
    throw Exception('Failed to load catalogs');
  }

  static Future<List<dynamic>> getProductsByCatalogId(String catalogId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final url = Uri.parse('$baseUrl/v1/commerce/products/$catalogId');
      if (kDebugMode) print('ChatService.getProductsByCatalogId -> GET $url');

      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final resBody = jsonDecode(resp.body);
        return resBody['data'] ?? [];
      }
    } catch (e) {
      if (kDebugMode)
        print('ChatService.getProductsByCatalogId -> Exception: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getAllProducts() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final url = Uri.parse('$baseUrl/v1/commerce/getProducts');
      if (kDebugMode) print('ChatService.getAllProducts -> GET $url');

      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final resBody = jsonDecode(resp.body);
        return resBody['data'] ?? [];
      }
    } catch (e) {
      if (kDebugMode) print('ChatService.getAllProducts -> Exception: $e');
    }
    return [];
  }

  static Future<double> getShippingPrice() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/commerce/getCatalog');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      final price = resBody['updatedCatalog']?['shippingPrice'];
      return double.tryParse(price?.toString() ?? '0') ?? 0.0;
    }
    return 0.0;
  }

  static Future<Map<String, dynamic>> getContactByNumber(String number) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/contacts/searchByNumber');
    final bodyData = {'contactNumber': number};

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load contact info');
  }

  static Future<void> notifyPayment(Map<String, dynamic> data) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    // Use the correct endpoint matching React web
    final url = Uri.parse('$baseUrl/v1/whatsapp-pays/notifyPayment');

    if (kDebugMode) {
      print('ChatService.notifyPayment -> POST $url');
      print('ChatService.notifyPayment -> Body: ${jsonEncode(data)}');
    }

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (kDebugMode) {
      print('ChatService.notifyPayment -> Status: ${resp.statusCode}');
      print('ChatService.notifyPayment -> Response: ${resp.body}');
    }

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      if (resBody['error'] == true) {
        throw Exception(
          resBody['msg'] ??
              resBody['error'] ??
              'Failed to send payment notification',
        );
      }
      return;
    }

    // Try to extract error message from response
    try {
      final resBody = jsonDecode(resp.body);
      throw Exception(
        resBody['error'] ?? 'Failed to send payment notification',
      );
    } catch (e) {
      throw Exception(
        'Failed to send payment notification (Status: ${resp.statusCode})',
      );
    }
  }

  /// Updates contact tags via PATCH /v1/contacts/id/:id/tags (backend expects body.tag = array).
  static Future<void> updateContactTags(String contactId, List<String> tags) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/contacts/id/$contactId/tags');
    final bodyData = {'tag': tags};

    if (kDebugMode) {
      print('ChatService.updateContactTags -> PATCH $url');
      print('ChatService.updateContactTags -> Body: ${jsonEncode(bodyData)}');
    }

    final resp = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (kDebugMode) {
      print('ChatService.updateContactTags -> Status: ${resp.statusCode}');
      print('ChatService.updateContactTags -> Response: ${resp.body}');
    }

    if (resp.statusCode != 200) {
      final resBody = jsonDecode(resp.body);
      throw Exception(
          resBody['error'] ?? resBody['msg'] ?? 'Failed to update tags');
    }
  }

  /// PATCH contact or session with exact body (id + contact or id + session).
  static Future<void> updateContactWithBody(
    String id,
    Map<String, dynamic> body,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/contacts/id/$id');
    final bodyData = {...body, 'id': id};

    if (kDebugMode) {
      print('ChatService.updateContactWithBody -> PATCH $url');
      print('ChatService.updateContactWithBody -> Body: ${jsonEncode(bodyData)}');
    }

    final resp = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (kDebugMode) {
      print('ChatService.updateContactWithBody -> Status: ${resp.statusCode}');
      print('ChatService.updateContactWithBody -> Response: ${resp.body}');
    }

    if (resp.statusCode != 200) {
      final resBody = jsonDecode(resp.body);
      throw Exception(
          resBody['error'] ?? resBody['msg'] ?? 'Failed to update contact');
    }
  }

  static Future<void> updateContact(
    String id,
    Map<String, dynamic> contactData,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/contacts/id/$id');

    final bodyData = {'contact': contactData, 'id': id};

    if (kDebugMode) {
      print('ChatService.updateContact -> PATCH $url');
      print('ChatService.updateContact -> Body: ${jsonEncode(bodyData)}');
    }

    final resp = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (kDebugMode) {
      print('ChatService.updateContact -> Status: ${resp.statusCode}');
      print('ChatService.updateContact -> Response: ${resp.body}');
    }

    if (resp.statusCode != 200) {
      final resBody = jsonDecode(resp.body);
      throw Exception(resBody['msg'] ?? 'Failed to update contact');
    }
  }

  static Future<List<dynamic>> getQuickReplies() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/quick-reply');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      return resBody['data'] ?? [];
    }
    throw Exception('Failed to load quick replies');
  }

  static Future<void> sendQuickReply(Map<String, dynamic> data) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/quick-reply');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (resp.statusCode != 200) {
      final resBody = jsonDecode(resp.body);
      if (resBody['error'] == true) {
        throw Exception(resBody['msg'] ?? 'Failed to send quick reply');
      }
      throw Exception('Failed to send quick reply');
    }
  }

  static Future<List<dynamic>> getApprovedTemplates() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/templates/approved');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      return resBody as List<dynamic>;
    }
    throw Exception('Failed to load templates');
  }

  static Future<void> sendTemplate({
    required String templateId,
    required Map<String, dynamic> data,
    String method = 'intervene',
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/templates/send/$templateId/$method');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (resp.statusCode != 200) {
      final resBody = jsonDecode(resp.body);
      throw Exception(resBody['msg'] ?? 'Failed to send template');
    }
  }

  // ── Quick Reply CRUD ──────────────────────────────────────────

  static Future<void> createQuickReply(Map<String, dynamic> data) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/quick-reply');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      final resBody = jsonDecode(resp.body);
      throw Exception(resBody['msg'] ?? 'Failed to create quick reply');
    }
  }

  static Future<void> editQuickReply(
    String id,
    Map<String, dynamic> data,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/edit-quickreply/$id');
    final resp = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (resp.statusCode != 200) {
      final resBody = jsonDecode(resp.body);
      throw Exception(resBody['msg'] ?? 'Failed to update quick reply');
    }
  }

  static Future<void> deleteQuickReply(String id) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/chat/id/$id');
    final resp = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode != 200) {
      final resBody = jsonDecode(resp.body);
      throw Exception(resBody['msg'] ?? 'Failed to delete quick reply');
    }
  }

  static Future<List<String>> getContactGroups() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    // Use /v1/contacts/groups as per ContactApis.js in web
    final url = Uri.parse('$baseUrl/v1/contacts/groups');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      final resBody = jsonDecode(resp.body);
      final rawData = resBody['data'] ?? [];
      final List<dynamic> groups = rawData is List ? rawData : [];

      return groups
          .map((g) {
            if (g is String) return g;
            if (g is Map) return g['name']?.toString() ?? '';
            return g.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList()
          .cast<String>();
    }
    // Return empty list instead of throwing to avoid breaking UI on network error
    return [];
  }

  static Future<void> createLead(Map<String, dynamic> leadData) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    // Leads endpoint
    final url = Uri.parse('$baseUrl/v1/lead-configuration/leads');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(leadData),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      final resBody = jsonDecode(resp.body);
      throw Exception(
        resBody['message'] ?? resBody['msg'] ?? 'Failed to create lead',
      );
    }
  }

  static Future<void> createContactGroup(
    String groupName, [
    String? remarks,
  ]) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('No token found');

    final url = Uri.parse('$baseUrl/v1/contacts/groups');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'group': groupName, 'remarks': remarks ?? ''}),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      final resBody = jsonDecode(resp.body);
      throw Exception(
        resBody['message'] ?? resBody['msg'] ?? 'Failed to create group',
      );
    }
  }
} // End of ChatService
