import 'api_client.dart';
import 'session.dart';

/// Agents & roles (RBAC) against apiv2.askeva.io/v1/agents/* and /v1/users/*.
/// Mirrors the web app's agents_service / role-access contract.
class AgentsRepository {
  final ApiClient client;
  final Session session;
  AgentsRepository(this.client, this.session);

  /// GET /v1/agents/agents -> { data:[ { _id, username, email, role, mobilenumber, status } ] }
  Future<List<Map<String, dynamic>>> fetchAgents() async {
    final res = await client.get('/agents/agents');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// POST /v1/agents/agents
  Future<void> createAgent(Map<String, dynamic> body) async {
    await client.post('/agents/agents', body: body);
  }

  /// PATCH /v1/agents/agents  (body carries the id + updated fields)
  Future<void> updateAgent(Map<String, dynamic> body) async {
    await client.patch('/agents/agents', body: body);
  }

  /// DELETE /v1/agents/agents/{id}
  Future<void> deleteAgent(String id) async {
    await client.delete('/agents/agents/$id');
  }

  /// PATCH /v1/agents/agents/{id}/toggle -> enable/disable an agent
  Future<void> toggleAgent(String id) async {
    await client.patch('/agents/agents/$id/toggle');
  }

  /// POST /v1/agents/agent-password
  Future<void> changeAgentPassword(Map<String, dynamic> body) async {
    await client.post('/agents/agent-password', body: body);
  }

  /// GET /v1/users/agentroles -> { data:[ { _id, role_name, status, permissions } ] }
  Future<List<Map<String, dynamic>>> fetchRoles() async {
    final res = await client.get('/users/agentroles');
    final list = (res is Map && res['data'] is List) ? res['data'] as List : (res is List ? res : const []);
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// POST /v1/users/role-access
  Future<void> createRole(Map<String, dynamic> body) async {
    await client.post('/users/role-access', body: body);
  }

  /// PATCH /v1/users/role-access/{id}
  Future<void> updateRole(String id, Map<String, dynamic> body) async {
    await client.patch('/users/role-access/$id', body: body);
  }

  /// DELETE /v1/users/role-access/{id}
  Future<void> deleteRole(String id) async {
    await client.delete('/users/role-access/$id');
  }

  /// POST /v1/users/createQrCode -> { qr_image_url, deep_link_url }
  Future<Map<String, dynamic>> createQrCode(Map<String, dynamic> body) async {
    final res = await client.post('/users/createQrCode', body: body);
    return Map<String, dynamic>.from(res is Map ? res : const {});
  }

  /// GET /v1/users/qrCode -> { qr_codes: [ { _id, prefilledMessage, qrCodeUrl, deepLinkUrl, createdAt } ] }
  Future<List<Map<String, dynamic>>> fetchQrCodes() async {
    final res = await client.get('/users/qrCode');
    final list = (res is Map && res['qr_codes'] is List) ? res['qr_codes'] as List : const [];
    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// PATCH /v1/users/editQrCode/{id}
  Future<void> editQrCode(String id, Map<String, dynamic> body) async {
    await client.patch('/users/editQrCode/$id', body: body);
  }

  /// DELETE /v1/users/delete-qr/{id}
  Future<void> deleteQrCode(String id) async {
    await client.delete('/users/delete-qr/$id');
  }

  /// GET /v1/users/userattr -> List of attributes
  Future<List<Map<String, dynamic>>> fetchUserAttributes() async {
    final res = await client.get('/users/userattr');
    if (res is Map && res['data'] is Map && res['data']['userAttr'] is Map) {
      final userAttr = res['data']['userAttr'] as Map;
      return userAttr.entries.map((e) => {
        'key': e.key.toString(),
        'val': e.value.toString(),
      }).toList().reversed.toList();
    } else if (res is Map && res['userAttr'] is Map) {
      final userAttr = res['userAttr'] as Map;
      return userAttr.entries.map((e) => {
        'key': e.key.toString(),
        'val': e.value.toString(),
      }).toList().reversed.toList();
    } else if (res is List) {
      return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList().reversed.toList();
    }
    return const [];
  }

  /// POST /v1/users/userattr -> Create User Attribute
  Future<Map<String, dynamic>> createUserAttribute(Map<String, dynamic> body) async {
    final res = await client.post('/users/userattr', body: body);
    return Map<String, dynamic>.from(res is Map ? res : const {});
  }

  /// PATCH /v1/users/userattr -> Update User Attribute
  Future<Map<String, dynamic>> updateUserAttribute(Map<String, dynamic> body) async {
    final res = await client.patch('/users/userattr', body: body);
    return Map<String, dynamic>.from(res is Map ? res : const {});
  }

  /// DELETE /v1/users/userattr/{attrName} -> Delete User Attribute
  Future<void> deleteUserAttribute(String attrName) async {
    await client.delete('/users/userattr/$attrName');
  }
}
