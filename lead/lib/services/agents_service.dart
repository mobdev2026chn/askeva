import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class AgentsService {
  static String get baseUrl => AuthService.baseUrl;

  // --- Agents API ---

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

  static Future<void> createAgent(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/v1/agents/agents');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      final body = jsonDecode(resp.body);
      throw Exception(
        body['msg'] ?? body['message'] ?? 'Failed to create agent',
      );
    }
  }

  static Future<void> updateAgent(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/v1/agents/agents');
    final token = await AuthService.getToken();
    final resp = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(
        body['msg'] ?? body['message'] ?? 'Failed to update agent',
      );
    }
  }

  static Future<void> deleteAgent(String id) async {
    final uri = Uri.parse('$baseUrl/v1/agents/agents/$id');
    final token = await AuthService.getToken();
    final resp = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(
        body['msg'] ?? body['message'] ?? 'Failed to delete agent',
      );
    }
  }

  static Future<void> toggleAgentStatus(String id, bool active) async {
    final uri = Uri.parse('$baseUrl/v1/agents/agents/$id/toggle');
    final token = await AuthService.getToken();
    final resp = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'active': active}),
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(
        body['msg'] ?? body['message'] ?? 'Failed to toggle status',
      );
    }
  }

  static Future<void> changePassword(String email, String newPassword) async {
    final uri = Uri.parse('$baseUrl/v1/agents/agent-password');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'email': email, 'newPassword': newPassword}),
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(
        body['msg'] ?? body['message'] ?? 'Failed to change password',
      );
    }
  }

  // --- Roles API ---

  static Future<List<dynamic>> getRoles() async {
    final uri = Uri.parse('$baseUrl/v1/users/agentroles');
    final token = await AuthService.getToken();
    final resp = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['data'] as List<dynamic>;
    }
    throw Exception('Failed to load roles');
  }

  static Future<void> createRole(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/v1/users/role-access');
    final token = await AuthService.getToken();
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      final body = jsonDecode(resp.body);
      throw Exception(
        body['msg'] ?? body['message'] ?? 'Failed to create role',
      );
    }
  }

  static Future<void> updateRole(String id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/v1/users/role-access/$id');
    final token = await AuthService.getToken();
    final resp = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(
        body['msg'] ?? body['message'] ?? 'Failed to update role',
      );
    }
  }

  static Future<void> deleteRole(String id) async {
    final uri = Uri.parse('$baseUrl/v1/users/role-access/$id');
    final token = await AuthService.getToken();
    final resp = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(
        body['msg'] ?? body['message'] ?? 'Failed to delete role',
      );
    }
  }
}
