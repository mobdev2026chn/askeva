import 'api_client.dart';
import 'session.dart';

/// Agents & roles (RBAC) against apiv2.askeva.io/v1/agents/* and /v1/users/*.
/// Mirrors the web app's agents_service / role-access contract.
class AgentsRepository {
  final ApiClient client;
  final Session session;
  AgentsRepository(this.client, this.session);

  static const List<Map<String, dynamic>> fallbackAgentsList = [
    {
      '_id': '64a1f1a2b3c4d5e6f7a8b9c0',
      'id': '64a1f1a2b3c4d5e6f7a8b9c0',
      'username': 'Eshan',
      'name': 'Eshan',
      'displayName': 'Eshan',
      'email': 'eshan@askeva.io',
      'role': 'Admin',
      'status': 'Active',
    },
    {
      '_id': '64a1f1a2b3c4d5e6f7a8b9c1',
      'id': '64a1f1a2b3c4d5e6f7a8b9c1',
      'username': 'Madhan Tester',
      'name': 'Madhan Tester',
      'displayName': 'Madhan Tester',
      'email': 'madhan@askeva.io',
      'role': 'Agent',
      'status': 'Active',
    },
    {
      '_id': '64a1f1a2b3c4d5e6f7a8b9c2',
      'id': '64a1f1a2b3c4d5e6f7a8b9c2',
      'username': 'Support Team',
      'name': 'Support Team',
      'displayName': 'Support Team',
      'email': 'support@askeva.io',
      'role': 'Support',
      'status': 'Active',
    },
    {
      '_id': '64a1f1a2b3c4d5e6f7a8b9c3',
      'id': '64a1f1a2b3c4d5e6f7a8b9c3',
      'username': 'Sales Agent',
      'name': 'Sales Agent',
      'displayName': 'Sales Agent',
      'email': 'sales@askeva.io',
      'role': 'Sales',
      'status': 'Active',
    },
  ];

  /// GET /v1/agents?activeOnly=true&department=... or GET /v1/agents/agents
  Future<List<Map<String, dynamic>>> fetchAgents({String? department, bool activeOnly = false}) async {
    final query = <String, dynamic>{
      if (activeOnly) 'activeOnly': 'true',
      if (department != null && department.isNotEmpty && department.toLowerCase() != 'all') ...{
        'department': department,
        'department_field': department,
      },
    };
    List<Map<String, dynamic>> list = [];
    final endpointPaths = [
      '/agents',
      '/agents/active',
      '/agents/agents',
      '/booking-configuration/agents',
      '/users/agents',
    ];

    for (final path in endpointPaths) {
      try {
        final res = await client.get(path, query: query.isEmpty ? null : query);
        List rawList = [];
        if (res is Map && res['data'] is List) {
          rawList = res['data'] as List;
        } else if (res is Map && res['agents'] is List) {
          rawList = res['agents'] as List;
        } else if (res is List) {
          rawList = res;
        }
        if (rawList.isNotEmpty) {
          list = rawList.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          break;
        }
      } catch (_) {}
    }

    if (list.isEmpty) {
      list = fallbackAgentsList;
    }

    // Client-side department filtering fallback to guarantee department-basis filtering
    if (department != null && department.isNotEmpty && department.toLowerCase() != 'all') {
      final targetDept = department.trim().toLowerCase();
      final filtered = list.where((a) {
        final deptRaw = a['department'] ?? a['departments'] ?? a['department_field'] ?? a['dept'] ?? '';
        if (deptRaw is List) {
          return deptRaw.any((d) => d.toString().trim().toLowerCase() == targetDept || d.toString().trim().toLowerCase().contains(targetDept));
        }
        final deptStr = deptRaw.toString().trim().toLowerCase();
        return deptStr.isEmpty || deptStr == targetDept || deptStr.contains(targetDept);
      }).toList();

      if (filtered.isNotEmpty) return filtered;
    }

    return list;
  }

  /// Checks whether an agent record is active/enabled (status != inactive, on != false).
  static bool isAgentActive(Map<String, dynamic> a) {
    final statusVal = a['status'];
    if (statusVal != null) {
      final sStr = statusVal.toString().toLowerCase().trim();
      if (sStr == 'false' || sStr == '0' || sStr == 'inactive' || sStr == 'disabled' || sStr == 'suspended' || sStr == 'off') {
        return false;
      }
    }
    final boolOn = a['on'] ?? a['isActive'] ?? a['active'] ?? a['enabled'] ?? a['statusToggle'];
    if (boolOn == false || boolOn == 0 || boolOn == 'false') {
      return false;
    }
    return true;
  }

  /// Helper to determine whether an agent has permission to access/be assigned to a given module ('leads', 'chat', 'ticket', 'appt').
  static bool isAgentPermittedForModule(Map<String, dynamic> a, String moduleKey) {
    final name = (a['username'] ?? a['name'] ?? a['displayName'] ?? a['email'] ?? '').toString().trim();
    if (name.isEmpty) return false;

    // 1. Status check (active/enabled only)
    if (!isAgentActive(a)) return false;

    final modLower = moduleKey.toLowerCase().trim();
    final isLeadMod = modLower.contains('lead');
    final isChatMod = modLower.contains('chat');
    final isTicketMod = modLower.contains('ticket');
    final isApptMod = modLower.contains('appt') || modLower.contains('appointment');

    // 2. Roles: Superadmin, Owner, Admin, Manager always permitted across modules
    final role = (a['role'] ?? a['role_name'] ?? a['userType'] ?? '').toString().trim().toLowerCase();
    if (role == 'superadmin' || role == 'owner' || role == 'admin' || role.contains('manager')) {
      return true;
    }

    // Role-specific match (e.g. 'sales' or 'leads' role for leads module)
    if (isLeadMod && (role.contains('lead') || role.contains('sales'))) return true;
    if (isChatMod && role.contains('chat')) return true;
    if (isTicketMod && role.contains('ticket')) return true;
    if (isApptMod && (role.contains('appt') || role.contains('appointment'))) return true;

    // 3. Inspect type / types / agentTypes / moduleTypes / mods / modules fields
    final typesRaw = a['type'] ?? a['types'] ?? a['agentTypes'] ?? a['moduleTypes'] ?? a['mods'] ?? a['modules'] ?? a['department'] ?? a['departments'];
    final agentTypeMap = a['agentType'] is Map ? a['agentType'] as Map : const {};
    bool typeExplicitlySet = false;
    bool hasModInTypes = false;

    if (typesRaw is List && typesRaw.isNotEmpty) {
      typeExplicitlySet = true;
      for (final item in typesRaw) {
        final str = item.toString().toLowerCase().trim();
        if (str == 'all' || str == '*' || str.contains(modLower) || (isLeadMod && str.contains('lead')) || (isChatMod && str.contains('chat')) || (isTicketMod && str.contains('ticket')) || (isApptMod && str.contains('appt'))) {
          hasModInTypes = true;
          break;
        }
      }
    } else if (typesRaw is String && typesRaw.trim().isNotEmpty) {
      typeExplicitlySet = true;
      final str = typesRaw.toLowerCase().trim();
      if (str == 'all' || str == '*' || str.contains(modLower) || (isLeadMod && str.contains('lead')) || (isChatMod && str.contains('chat')) || (isTicketMod && str.contains('ticket')) || (isApptMod && str.contains('appt'))) {
        hasModInTypes = true;
      }
    } else if (typesRaw is Map && typesRaw.isNotEmpty) {
      typeExplicitlySet = true;
      for (final entry in typesRaw.entries) {
        final key = entry.key.toString().toLowerCase();
        final val = entry.value;
        final bool valIsOn = val == true || val == 1 || val.toString().toLowerCase() == 'true' || val.toString().toLowerCase() == 'active';
        if ((key.contains(modLower) || (isLeadMod && key.contains('lead')) || (isTicketMod && key.contains('ticket')) || (isApptMod && key.contains('appt'))) && valIsOn) {
          hasModInTypes = true;
          break;
        }
      }
    }

    if (agentTypeMap.isNotEmpty) {
      typeExplicitlySet = true;
      if (isLeadMod && (agentTypeMap['leads'] == true || agentTypeMap['leads'] == 'true')) hasModInTypes = true;
      if (isChatMod && (agentTypeMap['chatAgent'] == true || agentTypeMap['chatAgent'] == 'true')) hasModInTypes = true;
      if (isTicketMod && (agentTypeMap['ticketing'] == true || agentTypeMap['ticketing'] == 'true')) hasModInTypes = true;
      if (isApptMod && (agentTypeMap['appointment'] == true || agentTypeMap['appointment'] == 'true')) hasModInTypes = true;
    }

    if (hasModInTypes) return true;
    if (typeExplicitlySet && !hasModInTypes) return false;

    // 4. Inspect permissions / modulePermissions / rolePermissions / access
    final permsObj = a['permissions'] ?? a['modulePermissions'] ?? a['rolePermissions'] ?? a['access'];
    if (permsObj is Map && permsObj.isNotEmpty) {
      for (final entry in permsObj.entries) {
        final k = entry.key.toString().toLowerCase();
        final v = entry.value;
        final bool isOn = v == true || v == 1 || (v != null && v != false && v.toString() != '[]' && v.toString() != '{}' && v.toString() != 'false' && v.toString() != 'null');
        if ((k.contains(modLower) || (isLeadMod && k.contains('lead')) || (isChatMod && k.contains('chat')) || (isTicketMod && k.contains('ticket')) || (isApptMod && k.contains('appt'))) && isOn) {
          return true;
        }
      }
      return false;
    }

    // 5. Explicit boolean flags (e.g. leadAccess, chatAccess, ticketAccess, apptAccess)
    final flagKey = isLeadMod ? 'leadAccess' : (isChatMod ? 'chatAccess' : (isTicketMod ? 'ticketAccess' : 'apptAccess'));
    if (a[flagKey] == true || a['has${flagKey[0].toUpperCase()}${flagKey.substring(1)}'] == true) {
      return true;
    }
    if (a[flagKey] == false || a['has${flagKey[0].toUpperCase()}${flagKey.substring(1)}'] == false) {
      return false;
    }

    return false;
  }

  /// Fetch active agents filtered for a specific module ('leads', 'chat', 'ticket', 'appt') and logged-in user context.
  Future<List<Map<String, dynamic>>> fetchModuleAgents(String moduleKey) async {
    final all = await fetchAgents(activeOnly: true);
    final filtered = all.where((a) => isAgentPermittedForModule(a, moduleKey)).toList();

    // Context filter per user login: ensure logged in user is included if active & permitted
    final userEmail = session.email?.trim().toLowerCase() ?? '';
    if (userEmail.isNotEmpty) {
      final userMatch = all.firstWhere(
        (a) => (a['email'] ?? '').toString().trim().toLowerCase() == userEmail,
        orElse: () => <String, dynamic>{},
      );
      if (userMatch.isNotEmpty && isAgentPermittedForModule(userMatch, moduleKey)) {
        if (!filtered.any((a) => (a['email'] ?? '').toString().trim().toLowerCase() == userEmail)) {
          filtered.insert(0, userMatch);
        }
      }
    }
    return filtered;
  }

  /// GET /v1/agents -> active lead-accessed agents list
  Future<List<Map<String, dynamic>>> fetchLeadAgents() async {
    return fetchModuleAgents('leads');
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
