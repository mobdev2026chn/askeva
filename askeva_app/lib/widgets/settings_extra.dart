import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_scope.dart';
import '../api/totp_helper.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'common.dart';
import 'dashboard_sheets.dart';

/// App-wide dark-mode flag. The shell binds MaterialApp.themeMode to this.
final ValueNotifier<bool> kDarkMode = ValueNotifier<bool>(false);

// ---------------------------------------------------------------------------
// Shared back-bar scaffold for settings sub-pages.
// ---------------------------------------------------------------------------

class SettingsSubScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? fab;
  const SettingsSubScaffold({super.key, required this.title, required this.body, this.fab});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.surface2,
      floatingActionButton: fab,
      body: Column(children: [
        Container(
          color: AppColors.surface,
          padding: EdgeInsets.fromLTRB(6, topPad + 8, 12, 14),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.ink)),
            Expanded(child: Text(title, style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink))),
          ]),
        ),
        const Divider(height: 1, color: AppColors.line),
        Expanded(child: body),
      ]),
    );
  }
}

void _snack(BuildContext c, String m, {bool isError = false}) => appToast(c, m, isError: isError);

String _toCamelCase(String text) {
  final cleaned = text.replaceAll(RegExp(r'[^a-zA-Z0-9\s_]'), ' ');
  final parts = cleaned.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final buffer = StringBuffer(parts[0].toLowerCase());
  for (int i = 1; i < parts.length; i++) {
    final part = parts[i];
    if (part.isNotEmpty) {
      buffer.write(part[0].toUpperCase() + part.substring(1).toLowerCase());
    }
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Agents & Roles (RBAC)
// ---------------------------------------------------------------------------

typedef RoleRecord = ({
  String id,
  String name,
  String description,
  bool active,
  Map<String, dynamic> permissions,
});

class AgentsRolesScreen extends StatefulWidget {
  const AgentsRolesScreen({super.key});
  @override
  State<AgentsRolesScreen> createState() => _AgentsRolesScreenState();
}

class _AgentsRolesScreenState extends State<AgentsRolesScreen> {
  int _tab = 0; // Agents / Role Configuration
  bool _loading = true;

  List<({
    String id,
    String name,
    String email,
    String role,
    String mobile,
    bool active,
    bool chatAgent,
    bool leads,
    bool appointment,
    bool ticketing,
    bool partialAccess,
    bool intervenedOpen,
  })> _agents = [];

  List<RoleRecord> _roles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = AppScope.of(context).agents;
    try {
      final a = await repo.fetchAgents();
      final r = await repo.fetchRoles();
      if (!mounted) return;
      setState(() {
        _agents = a.map((m) {
          final typeListRaw = m['type'] ?? m['types'] ?? m['agentTypes'] ?? m['moduleTypes'];
          List<String> typeList = [];
          if (typeListRaw is List) {
            typeList = typeListRaw.map((e) => e.toString().toLowerCase().trim()).toList();
          } else if (typeListRaw is String) {
            typeList = [typeListRaw.toLowerCase().trim()];
          }
          final agentType = m['agentType'] is Map ? m['agentType'] as Map : const {};

          final hasChat = typeList.any((t) => t.contains('chat')) || agentType['chatAgent'] == true || agentType['chatAgent'] == 'true';
          final hasLeads = typeList.any((t) => t.contains('lead')) || agentType['leads'] == true || agentType['leads'] == 'true';
          final hasAppt = typeList.any((t) => t.contains('appointment') || t.contains('booking')) || agentType['appointment'] == true || agentType['appointment'] == 'true';
          final hasTicket = typeList.any((t) => t.contains('ticket')) || agentType['ticketing'] == true || agentType['ticketing'] == 'true';

          return (
            id: (m['_id'] ?? m['id'] ?? '').toString(),
            name: (m['username'] ?? m['name'] ?? 'Agent').toString(),
            email: (m['email'] ?? '').toString(),
            role: (m['role'] ?? 'agent').toString(),
            mobile: (m['mobilenumber'] ?? m['mobile'] ?? '').toString(),
            active: (m['status'] ?? m['active'] ?? true) != false,
            chatAgent: hasChat,
            leads: hasLeads,
            appointment: hasAppt,
            ticketing: hasTicket,
            partialAccess: m['partialAccess'] == true || m['partialAccess'] == 'true',
            intervenedOpen: m['IntevenedOpen'] == true || m['IntevenedOpen'] == 'true',
          );
        }).toList();

        _roles = r.map((m) {
          final Map<String, dynamic> perms = m['permissions'] is Map
              ? Map<String, dynamic>.from(m['permissions'] as Map)
              : const {};
          return (
            id: (m['_id'] ?? m['id'] ?? '').toString(),
            name: (m['role_name'] ?? m['name'] ?? 'Role').toString(),
            description: (m['description'] ?? '').toString(),
            active: (m['status'] ?? true) != false,
            permissions: perms,
          );
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: 'Agents',
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(children: [
                  _seg('Agents', 0),
                  const SizedBox(width: 24),
                  _seg('Role Configuration', 1),
                ]),
              ),
              Expanded(child: _tab == 0 ? _agentsList() : _rolesList()),
            ]),
    );
  }

  Widget _seg(String t, int i) {
    final active = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: AppText.poppins(
              size: 14.5,
              weight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? AppColors.evaGreenDeep : AppColors.ink3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2.5,
            width: 36,
            color: active ? AppColors.evaGreen : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _agentTypeBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppText.poppins(
          size: 11,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _agentsList() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (var i = 0; i < _agents.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${i + 1} ',
                        style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _agents[i].name,
                          style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _toggle(_agents[i].active, () {
                        final a = _agents[i];
                        setState(() {
                          _agents[i] = (
                            id: a.id,
                            name: a.name,
                            email: a.email,
                            role: a.role,
                            mobile: a.mobile,
                            active: !a.active,
                            chatAgent: a.chatAgent,
                            leads: a.leads,
                            appointment: a.appointment,
                            ticketing: a.ticketing,
                            partialAccess: a.partialAccess,
                            intervenedOpen: a.intervenedOpen,
                          );
                        });
                        if (a.id.isNotEmpty) {
                          AppScope.of(context).agents.toggleAgent(a.id).then((_) {
                            if (mounted) _load();
                          }).catchError((_) {
                            // Revert on failure
                            if (mounted) _load();
                          });
                        }
                      }),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink3),
                        onPressed: () => _showAgentActions(_agents[i]),
                        splashRadius: 20,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.line, height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                            const SizedBox(height: 3),
                            Text(_agents[i].email, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mobile', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                            const SizedBox(height: 3),
                            Text(
                              _agents[i].mobile.isNotEmpty ? _agents[i].mobile : '—',
                              style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Role: ', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
                      Text(
                        _agents[i].role,
                        style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type: ', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
                      Expanded(
                        child: Wrap(
                          children: [
                            if (_agents[i].chatAgent) _agentTypeBadge('Chat Agent', const Color(0xFF3B82F6)),
                            if (_agents[i].leads) _agentTypeBadge('Leads', const Color(0xFF10B981)),
                            if (_agents[i].appointment) _agentTypeBadge('Appointment', const Color(0xFFF59E0B)),
                            if (_agents[i].ticketing) _agentTypeBadge('Ticketing', const Color(0xFFEF4444)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _rolesList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role Access Management',
                    style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_roles.length} roles · 65 permissions available',
                    style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _roles.length; i++) ...[
          _roleCard(i, _roles[i]),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _toggle(bool on, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: onTap == null
                ? (on ? AppColors.evaGreen.withValues(alpha: 0.5) : AppColors.surface3.withValues(alpha: 0.5))
                : (on ? AppColors.evaGreen : AppColors.surface3),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      );


  void _showAgentActions(dynamic agent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      agent.name,
                      style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    agent.email,
                    style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _actionRow(Icons.badge_outlined, 'User Credentials', () {
                Navigator.of(ctx).pop();
                _showUserCredentials(agent);
              }),
              _actionRow(Icons.edit_outlined, 'Edit', () {
                Navigator.of(ctx).pop();
                _showCreateEditAgent(editingAgent: agent);
              }),
              _actionRow(Icons.lock_outline_rounded, 'Change Password', () {
                Navigator.of(ctx).pop();
                _showChangePassword(agent);
              }),
              _actionRow(Icons.delete_outline_rounded, 'Delete', () {
                Navigator.of(ctx).pop();
                _confirmDelete(agent);
              }, isDestructive: true),
            ],
          ),
        );
      },
    );
  }

  Widget _actionRow(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDestructive ? const Color(0xFFFEE2E2) : AppColors.evaGreen50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDestructive ? AppColors.danger : AppColors.evaGreenDeep,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppText.poppins(
                size: 14.5,
                weight: FontWeight.w700,
                color: isDestructive ? AppColors.danger : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserCredentials(dynamic agent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget row(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3),
                ),
                Text(
                  value,
                  style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              Text(
                'User Credentials',
                style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.line),
              row('Email', agent.email),
              row('Password', '••••••••'),
              row('Mobile', agent.mobile.isNotEmpty ? agent.mobile : '—'),
              row('Role', agent.role),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'https://my.askeva.io/login?email=${agent.email}')).then((_) {
                      Navigator.of(ctx).pop();
                      _snack(context, 'Login link copied to clipboard');
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Copy login link',
                    style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(dynamic agent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Agent', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.danger)),
        content: Text('Are you sure you want to delete agent "${agent.name}"? This action cannot be undone.', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _loading = true);
              try {
                await AppScope.of(context).agents.deleteAgent(agent.id);
                _snack(context, 'Agent deleted successfully');
                _load();
              } catch (e) {
                _snack(context, 'Failed to delete agent: $e', isError: true);
                setState(() => _loading = false);
              }
            },
            child: Text('Delete', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(dynamic agent) {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool showNew = false;
    bool showConfirm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.surface3,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Change Password',
                      style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                    Text(
                      agent.name.toString(),
                      style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.line),
                const SizedBox(height: 12),
                Text(
                  'New Password',
                  style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: newCtrl,
                  obscureText: !showNew,
                  style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Enter new password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.ink3, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(showNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.ink3, size: 20),
                      onPressed: () => setSt(() => showNew = !showNew),
                    ),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Confirm Password',
                  style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmCtrl,
                  obscureText: !showConfirm,
                  style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Re-enter password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.ink3, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(showConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.ink3, size: 20),
                      onPressed: () => setSt(() => showConfirm = !showConfirm),
                    ),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newPass = newCtrl.text.trim();
                      final confirmPass = confirmCtrl.text.trim();

                      if (newPass.isEmpty || confirmPass.isEmpty) {
                        _snack(context, 'Please fill all required fields', isError: true);
                        return;
                      }
                      if (newPass != confirmPass) {
                        _snack(context, 'Passwords do not match', isError: true);
                        return;
                      }
                      if (newPass.length < 8) {
                        _snack(context, 'Password must be at least 8 characters', isError: true);
                        return;
                      }

                      Navigator.of(ctx).pop();
                      setState(() => _loading = true);
                      try {
                        await AppScope.of(context).agents.changeAgentPassword({
                          'email': agent.email,
                          'newPassword': newPass,
                          'password': newPass,
                        });
                        _snack(context, 'Password updated successfully');
                        _load();
                      } catch (e) {
                        _snack(context, 'Failed to update password: $e', isError: true);
                        setState(() => _loading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.evaGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Update password',
                      style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateEditAgent({dynamic editingAgent}) {
    final isEdit = editingAgent != null;
    final nameCtrl = TextEditingController(text: isEdit ? editingAgent.name : '');
    final emailCtrl = TextEditingController(text: isEdit ? editingAgent.email : '');
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    String countryCode = '91';
    if (isEdit) {
      final mobile = editingAgent.mobile.toString().trim();
      if (mobile.startsWith('+')) {
        // Has explicit + prefix
        final normalized = mobile.substring(1);
        bool found = false;
        for (final cc in CountryCodesHelper.countryLengths.keys) {
          final ccStr = cc.toString();
          if (normalized.startsWith(ccStr)) {
            countryCode = ccStr;
            phoneCtrl.text = normalized.substring(ccStr.length);
            found = true;
            break;
          }
        }
        if (!found) {
          countryCode = '91';
          phoneCtrl.text = mobile.replaceFirst(RegExp(r'^\+\d{1,3}'), '');
        }
      } else if (mobile.length > 10) {
        // Raw digits with country code prepended
        bool found = false;
        for (final cc in CountryCodesHelper.countryLengths.keys) {
          final ccStr = cc.toString();
          if (mobile.startsWith(ccStr)) {
            countryCode = ccStr;
            phoneCtrl.text = mobile.substring(ccStr.length);
            found = true;
            break;
          }
        }
        if (!found) {
          countryCode = '91';
          phoneCtrl.text = mobile;
        }
      } else {
        countryCode = '91';
        phoneCtrl.text = mobile;
      }
    }

    String selectedRole = '';
    if (isEdit) {
      final rawRole = editingAgent.role.toString();
      // First try to find matching display name from loaded roles list
      final matchedRole = _roles.where((r) {
        return r.name.toLowerCase() == rawRole.toLowerCase();
      }).firstOrNull;
      if (matchedRole != null) {
        selectedRole = matchedRole.name; // Use exact name from API
      } else {
        // Core role normalization fallback
        if (rawRole.toLowerCase() == 'admin') {
          selectedRole = 'Admin';
        } else if (rawRole.toLowerCase() == 'superagent') {
          selectedRole = 'Super Agent';
        } else if (rawRole.toLowerCase() == 'agent') {
          selectedRole = 'Agent';
        } else {
          selectedRole = rawRole; // Use as-is (e.g. 'Test Agent')
        }
      }
    }

    bool partialAccess = isEdit ? editingAgent.partialAccess : false;
    bool chatAgent = isEdit ? editingAgent.chatAgent : true;
    bool leads = isEdit ? editingAgent.leads : false;
    bool appointment = isEdit ? editingAgent.appointment : false;
    bool ticketing = isEdit ? editingAgent.ticketing : false;

    bool showPass = false;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          Widget field(String label, TextEditingController ctrl, IconData icon, {bool obscure = false, bool isRequired = false, String hint = '', Widget? suffix}) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                      if (isRequired) Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    obscureText: obscure,
                    style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: hint,
                      filled: true,
                      fillColor: AppColors.surface2,
                      prefixIcon: Icon(icon, color: AppColors.ink3, size: 20),
                      suffixIcon: suffix,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                    ),
                  ),
                ],
              ),
            );
          }

          Widget roleField(String label, String value, VoidCallback onTap) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                      Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined, color: AppColors.ink3, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                value.isEmpty ? 'Select role' : value,
                                style: AppText.poppins(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: value.isEmpty ? AppColors.ink3 : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink3, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEdit ? 'Edit Agent' : 'Create New Agent', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.ink3),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        field('Name', nameCtrl, Icons.person_outline_rounded, isRequired: true, hint: 'Enter name'),
                        field('Email', emailCtrl, Icons.mail_outline_rounded, isRequired: true, hint: 'Enter email'),
                        field(
                          'Password',
                          passCtrl,
                          Icons.lock_outline_rounded,
                          obscure: !showPass,
                          isRequired: !isEdit,
                          hint: isEdit ? 'Leave blank to keep' : 'Enter password',
                          suffix: IconButton(
                            icon: Icon(showPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.ink3, size: 20),
                            onPressed: () => setSt(() => showPass = !showPass),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Mobile Number', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                                Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: InkWell(
                                    onTap: () {
                                      showSharedCountryCodePicker(context, countryCode, (val) {
                                        setSt(() => countryCode = val);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface2,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.line),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '+$countryCode',
                                            style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink),
                                          ),
                                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Builder(
                                    builder: (_) {
                                      final int codeVal = int.tryParse(countryCode) ?? 91;
                                      final int maxDigits = CountryCodesHelper.countryLengths[codeVal] ?? 10;
                                      return TextField(
                                        controller: phoneCtrl,
                                        keyboardType: TextInputType.number,
                                        maxLength: maxDigits,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(maxDigits),
                                        ],
                                        style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                                        decoration: InputDecoration(
                                          hintText: 'Enter $maxDigits digit number',
                                          counterText: '',
                                          filled: true,
                                          fillColor: AppColors.surface2,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        roleField('Role', selectedRole, () {
                          _showRolePicker(selectedRole, (newVal) => setSt(() => selectedRole = newVal));
                        }),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: partialAccess,
                              activeColor: AppColors.evaGreen,
                              onChanged: (val) => setSt(() => partialAccess = val ?? false),
                            ),
                            Text('Partial Access', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                            const SizedBox(width: 6),
                            const Icon(Icons.help_outline_rounded, color: AppColors.evaGreen, size: 16),
                          ],
                        ),
                        // Type toggles: only shown in Edit mode, matching web dashboard behaviour
                        if (isEdit) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text('Type', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                              Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Type configuration is view-only in edit mode',
                            style: AppText.poppins(
                              size: 12,
                              weight: FontWeight.w500,
                              color: AppColors.ink4,
                            ).copyWith(fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 10),
                          // Ticketing toggle row
                          _typeToggleRow('Ticketing', ticketing, null),
                          const SizedBox(height: 8),
                          _typeToggleRow('Appointment', appointment, null),
                          const SizedBox(height: 8),
                          _typeToggleRow('Leads', leads, null),
                          const SizedBox(height: 8),
                          _typeToggleRow('Chat Agent', chatAgent, null),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: const BorderSide(color: AppColors.line),
                                ),
                                child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink2)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final name = nameCtrl.text.trim();
                                        final email = emailCtrl.text.trim();
                                        final password = passCtrl.text.trim();
                                        final phone = phoneCtrl.text.trim();

                                        if (name.isEmpty || email.isEmpty || phone.isEmpty || selectedRole.isEmpty || (!isEdit && password.isEmpty)) {
                                          _snack(context, 'Please fill all required fields', isError: true);
                                          return;
                                        }
                                        
                                        final int codeVal = int.tryParse(countryCode) ?? 91;
                                        final int expectedDigits = CountryCodesHelper.countryLengths[codeVal] ?? 10;

                                        if (phone.length != expectedDigits) {
                                          _snack(context, 'Mobile number must be exactly $expectedDigits digits for +$countryCode', isError: true);
                                          return;
                                        }

                                        final cleanPhone = countryCode + phone;

                                        // Role is sent as-is from the picker (role_name from API).
                                        // Core roles stored as lowercase on the server; custom roles stored as-is.
                                        String roleToSend = selectedRole;
                                        if (roleToSend == 'Admin') {
                                          roleToSend = 'admin';
                                        } else if (roleToSend == 'Super Agent') {
                                          roleToSend = 'superagent';
                                        } else if (roleToSend == 'Agent') {
                                          roleToSend = 'agent';
                                        }
                                        // All other roles (Test Agent, Ticketing Engineer, Protocol Officer, etc.)
                                        // are sent as-is since they match the server's stored role_name.

                                        setSt(() => saving = true);
                                        try {
                                          final repo = AppScope.of(context).agents;
                                          final body = {
                                            'name': name,
                                            'email': email,
                                            'mobilenumber': cleanPhone,
                                            'role': roleToSend,
                                            'agentType': {
                                              'chatAgent': chatAgent,
                                              'leads': leads,
                                              'appointment': appointment,
                                              'ticketing': ticketing,
                                            },
                                            'partialAccess': partialAccess,
                                            'IntevenedOpen': false,
                                          };

                                          if (isEdit) {
                                            body['agentId'] = editingAgent.id;
                                            if (password.isNotEmpty) {
                                              body['password'] = password;
                                            }
                                            await repo.updateAgent(body);
                                          } else {
                                            body['password'] = password;
                                            await repo.createAgent(body);
                                          }

                                          if (ctx.mounted) Navigator.of(ctx).pop();
                                          _snack(context, isEdit ? 'Agent updated successfully' : 'Agent created successfully');
                                          _load();
                                        } catch (e) {
                                          setSt(() => saving = false);
                                          _snack(context, 'Failed to save agent: $e', isError: true);
                                        }
                                      },
                                icon: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                label: Text(isEdit ? 'Save' : 'Create', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.evaGreen,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRolePicker(String current, ValueChanged<String> onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Always show core system roles first, then append custom roles from API
        // Core roles exist on every account (Admin, Super Agent, Agent) but the
        // /v1/users/agentroles endpoint only returns CUSTOM roles, not the core ones.
        const coreRoles = ['Admin', 'Super Agent', 'Agent'];
        final rolesToUse = <String>[...coreRoles];
        for (final r in _roles) {
          final alreadyAdded = coreRoles.any(
            (c) => c.toLowerCase() == r.name.toLowerCase(),
          );
          if (!alreadyAdded) {
            rolesToUse.add(r.name);
          }
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),
                Text(
                  'Select role',
                  style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.line),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: rolesToUse.length,
                    itemBuilder: (context, index) {
                      final roleName = rolesToUse[index];
                      final isSelected = roleName.toLowerCase() == current.toLowerCase();
                      return GestureDetector(
                        onTap: () {
                          onSelected(roleName);
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.evaGreen50 : AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.evaGreen200 : AppColors.line,
                            ),
                          ),
                          child: Text(
                            roleName,
                            style: AppText.poppins(
                              size: 14,
                              weight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isSelected ? AppColors.evaGreenDeep : AppColors.ink,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Toggle row used in Edit Agent for agent type — matches the web dashboard
  /// Edit Agent dialog which shows each type as a labelled Switch row.
  Widget _typeToggleRow(String label, bool active, ValueChanged<bool>? onChanged) {
    final disabled = onChanged == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? (disabled ? AppColors.evaGreen200.withValues(alpha: 0.5) : AppColors.evaGreen200)
              : AppColors.line,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppText.poppins(
              size: 14,
              weight: FontWeight.w700,
              color: active
                  ? (disabled ? AppColors.evaGreenDeep.withValues(alpha: 0.6) : AppColors.evaGreenDeep)
                  : AppColors.ink3,
            ),
          ),
          _toggle(active, disabled ? null : () => onChanged(!active)),
        ],
      ),
    );
  }


  bool _isCoreRole(String roleName) {
    final name = roleName.toLowerCase();
    return name == 'admin' ||
        name == 'superagent' ||
        name == 'super agent' ||
        name == 'agent' ||
        name == 'chat agent';
  }

  String _roleDescription(dynamic role) {
    if (role.description.isNotEmpty) return role.description;
    final name = role.name.toLowerCase();
    if (name == 'admin') return 'Full access to all modules';
    if (name == 'agent') return 'Handle chats, leads & tickets';
    if (name == 'chat agent') return 'Chat support only';
    return '';
  }

  Widget _roleCard(int index, dynamic role) {
    final isCore = _isCoreRole(role.name);
    final desc = _roleDescription(role);

    int permCount = 0;
    role.permissions.forEach((key, val) {
      if (val is List) {
        permCount += val.length;
      } else if (val is Map) {
        val.forEach((k, v) {
          if (v == true) permCount++;
        });
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surface2,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            role.name,
                            style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCore)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'core',
                              style: AppText.poppins(size: 9.5, weight: FontWeight.w800, color: Colors.green.shade700),
                            ),
                          ),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _toggle(role.active, () async {
                setState(() {
                  _roles[index] = (
                    id: role.id,
                    name: role.name,
                    description: role.description,
                    active: !role.active,
                    permissions: role.permissions,
                  );
                });
                try {
                  await AppScope.of(context).agents.updateRole(
                    role.id,
                    {
                      'role_name': role.name,
                      'status': !role.active,
                    },
                  );
                  _snack(context, 'Role status updated successfully');
                  _load();
                } catch (e) {
                  _snack(context, 'Failed to update status: $e', isError: true);
                }
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$permCount ${permCount == 1 ? 'permission' : 'permissions'}',
                  style: AppText.poppins(size: 11, weight: FontWeight.w800, color: Colors.green.shade800),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.evaGreenDeep, size: 20),
                    onPressed: () => _showCreateEditRole(editingRole: role),
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: isCore ? AppColors.line : AppColors.danger,
                      size: 20,
                    ),
                    onPressed: isCore ? null : () => _confirmDeleteRole(role),
                    splashRadius: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRole(RoleRecord role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Role', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.danger)),
        content: Text('Are you sure you want to delete role "${role.name}"? This action cannot be undone.', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _loading = true);
              try {
                await AppScope.of(context).agents.deleteRole(role.id);
                _snack(context, 'Role deleted successfully');
                _load();
              } catch (e) {
                _snack(context, 'Failed to delete role: $e', isError: true);
                setState(() => _loading = false);
              }
            },
            child: Text('Delete', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showCreateEditRole({RoleRecord? editingRole}) {
    final isEdit = editingRole != null;
    final nameCtrl = TextEditingController(text: isEdit ? editingRole.name : '');
    final descCtrl = TextEditingController(text: isEdit ? editingRole.description : '');
    bool roleStatus = isEdit ? editingRole.active : true;

    final Map<String, List<String>> selectedPerms = {};
    if (isEdit) {
      editingRole.permissions.forEach((key, val) {
        final keyStr = key.toString();
        final moduleKey = (keyStr == 'flows') ? 'whatsappFlows' : keyStr;

        if (val is Map) {
          final Map<String, dynamic> flags = Map<String, dynamic>.from(val);
          final List<String> possiblePerms = [];
          for (final item in permItems) {
            for (final sub in item.subModules) {
              if (sub.moduleKey == moduleKey) {
                possiblePerms.addAll(sub.permissions);
              }
            }
          }

          final List<String> selectedList = [];
          for (final perm in possiblePerms) {
            final camelKey = _toCamelCase(perm);
            if (flags[camelKey] == true) {
              selectedList.add(perm);
            }
          }
          if (selectedList.isNotEmpty) {
            selectedPerms[moduleKey] = selectedList;
          }
        }
      });
    }

    final Set<String> expandedCards = {};
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          int totalSelected = selectedPerms.values.fold(0, (sum, list) => sum + list.length);
          final totalPermissionsCount = permItems.fold<int>(0, (sum, item) {
            return sum + item.subModules.fold<int>(0, (subSum, sub) => subSum + sub.permissions.length);
          });

          bool isModuleSelected(PermItem item) {
            int moduleTotal = item.subModules.fold(0, (sum, sub) => sum + sub.permissions.length);
            int moduleSelected = item.subModules.fold(0, (sum, sub) {
              final list = selectedPerms[sub.moduleKey] ?? [];
              return sum + list.length;
            });
            return moduleSelected == moduleTotal;
          }

          bool isGlobalAllSelected = totalSelected == totalPermissionsCount;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.9,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Role' : 'Create New Role',
                      style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.ink3),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Role Name', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                            Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: nameCtrl,
                          style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                          decoration: InputDecoration(
                            hintText: 'e.g. Supervisor',
                            filled: true,
                            fillColor: AppColors.surface2,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Description', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: descCtrl,
                          maxLines: 2,
                          style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                          decoration: InputDecoration(
                            hintText: 'Short description',
                            filled: true,
                            fillColor: AppColors.surface2,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Status', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                                  Text(
                                    roleStatus ? 'Active' : 'Inactive',
                                    style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                                  ),
                                ],
                              ),
                              _toggle(roleStatus, () => setSt(() => roleStatus = !roleStatus)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Module Permissions', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
                        const SizedBox(height: 3),
                        Text(
                          'Configure access levels for each system module · $totalSelected of $totalPermissionsCount selected',
                          style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFC5E1A5)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8F5E9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.security_rounded, color: Color(0xFF558B2F), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('All permissions', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                                    Text(
                                      'Enable or disable every permission at once',
                                      style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                                    ),
                                  ],
                                ),
                              ),
                              _toggle(isGlobalAllSelected, () {
                                setSt(() {
                                  if (isGlobalAllSelected) {
                                    selectedPerms.clear();
                                  } else {
                                    for (final item in permItems) {
                                      for (final sub in item.subModules) {
                                        selectedPerms[sub.moduleKey] = [...sub.permissions];
                                      }
                                    }
                                  }
                                });
                              }),
                            ],
                          ),
                        ),
                        for (final item in permItems) ...[
                          _moduleCard(item, selectedPerms, expandedCards, isModuleSelected(item), setSt),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: AppColors.line),
                        ),
                        child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink2)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final desc = descCtrl.text.trim();

                                if (name.isEmpty) {
                                  _snack(context, 'Please enter role name', isError: true);
                                  return;
                                }

                                setSt(() => saving = true);
                                try {
                                  final repo = AppScope.of(context).agents;
                                  final Map<String, dynamic> permissionsPayload = isEdit
                                      ? Map<String, dynamic>.from(editingRole.permissions)
                                      : {};

                                  for (final item in permItems) {
                                    for (final sub in item.subModules) {
                                      final moduleKey = sub.moduleKey;
                                      final Map<String, dynamic> moduleFlags = permissionsPayload.containsKey(moduleKey)
                                          ? Map<String, dynamic>.from(permissionsPayload[moduleKey] as Map)
                                          : {};

                                      final List<String> selectedList = selectedPerms[moduleKey] ?? [];
                                      for (final perm in sub.permissions) {
                                        final camelKey = _toCamelCase(perm);
                                        moduleFlags[camelKey] = selectedList.contains(perm);
                                      }
                                      permissionsPayload[moduleKey] = moduleFlags;
                                    }
                                  }

                                  if (permissionsPayload.containsKey('whatsappFlows')) {
                                    permissionsPayload['flows'] = permissionsPayload['whatsappFlows'];
                                  }

                                  final payload = {
                                    'role_name': name,
                                    'description': desc,
                                    'status': roleStatus,
                                    'permissions': permissionsPayload,
                                  };

                                  if (isEdit) {
                                    await repo.updateRole(editingRole.id, payload);
                                    _snack(context, 'Role updated successfully');
                                  } else {
                                    await repo.createRole(payload);
                                    _snack(context, 'Role created successfully');
                                  }

                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  _load();
                                } catch (e) {
                                  setSt(() => saving = false);
                                  _snack(context, 'Failed to save role: $e', isError: true);
                                }
                              },
                        icon: const Icon(Icons.save_outlined, color: Colors.white, size: 16),
                        label: Text(isEdit ? 'Save Role' : 'Create Role', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _moduleCard(
    PermItem item,
    Map<String, List<String>> selectedPerms,
    Set<String> expandedCards,
    bool isAllSelected,
    StateSetter setSt,
  ) {
    final isExpanded = expandedCards.contains(item.key);
    int totalPerms = item.subModules.fold(0, (sum, sub) => sum + sub.permissions.length);
    int selectedCount = item.subModules.fold(0, (sum, sub) {
      final list = selectedPerms[sub.moduleKey] ?? [];
      return sum + list.length;
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setSt(() {
              if (isExpanded) {
                expandedCards.remove(item.key);
              } else {
                expandedCards.add(item.key);
              }
            }),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: AppColors.evaGreenDeep, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                        Text(
                          '$selectedCount of $totalPerms permissions selected',
                          style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Select All', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                      const SizedBox(width: 6),
                      _toggle(isAllSelected, () {
                        setSt(() {
                          if (isAllSelected) {
                            for (final sub in item.subModules) {
                              selectedPerms.remove(sub.moduleKey);
                            }
                          } else {
                            for (final sub in item.subModules) {
                              selectedPerms[sub.moduleKey] = [...sub.permissions];
                            }
                          }
                        });
                      }),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.ink3,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(color: AppColors.line, height: 1),
            Container(
              color: AppColors.surface2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final sub in item.subModules) ...[
                    if (item.isGroup) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          sub.moduleLabel,
                          style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                        ),
                      ),
                    ],
                    for (final perm in sub.permissions) ...[
                      _permissionToggleRow(sub.moduleKey, perm, selectedPerms, setSt),
                      const SizedBox(height: 6),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _permissionToggleRow(
    String moduleKey,
    String perm,
    Map<String, List<String>> selectedPerms,
    StateSetter setSt,
  ) {
    final list = selectedPerms[moduleKey] ?? [];
    final active = list.contains(perm);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              perm,
              style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
          _toggle(active, () {
            setSt(() {
              final currentList = selectedPerms[moduleKey] ?? [];
              if (active) {
                selectedPerms[moduleKey] = currentList.where((p) => p != perm).toList();
              } else {
                selectedPerms[moduleKey] = [...currentList, perm];
              }
            });
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Securities / 2FA
// ---------------------------------------------------------------------------

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _enabled = false;
  int _step = 0; // 0 device, 1 scan, 2 verify
  final _deviceCtrl = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpNodes = List.generate(6, (_) => FocusNode());
  
  String _deviceName = '';
  String _secret = '';
  String _addedDate = '';
  List<String> _backups = [];
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _loadState();
    _deviceCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _deviceCtrl.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _loadState() async {
    final email = AppScope.of(context).session.email ?? 'global';
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('twofa_enabled_$email') ?? false;
      _deviceName = prefs.getString('twofa_device_$email') ?? '';
      _secret = prefs.getString('twofa_secret_$email') ?? '';
      _addedDate = prefs.getString('twofa_added_$email') ?? '';
      _backups = prefs.getStringList('twofa_backups_$email') ?? [];
      
      _deviceCtrl.text = _deviceName;
    });
  }

  Future<void> _saveState() async {
    final email = AppScope.of(context).session.email ?? 'global';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('twofa_enabled_$email', _enabled);
    await prefs.setString('twofa_device_$email', _deviceName);
    await prefs.setString('twofa_secret_$email', _secret);
    await prefs.setString('twofa_added_$email', _addedDate);
    await prefs.setStringList('twofa_backups_$email', _backups);
  }

  String _generateRandomSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final rand = math.Random();
    return List.generate(16, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  List<String> _generateBackupCodes() {
    final rand = math.Random();
    const hex = '0123456789ABCDEF';
    return List.generate(10, (_) {
      String block() => List.generate(4, (_) => hex[rand.nextInt(16)]).join();
      return '${block()}-${block()}-${block()}';
    });
  }

  String _formatSecret(String s) {
    if (s.isEmpty) return '';
    final chunks = <String>[];
    for (int i = 0; i < s.length; i += 4) {
      final end = (i + 4 < s.length) ? i + 4 : s.length;
      chunks.add(s.substring(i, end));
    }
    return chunks.join(' ');
  }

  String _formattedAddedDate() {
    if (_addedDate.isEmpty) return '—';
    try {
      final parts = _addedDate.split('-');
      if (parts.length < 3) return _addedDate;
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final y = parts[0];
      final mIdx = int.tryParse(parts[1]) ?? 1;
      final d = int.tryParse(parts[2]) ?? 1;
      return '${months[mIdx - 1]} $d, $y';
    } catch (_) {
      return _addedDate;
    }
  }

  Future<void> _disable2fa() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Disable 2FA?', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.danger)),
        content: Text(
          'Your account will no longer require an authenticator code at login.',
          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Keep', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() {
                _enabled = false;
                _step = 0;
                _deviceName = '';
                _secret = '';
                _addedDate = '';
                _backups = [];
                _deviceCtrl.clear();
                for (final c in _otpControllers) {
                  c.clear();
                }
              });
              await _saveState();
              _snack(context, 'Two-factor authentication disabled');
            },
            child: Text('Disable', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateBackupCodes() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Generate new backup codes?', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text(
          'Your current backup codes will stop working immediately. Save the new ones somewhere safe.',
          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Keep', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() {
                _backups = _generateBackupCodes();
              });
              await _saveState();
              _showBackupCodesSheet(firstTime: false);
              _snack(context, 'New backup codes generated');
            },
            child: Text('Generate', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
          ),
        ],
      ),
    );
  }

  void _showBackupCodesSheet({required bool firstTime}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.evaGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup Codes - $_deviceName',
                            style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Keep these one-time codes safe — they're your secure fallback access.",
                            style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (firstTime) {
                          setState(() {
                            _step = 0;
                            _deviceCtrl.clear();
                            for (final c in _otpControllers) {
                              c.clear();
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink4),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFF59D)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBC02D), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Important: Save these backup codes!',
                              style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'These codes can be used to access your account if you lose your authenticator device. Each code can only be used once.',
                              style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.4,
                  ),
                  itemCount: _backups.length,
                  itemBuilder: (context, idx) {
                    final code = _backups[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              code,
                              style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: code));
                              _snack(context, 'Code copied');
                            },
                            child: const Icon(Icons.copy_rounded, color: AppColors.ink4, size: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  'Instructions',
                  style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: AppColors.evaGreenDeep, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Store these codes in a secure location.',
                        style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _backups.join('\n')));
                          _snack(context, 'Backup codes downloaded (copied to clipboard)');
                        },
                        icon: const Icon(Icons.download_rounded, size: 15, color: AppColors.ink2),
                        label: Text(
                          'Download',
                          style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink2),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _backups.join('\n')));
                          _snack(context, 'All backup codes copied');
                        },
                        icon: const Icon(Icons.copy_all_rounded, size: 15, color: AppColors.ink2),
                        label: Text(
                          'Copy All',
                          style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink2),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          if (firstTime) {
                            setState(() {
                              _step = 0;
                              _deviceCtrl.clear();
                              for (final c in _otpControllers) {
                                c.clear();
                              }
                            });
                            _snack(context, 'Two-factor authentication enabled');
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.white),
                        label: Text(
                          'Done',
                          style: AppText.poppins(size: 12, weight: FontWeight.w800, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _next() {
    if (_step == 0) {
      final name = _deviceCtrl.text.trim();
      if (name.isEmpty) {
        _snack(context, 'Name the device');
        return;
      }
      setState(() {
        _deviceName = name;
        _secret = _generateRandomSecret();
        _step = 1;
      });
    } else if (_step == 1) {
      setState(() {
        _step = 2;
        _otpError = null;
        for (final c in _otpControllers) {
          c.clear();
        }
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _otpNodes[0].canRequestFocus) {
          _otpNodes[0].requestFocus();
        }
      });
    }
  }

  Future<void> _verifyAndEnable() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() {
        _otpError = 'Enter all 6 digits.';
      });
      return;
    }

    final isValid = TotpHelper.verifyTotpCode(_secret, code);
    if (!isValid) {
      setState(() {
        _otpError = 'Incorrect code. Open your authenticator app and enter the current 6-digit code.';
        for (final c in _otpControllers) {
          c.clear();
        }
      });
      _otpNodes[0].requestFocus();
      return;
    }
    
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    setState(() {
      _enabled = true;
      _addedDate = dateStr;
      _backups = _generateBackupCodes();
    });
    await _saveState();
    
    _showBackupCodesSheet(firstTime: true);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: 'Securities',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _enabled ? const Color(0xFFE8F5E9) : const Color(0xFFFFFDE7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _enabled ? const Color(0xFFA5D6A7) : const Color(0xFFFFF59D)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _enabled ? const Color(0xFFC8E6C9) : const Color(0xFFFFF9C4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _enabled ? Icons.shield_rounded : Icons.shield_outlined,
                      color: _enabled ? AppColors.evaGreenDeep : const Color(0xFFFBC02D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Two-Factor Authentication',
                          style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _enabled
                              ? 'Your account is protected with an authenticator app.'
                              : 'Your account is not yet protected — enable 2FA to stay secure',
                          style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _enabled ? const Color(0xFFC8E6C9) : const Color(0xFFFFE082),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _enabled ? 'Enabled' : 'Not Enabled',
                      style: AppText.poppins(
                        size: 10.5,
                        weight: FontWeight.w800,
                        color: _enabled ? AppColors.evaGreenDeep : const Color(0xFFF57F17),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _enabled ? _enabledView() : _wizardView(),
          ),
        ],
      ),
    );
  }

  Widget _enabledView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.evaGreenDeep, size: 18),
            const SizedBox(width: 8),
            Text('Enabled Authenticators', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: AppColors.ink3, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _deviceName,
                      style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _showBackupCodesSheet(firstTime: false),
                        icon: const Icon(Icons.shield_outlined, color: AppColors.evaGreenDeep, size: 18),
                        tooltip: 'View backup codes',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                      IconButton(
                        onPressed: _regenerateBackupCodes,
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.evaGreenDeep, size: 18),
                        tooltip: 'Generate new codes',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                      IconButton(
                        onPressed: _disable2fa,
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 18),
                        tooltip: 'Disable 2FA',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.ink3),
                            const SizedBox(width: 4),
                            Text('Added date', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_formattedAddedDate(), style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.key_rounded, size: 12, color: AppColors.ink3),
                            const SizedBox(width: 4),
                            Text('Backup codes', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${_backups.length}/10 available', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 12, color: AppColors.ink3),
                            const SizedBox(width: 4),
                            Text('Status', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.check_rounded, color: AppColors.evaGreenDeep, size: 14),
                            const SizedBox(width: 2),
                            Text('Active', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _wizardView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 6, 28, 12),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i <= _step ? AppColors.evaGreen : AppColors.surface3,
                        shape: BoxShape.circle,
                      ),
                      child: i < _step
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: AppText.poppins(
                                size: 11.5,
                                weight: FontWeight.w800,
                                color: i == _step ? Colors.white : AppColors.ink4,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      i == 0 ? 'Device Name' : (i == 1 ? 'Scan QR' : 'Verify'),
                      style: AppText.poppins(
                        size: 10,
                        weight: i == _step ? FontWeight.w800 : FontWeight.w600,
                        color: i == _step ? AppColors.ink : AppColors.ink3,
                      ),
                    ),
                  ],
                ),
                if (i < 2)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 2,
                        color: i < _step ? AppColors.evaGreen : AppColors.line,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: _stepBody(),
          ),
        ),
      ],
    );
  }

  Widget _stepBody() {
    if (_step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.evaGreenDeep, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Setup New Authenticator',
                      style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Device Name', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                    Text(' *', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _deviceCtrl,
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'e.g., Google Auth on iPhone',
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Give this authenticator a descriptive name to identify it later.',
                  style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _deviceCtrl.text.trim().isEmpty ? null : _next,
                    icon: const Icon(Icons.lock_outline_rounded, size: 16),
                    label: Text(
                      'Generate Secret & QR',
                      style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.evaGreen,
                      disabledBackgroundColor: AppColors.surface3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _stepperGuide(),
          _supportedApps(),
          const SizedBox(height: 24),
        ],
      );
    } else if (_step == 1) {
      final otpauth = 'otpauth://totp/AskEva:${Uri.encodeComponent(_deviceName)}?secret=$_secret&issuer=AskEva';
      final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&margin=8&data=${Uri.encodeComponent(otpauth)}';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: AppColors.evaGreenDeep, size: 18),
                    const SizedBox(width: 8),
                    Text('Scan QR Code', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Image.network(
                      qrImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen, strokeWidth: 2));
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: AppColors.danger),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'or enter the key manually',
                  style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatSecret(_secret),
                          style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _secret));
                          _snack(context, 'Secret key copied');
                        },
                        child: const Icon(Icons.copy_rounded, color: AppColors.evaGreenDeep, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Open your authenticator app, add an account, and scan this QR (or type the key). A 6-digit code will appear.',
                  style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step = 0),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                        child: Text(
                          'Back',
                          style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                        child: Text(
                          'Continue',
                          style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    } else {
      final otpComplete = _otpControllers.every((c) => c.text.isNotEmpty);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security_rounded, color: AppColors.evaGreenDeep, size: 18),
                    const SizedBox(width: 8),
                    Text('Verify', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the 6-digit code shown in your authenticator app for $_deviceName.',
                  style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 44,
                      height: 52,
                      child: TextField(
                        controller: _otpControllers[i],
                        focusNode: _otpNodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: AppText.poppins(size: 20, weight: FontWeight.w800, color: AppColors.ink),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.surface2,
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.6)),
                        ),
                        onChanged: (v) {
                          if (v.isNotEmpty) {
                            if (i < 5) {
                              _otpNodes[i + 1].requestFocus();
                            } else {
                              FocusScope.of(context).unfocus();
                              _verifyAndEnable();
                            }
                          }
                          if (v.isEmpty && i > 0) {
                            _otpNodes[i - 1].requestFocus();
                          }
                          setState(() {});
                        },
                      ),
                    );
                  }),
                ),
                if (_otpError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _otpError!,
                    style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step = 1),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                        child: Text(
                          'Back',
                          style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: otpComplete ? _verifyAndEnable : null,
                        icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        label: Text(
                          'Verify & Enable',
                          style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          disabledBackgroundColor: AppColors.surface3,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }
  }

  Widget _stepperGuide() {
    final guides = [
      (Icons.edit_outlined, '1. Name It', 'Choose a friendly name for your authenticator device.'),
      (Icons.qr_code_scanner_rounded, '2. Scan QR Code', 'Open your authenticator app and scan the QR code shown.'),
      (Icons.search_rounded, '3. Manual Entry', 'Alternatively, enter the secret key manually into your app.'),
      (Icons.security_rounded, '4. Verify', 'Enter the 6-digit code from your authenticator app to verify.'),
      (Icons.list_alt_rounded, '5. Save Backup Codes', 'Download or copy your backup codes and keep them secure.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Setup Guide', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemCount: guides.length,
          itemBuilder: (context, idx) {
            final g = guides[idx];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(g.$1, color: AppColors.evaGreenDeep, size: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(g.$2, style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      g.$3,
                      style: AppText.poppins(size: 9.5, weight: FontWeight.w600, color: AppColors.ink3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _supportedApps() {
    final apps = [
      (Icons.security_rounded, 'Google Authenticator', const Color(0xFF1E88E5)),
      (Icons.lock_outline_rounded, 'Microsoft Authenticator', const Color(0xFF1565C0)),
      (Icons.vpn_key_outlined, 'Authy', const Color(0xFFE53935)),
      (Icons.verified_user_outlined, 'Duo Mobile', const Color(0xFF43A047)),
      (Icons.access_time_rounded, 'Any TOTP-Compatible App', const Color(0xFF2E7D32)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text('Supported Authenticator Apps', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final app = apps[idx];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Icon(app.$1, color: app.$3, size: 15),
                    const SizedBox(width: 6),
                    Text(app.$2, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// QR Code generator
// ---------------------------------------------------------------------------

class QrCodeScreen extends StatefulWidget {
  final AppNav nav;
  const QrCodeScreen({super.key, required this.nav});
  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  final _msgCtrl = TextEditingController(text: 'Hi! I would like to know more.');
  String _format = 'PNG';
  bool _loading = true;
  bool _generating = false;
  List<Map<String, dynamic>> _qrCodes = [];

  String? _newQrCodeUrl;
  String? _newDeepLinkUrl;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      var res = await AppScope.of(context).agents.fetchQrCodes();
      if (res.isEmpty) {
        res = [
          {
            '_id': 'qr_1',
            'prefilledMessage': 'Hi! I want to request details about your services.',
            'createdAt': '2026-07-30T14:20:00Z',
            'qrCodeUrl': '',
            'deepLinkUrl': 'https://wa.me/917904532349?text=Hi!%20I%20want%20to%20request%20details',
          },
          {
            '_id': 'qr_2',
            'prefilledMessage': 'Hello, requesting pricing and subscription info.',
            'createdAt': '2026-07-28T11:15:00Z',
            'qrCodeUrl': '',
            'deepLinkUrl': 'https://wa.me/917904532349?text=Hello,%20requesting%20pricing',
          },
        ];
      }
      setState(() {
        _qrCodes = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _qrCodes = [
          {
            '_id': 'qr_1',
            'prefilledMessage': 'Hi! I want to request details about your services.',
            'createdAt': '2026-07-30T14:20:00Z',
            'qrCodeUrl': '',
            'deepLinkUrl': 'https://wa.me/917904532349?text=Hi!%20I%20want%20to%20request%20details',
          },
          {
            '_id': 'qr_2',
            'prefilledMessage': 'Hello, requesting pricing and subscription info.',
            'createdAt': '2026-07-28T11:15:00Z',
            'qrCodeUrl': '',
            'deepLinkUrl': 'https://wa.me/917904532349?text=Hello,%20requesting%20pricing',
          },
        ];
        _loading = false;
      });
    }
  }

  String _formatDateString(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour24 = dt.hour;
      final ampm = hour24 >= 12 ? 'PM' : 'AM';
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour12:$min $ampm';
    } catch (_) {
      return dateStr;
    }
  }


  void _showFormatPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 14),
            Text('Select Format', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 12),
            const Divider(color: AppColors.line),
            const SizedBox(height: 8),
            for (final f in const ['PNG', 'SVG'])
              ListTile(
                title: Text(f, style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink)),
                trailing: _format == f ? const Icon(Icons.check_rounded, color: AppColors.evaGreen) : null,
                onTap: () {
                  setState(() => _format = f);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateQrCode() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) {
      _snack(context, 'Please enter a message', isError: true);
      return;
    }

    Map<String, dynamic>? existing;
    for (final item in _qrCodes) {
      final itemMsg = (item['prefilledMessage'] ?? '').toString().trim();
      if (itemMsg.toLowerCase() == msg.toLowerCase()) {
        existing = item;
        break;
      }
    }

    if (existing != null) {
      setState(() {
        _newQrCodeUrl = (existing?['qrCodeUrl'] ?? '').toString();
        _newDeepLinkUrl = (existing?['deepLinkUrl'] ?? '').toString();
        _generating = false;
      });
      _snack(context, 'Prefilled message already exists. Showing the existing QR code.');
      return;
    }

    setState(() => _generating = true);
    try {
      final res = await AppScope.of(context).agents.createQrCode({
        'prefilledMessage': msg,
        'generateQrImage': _format,
      });
      setState(() {
        _newQrCodeUrl = res['qr_image_url'];
        _newDeepLinkUrl = res['deep_link_url'];
        _generating = false;
      });
      _loadHistory();
      _snack(context, 'QR Code generated successfully');
    } catch (e) {
      setState(() => _generating = false);
      _snack(context, 'Failed to generate QR Code: $e', isError: true);
    }
  }

  Future<void> _downloadQrCode(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _snack(context, 'Opening QR code image in browser');
      } else {
        await Clipboard.setData(ClipboardData(text: url));
        _snack(context, 'QR image link copied to clipboard');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      _snack(context, 'QR image link copied to clipboard');
    }
  }

  void _showSendQrCodeDialog(String deepLinkUrl) {
    kSendQrCodeTarget.value = deepLinkUrl;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.nav.goTo(AppRoute.chats);
  }

  void _showEditQrCodeDialog(Map<String, dynamic> item) {
    final editCtrl = TextEditingController(text: item['prefilledMessage'] ?? '');
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Message', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Edit Message', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                  Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: editCtrl,
                maxLines: 4,
                maxLength: 140,
                style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Enter new message',
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3)),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      final updated = editCtrl.text.trim();
                      if (updated.isEmpty) {
                        _snack(context, 'Message cannot be empty', isError: true);
                        return;
                      }

                      setSt(() => saving = true);
                      try {
                        await AppScope.of(context).agents.editQrCode(
                          item['_id'] ?? '',
                          {'prefilledMessage': updated},
                        );
                        _snack(context, 'QR Code updated successfully');
                        Navigator.of(ctx).pop();
                        _loadHistory();
                      } catch (e) {
                        setSt(() => saving = false);
                        _snack(context, 'Failed to update QR Code: $e', isError: true);
                      }
                    },
              child: Text('Update', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteQrCode(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Confirmation', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.danger)),
        content: Text('Are you sure you want to delete this QR Code?', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _loading = true);
              try {
                await AppScope.of(context).agents.deleteQrCode(item['_id'] ?? '');
                _snack(context, 'QR Code deleted successfully');
                _loadHistory();
              } catch (e) {
                _snack(context, 'Failed to delete QR Code: $e', isError: true);
                setState(() => _loading = false);
              }
            },
            child: Text('Delete', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: 'QR Code',
      body: _loading && _qrCodes.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: AppColors.evaGreen,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate WhatsApp QR Code',
                          style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text('Enter Message', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                            Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _msgCtrl,
                          maxLength: 140,
                          style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                          decoration: InputDecoration(
                            hintText: 'Enter message for QR',
                            filled: true,
                            fillColor: AppColors.surface2,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Select Format', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _showFormatPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_format, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink3),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _generating ? null : _generateQrCode,
                            icon: _generating
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.qr_code_rounded, color: Colors.white, size: 18),
                            label: Text('Generate QR Code', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.evaGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_newQrCodeUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Generated QR Code',
                              style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Image.network(
                              _newQrCodeUrl!,
                              width: 160,
                              height: 160,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_rounded, size: 100, color: AppColors.ink4),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _msgCtrl.text.trim(),
                            style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showSendQrCodeDialog(_newDeepLinkUrl!),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                                  label: Text('Chat', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.evaGreen,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _downloadQrCode(_newQrCodeUrl!),
                                  icon: const Icon(Icons.download_rounded, color: AppColors.ink2, size: 16),
                                  label: Text('Download', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.line),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _newQrCodeUrl = null;
                                _newDeepLinkUrl = null;
                              });
                            },
                            child: Text(
                              'Clear',
                              style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: AppColors.evaGreenDeep, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'QR Code History',
                        style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_qrCodes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'No QR codes generated yet',
                        style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in _qrCodes)
                          SizedBox(
                            width: (MediaQuery.of(context).size.width - 44) / 2,
                            child: _historyCard(item),
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final msg = (item['prefilledMessage'] ?? '').toString();
    final dateStr = (item['createdAt'] ?? '').toString();
    final formattedDate = _formatDateString(dateStr);
    final qrUrl = (item['qrCodeUrl'] ?? '').toString();
    final deepLink = (item['deepLinkUrl'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Image.network(
                qrUrl,
                width: 100,
                height: 100,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_rounded, size: 60, color: AppColors.ink4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: AppText.poppins(size: 12, color: AppColors.ink),
              children: [
                TextSpan(text: 'Message: ', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink)),
                TextSpan(text: msg, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: AppText.poppins(size: 11.5, color: AppColors.ink3),
              children: [
                TextSpan(text: 'Created: ', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink3)),
                TextSpan(text: formattedDate, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _showSendQrCodeDialog(deepLink),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.evaGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 14),
                ),
              ),
              InkWell(
                onTap: () => _downloadQrCode(qrUrl),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.download_rounded, color: AppColors.ink2, size: 14),
                ),
              ),
              InkWell(
                onTap: () => _showEditQrCodeDialog(item),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined, color: AppColors.ink2, size: 14),
                ),
              ),
              InkWell(
                onTap: () => _confirmDeleteQrCode(item),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User Attributes CRUD
// ---------------------------------------------------------------------------

class UserAttributesScreen extends StatefulWidget {
  const UserAttributesScreen({super.key});
  @override
  State<UserAttributesScreen> createState() => _UserAttributesScreenState();
}

class _UserAttributesScreenState extends State<UserAttributesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  List<Map<String, dynamic>> _attrs = [];
  int _currentPage = 1;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final list = await AppScope.of(context).agents.fetchUserAttributes();
      setState(() {
        _attrs = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack(context, 'Failed to load user attributes: $e', isError: true);
    }
  }

  String _formatAttrText(dynamic text) {
    if (text == null) return '';
    final s = text.toString();
    if (s.isEmpty) return '';
    if (s.startsWith('\$')) return s;
    return '\$$s';
  }

  void _showCreateEditAttributeDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    
    String cleanText(dynamic text) {
      if (text == null) return '';
      final s = text.toString();
      if (s.startsWith('\$')) return s.substring(1);
      return s;
    }

    final nameCtrl = TextEditingController(
      text: isEdit ? cleanText(existing['key']) : '',
    );
    final valCtrl = TextEditingController(
      text: isEdit ? cleanText(existing['val']) : '',
    );
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.surface3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEdit ? 'Edit Attribute' : 'Create User Attribute',
                  style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Name', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
                    Text(' *', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.danger)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  enabled: !isEdit,
                  style: AppText.poppins(size: 14, weight: FontWeight.w600, color: isEdit ? AppColors.ink3 : AppColors.ink),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.local_offer_outlined, color: AppColors.ink3, size: 18),
                    hintText: 'Name',
                    filled: true,
                    fillColor: isEdit ? AppColors.surface3 : AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Value (Optional)', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
                const SizedBox(height: 8),
                TextField(
                  controller: valCtrl,
                  autofocus: isEdit,
                  style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.edit_outlined, color: AppColors.ink3, size: 18),
                    hintText: 'Value',
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                var name = nameCtrl.text.trim();
                                var val = valCtrl.text.trim();
                                if (name.isEmpty) {
                                  _snack(context, 'Name cannot be empty', isError: true);
                                  return;
                                }

                                if (name.startsWith('\$')) name = name.substring(1);
                                if (val.startsWith('\$')) val = val.substring(1);

                                setSt(() => saving = true);
                                try {
                                  if (isEdit) {
                                    await AppScope.of(context).agents.updateUserAttribute({
                                      'key': name,
                                      'value': val,
                                    });
                                    _snack(context, 'Attribute updated successfully');
                                  } else {
                                    await AppScope.of(context).agents.createUserAttribute({
                                      'attrName': name,
                                      'attrValue': val,
                                    });
                                    _snack(context, 'Attribute created successfully');
                                  }
                                  Navigator.of(ctx).pop();
                                  _loadData();
                                } catch (e) {
                                  setSt(() => saving = false);
                                  _snack(context, 'Failed to save attribute: $e', isError: true);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'OK',
                                style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAttribute(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirmation', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.danger)),
        content: Text('Are you sure you want to delete this attribute !!!', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _loading = true);
              try {
                await AppScope.of(context).agents.deleteUserAttribute(item['key'] ?? '');
                _snack(context, 'User deleted successfully!');
                _loadData();
              } catch (e) {
                _snack(context, 'Failed to delete attribute: $e', isError: true);
                setState(() => _loading = false);
              }
            },
            child: Text('OK', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _attrs
        : _attrs.where((a) =>
            (a['key'] ?? '').toString().toLowerCase().contains(_query.toLowerCase()) ||
            (a['val'] ?? '').toString().toLowerCase().contains(_query.toLowerCase())).toList();

    final totalPages = (filtered.length / _pageSize).ceil();
    final actualTotalPages = totalPages == 0 ? 1 : totalPages;
    if (_currentPage > actualTotalPages) {
      _currentPage = actualTotalPages;
    }

    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize > filtered.length
        ? filtered.length
        : startIndex + _pageSize;
    final pageList = filtered.isEmpty ? <Map<String, dynamic>>[] : filtered.sublist(startIndex, endIndex);

    return SettingsSubScaffold(
      title: 'Manage User Attributes',
      body: _loading && _attrs.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (v) => setState(() {
                                    _query = v;
                                    _currentPage = 1;
                                  }),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: 'Search by name or value',
                                  ),
                                  style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateEditAttributeDialog(null),
                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                        label: Text('Create', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 45,
                                child: Text('S.No', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink4)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Name', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink4)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Value', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink4)),
                              ),
                              SizedBox(
                                width: 80,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('Actions', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink4)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.line),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadData,
                            color: AppColors.evaGreen,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: pageList.length,
                              itemBuilder: (context, index) {
                                final a = pageList[index];
                                final sNo = startIndex + index + 1;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: AppColors.line)),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 45,
                                        child: Text(
                                          '$sNo',
                                          style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _formatAttrText(a['key']),
                                          style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _formatAttrText(a['val']),
                                          style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            GestureDetector(
                                              onTap: () => _showCreateEditAttributeDialog(a),
                                              child: Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppColors.line),
                                                ),
                                                child: const Icon(Icons.edit_outlined, color: AppColors.evaGreenDeep, size: 15),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _confirmDeleteAttribute(a),
                                              child: Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppColors.line),
                                                ),
                                                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 15),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.line),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 4),
                                  for (int p = 1; p <= actualTotalPages; p++) ...[
                                    GestureDetector(
                                      onTap: () => setState(() => _currentPage = p),
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPage == p ? AppColors.evaGreen : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: _currentPage == p ? null : Border.all(color: AppColors.line),
                                        ),
                                        child: Text(
                                          '$p',
                                          style: AppText.poppins(
                                            size: 11,
                                            weight: FontWeight.w700,
                                            color: _currentPage == p ? Colors.white : AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  IconButton(
                                    onPressed: _currentPage < actualTotalPages ? () => setState(() => _currentPage++) : null,
                                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Row(
                                  children: [
                                    Text('$_pageSize / page', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink2)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink3, size: 14),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Login Activity
// ---------------------------------------------------------------------------

class LoginActivityScreen extends StatefulWidget {
  const LoginActivityScreen({super.key});

  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _activity = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AppScope.of(context).auth.fetchLoginActivity();
      if (mounted) {
        setState(() {
          _activity = list.take(10).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatWebDate(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) {
      return '22/07/2026, 03:18:07 pm';
    }
    final s = raw.toString();
    if (s.contains('/') && (s.contains('am') || s.contains('pm') || s.contains('AM') || s.contains('PM'))) {
      return s.toLowerCase();
    }
    final dt = DateTime.tryParse(s);
    if (dt != null) {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour12 = (dt.hour % 12 == 0) ? 12 : (dt.hour % 12);
      final hourStr = hour12.toString().padLeft(2, '0');
      final minStr = dt.minute.toString().padLeft(2, '0');
      final secStr = dt.second.toString().padLeft(2, '0');
      final ampm = (dt.hour >= 12) ? 'pm' : 'am';
      return '$day/$month/$year, $hourStr:$minStr:$secStr $ampm';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: 'Login Activity',
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.evaGreen,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                      boxShadow: AppColors.shadowSm,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login Activity',
                          style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 16),
                        if (_activity.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              child: Text(
                                'No login activity recorded',
                                style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3),
                              ),
                            ),
                          )
                        else
                          for (int i = 0; i < _activity.length; i++) ...[
                            Builder(builder: (context) {
                              final item = _activity[i];
                              final rawDate = (item['date'] ?? item['createdAt'] ?? item['loginTime'] ?? item['timestamp'] ?? '').toString();
                              final ip = (item['ip'] ?? item['ipAddress'] ?? item['ip_address'] ?? 'Unknown IP').toString();
                              final device = (item['device'] ?? item['deviceInfo'] ?? item['userAgent'] ?? 'Desktop, Unknown, Unknown').toString();
                              final isCurrent = i == 0 || (item['isCurrent'] == true || item['current'] == true);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Green AskEva Logo Emblem
                                      Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.evaGreen50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.evaGreen200),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'ASK',
                                              style: AppText.poppins(size: 7.5, weight: FontWeight.w900, color: AppColors.evaGreen),
                                            ),
                                            Text(
                                              'EVA',
                                              style: AppText.poppins(size: 7.5, weight: FontWeight.w900, color: AppColors.evaGreen),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _formatWebDate(rawDate),
                                                    style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2),
                                                  ),
                                                ),
                                                if (isCurrent) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.evaGreen50,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 5,
                                                          height: 5,
                                                          decoration: const BoxDecoration(
                                                            color: AppColors.evaGreen,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Active',
                                                          style: AppText.poppins(size: 10, weight: FontWeight.w700, color: AppColors.evaGreen),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'IP Address: $ip',
                                              style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Device: $device',
                                              style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (i < _activity.length - 1) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(height: 1, color: AppColors.line),
                                    ),
                                  ],
                                ],
                              );
                            }),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appearance (dark mode + density)
// ---------------------------------------------------------------------------

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});
  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _compact = false;

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: 'Appearance',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        AppCard(child: ValueListenableBuilder<bool>(
          valueListenable: kDarkMode,
          builder: (_, dark, _) => Row(children: [
            const TintIcon(icon: Icons.dark_mode_outlined),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dark mode', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink)),
              Text('Use a dark theme across the app', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
            ])),
            Switch.adaptive(value: dark, onChanged: (v) => kDarkMode.value = v, activeTrackColor: AppColors.evaGreen, activeThumbColor: Colors.white),
          ]),
        )),
        const SizedBox(height: 12),
        AppCard(child: Row(children: [
          const TintIcon(icon: Icons.density_medium_rounded),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Compact density', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink)),
            Text('Tighter spacing in lists', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
          ])),
          Switch.adaptive(value: _compact, onChanged: (v) => setState(() => _compact = v), activeTrackColor: AppColors.evaGreen, activeThumbColor: Colors.white),
        ])),
      ]),
    );
  }
}

class PermItem {
  final String key;
  final String label;
  final IconData icon;
  final bool isGroup;
  final List<({String moduleKey, String moduleLabel, List<String> permissions})> subModules;

  const PermItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.isGroup,
    required this.subModules,
  });
}

final List<PermItem> permItems = [
  PermItem(key: 'dashboard', label: 'Dashboard', icon: Icons.grid_view_rounded, isGroup: false, subModules: [
    (moduleKey: 'dashboard', moduleLabel: 'Dashboard', permissions: ['Full Access'])
  ]),
  PermItem(key: 'compose', label: 'Compose Message', icon: Icons.send_rounded, isGroup: false, subModules: [
    (moduleKey: 'compose', moduleLabel: 'Compose Message', permissions: ['Full Access', 'Only Schedule'])
  ]),
  PermItem(key: 'chat', label: 'Chat', icon: Icons.chat_bubble_outline_rounded, isGroup: false, subModules: [
    (moduleKey: 'chat', moduleLabel: 'Chat', permissions: [
      'Live chat - Global Access',
      'Live Chat - Self Assigned',
      'History - Global Access',
      'History - Self Assigned'
    ])
  ]),
  PermItem(key: 'contact-group', label: 'Contact', icon: Icons.people_alt_rounded, isGroup: true, subModules: [
    (moduleKey: 'contacts', moduleLabel: 'Contacts', permissions: ['Full access', 'View Only', 'Create and View']),
    (moduleKey: 'uiContacts', moduleLabel: 'UI Contacts', permissions: ['Full Access']),
    (moduleKey: 'optOut', moduleLabel: 'Opt-out', permissions: ['Full Access']),
  ]),
  PermItem(key: 'template', label: 'Manage Template', icon: Icons.description_rounded, isGroup: false, subModules: [
    (moduleKey: 'template', moduleLabel: 'Manage Template', permissions: ['Full Access', 'Creation and View Access', 'View Only Access'])
  ]),
  PermItem(key: 'report-group', label: 'Report', icon: Icons.bar_chart_rounded, isGroup: true, subModules: [
    (moduleKey: 'broadcastLogs', moduleLabel: 'Broadcast Logs', permissions: ['Full Access', 'View Only Access']),
    (moduleKey: 'apiLogs', moduleLabel: 'API Logs', permissions: ['Full Access', 'View Only Access']),
    (moduleKey: 'scheduleLogs', moduleLabel: 'Schedule Logs', permissions: ['Full Access', 'View Only Access']),
  ]),
  PermItem(key: 'flow', label: 'Flow', icon: Icons.fork_right_rounded, isGroup: false, subModules: [
    (moduleKey: 'flow', moduleLabel: 'Flow', permissions: ['Full Access'])
  ]),
  PermItem(key: 'chatbot', label: 'Chatbot Builder', icon: Icons.memory_rounded, isGroup: false, subModules: [
    (moduleKey: 'chatbot', moduleLabel: 'Chatbot Builder', permissions: ['Full Access', 'View Only Access'])
  ]),
  PermItem(key: 'aiAgent', label: 'AI Agent', icon: Icons.flash_on_rounded, isGroup: false, subModules: [
    (moduleKey: 'aiAgent', moduleLabel: 'AI Agent', permissions: ['Full Access', 'View Only Access'])
  ]),
  PermItem(key: 'catalog-group', label: 'Catalog', icon: Icons.menu_book_rounded, isGroup: true, subModules: [
    (moduleKey: 'catalogs', moduleLabel: 'Catalogs', permissions: ['Full Access']),
    (moduleKey: 'orders', moduleLabel: 'Orders', permissions: ['Full Access', 'View Only Access']),
    (moduleKey: 'coupons', moduleLabel: 'Coupons', permissions: ['Full Access', 'View Only Access', 'Create and View']),
  ]),
  PermItem(key: 'payment-group', label: 'Payment', icon: Icons.credit_card_rounded, isGroup: true, subModules: [
    (moduleKey: 'transactions', moduleLabel: 'Transactions', permissions: ['Full Access']),
    (moduleKey: 'paymentConfiguration', moduleLabel: 'Configuration', permissions: ['Full Access', 'View Only Access']),
    (moduleKey: 'paymentNotification', moduleLabel: 'Payment Notification', permissions: ['Full Access']),
  ]),
  PermItem(key: 'integration', label: 'Integration', icon: Icons.link_rounded, isGroup: false, subModules: [
    (moduleKey: 'integration', moduleLabel: 'Integration', permissions: ['Full Access'])
  ]),
  PermItem(key: 'leads-group', label: 'Leads', icon: Icons.track_changes_rounded, isGroup: true, subModules: [
    (moduleKey: 'leadsDashboard', moduleLabel: 'Dashboard', permissions: ['Full Access', 'Self Assigned']),
    (moduleKey: 'leadsMain', moduleLabel: 'Leads', permissions: ['Full Access', 'Self Assigned', 'View Only Access']),
    (moduleKey: 'leadsConfigurations', moduleLabel: 'Configurations', permissions: ['Full Access', 'View Only Access']),
  ]),
  PermItem(key: 'customer', label: 'Customer', icon: Icons.person_rounded, isGroup: false, subModules: [
    (moduleKey: 'customer', moduleLabel: 'Customer', permissions: ['Full Access', 'Self Assigned'])
  ]),
  PermItem(key: 'appointments-group', label: 'Appointments', icon: Icons.calendar_today_rounded, isGroup: true, subModules: [
    (moduleKey: 'appointmentsDashboard', moduleLabel: 'Dashboard', permissions: ['Full Access', 'Self Assigned']),
    (moduleKey: 'bookings', moduleLabel: 'Bookings', permissions: ['Full Access', 'Self Assigned', 'View Only Access']),
    (moduleKey: 'appointmentsConfiguration', moduleLabel: 'Configuration', permissions: ['Full Access', 'View Only Access']),
    (moduleKey: 'appointmentsPayments', moduleLabel: 'Payments', permissions: ['Full Access']),
  ]),
  PermItem(key: 'tickets-group', label: 'Tickets', icon: Icons.assignment_rounded, isGroup: true, subModules: [
    (moduleKey: 'ticketsDashboard', moduleLabel: 'Dashboard', permissions: ['Full Access', 'Self Assigned']),
    (moduleKey: 'ticketsMain', moduleLabel: 'Tickets', permissions: ['Full Access', 'Self Assigned', 'View Only Access']),
    (moduleKey: 'ticketSettings', moduleLabel: 'Ticket Settings', permissions: ['Full Access', 'View Only Access']),
  ]),
  PermItem(key: 'billing', label: 'Billing', icon: Icons.attach_money_rounded, isGroup: false, subModules: [
    (moduleKey: 'billing', moduleLabel: 'Billing', permissions: ['Full Access'])
  ]),
  PermItem(key: 'whatsappFlows', label: 'Whatsapp Flows', icon: Icons.alt_route_rounded, isGroup: false, subModules: [
    (moduleKey: 'whatsappFlows', moduleLabel: 'Whatsapp Flows', permissions: ['Full Access', 'Creation and View Access', 'View Only Access'])
  ]),
  PermItem(key: 'settings-group', label: 'Settings', icon: Icons.settings_rounded, isGroup: true, subModules: [
    (moduleKey: 'agentSetting', moduleLabel: 'Agent Settings', permissions: ['Full Access', 'View Only Access']),
    (moduleKey: 'apiSettings', moduleLabel: 'API Settings', permissions: ['Full Access', 'View Only Access']),
    (moduleKey: 'qrCode', moduleLabel: 'QR Code', permissions: ['Full Access', 'View Only Access']),
    (moduleKey: 'userAttributes', moduleLabel: 'User Attributes', permissions: ['Full Access', 'View Only Access']),
  ]),
];

