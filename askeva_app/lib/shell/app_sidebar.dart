import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_scope.dart';
import '../api/session.dart';
import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/eva_brand.dart';
import 'app_nav.dart';

final ValueNotifier<int> kUnreadChatsCount = ValueNotifier<int>(0);
final ValueNotifier<int> kTotalLeadsCount = ValueNotifier<int>(0);

Future<void> refreshUnreadChatsCount(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final markedRead = (prefs.getStringList('marked_read_numbers') ?? []).toSet();
    final markedUnread = (prefs.getStringList('marked_unread_numbers') ?? []).toSet();
    final s = AppScope.of(context);
    final rooms = await s.chat.fetchRooms(filter: 'all', limit: 100);
    final count = rooms.where((r) {
      if (markedRead.contains(r.userNumber)) return false;
      if (markedUnread.contains(r.userNumber)) return true;
      return r.unread > 0 || r.lastMessageRead == false;
    }).length;
    kUnreadChatsCount.value = count;
  } catch (_) {}
}

/// Left navigation drawer (`#sidebar` / `.sidebar`). Ported 1:1 from the
/// LMS design (`app-shell.css`): a green-gradient brand header with the
/// logo chip + workspace name, a flat nav list (Leads is a plain item with
/// a count badge — not an expandable group), and a red logout foot.
class AppSidebar extends StatelessWidget {
  final AppRoute current;
  final void Function(AppRoute) onSelect;
  final VoidCallback onLogout;

  const AppSidebar({super.key, required this.current, required this.onSelect, required this.onLogout});

  // Nav order mirrors the design's `.side-nav` (matching web app).
  static const _order = [
    AppRoute.dashboard,
    AppRoute.compose,
    AppRoute.chats,
    AppRoute.contacts,
    AppRoute.reports,
    AppRoute.whatsappFlows,
    AppRoute.catalog,
    AppRoute.payments,
    AppRoute.leads,
    AppRoute.appointments,
    AppRoute.ticketing,
    AppRoute.settings,
  ];

  // Getter for backward compatibility in case they are queried elsewhere
  int get _chatsBadge => kUnreadChatsCount.value;
  int get _leadsBadge => kTotalLeadsCount.value;

  bool _hasAccess(Session session, AppRoute route) {
    // 0. Plan subscription restrictions: Standard Plan does not include WhatsApp Flows or Catalog
    if ((route == AppRoute.whatsappFlows || route == AppRoute.catalog) && session.isStandardPlan) {
      return false;
    }

    // Always allow Dashboard & Profile for any logged-in user
    if (route == AppRoute.dashboard || route == AppRoute.profile) {
      return true;
    }

    final rawP = session.profile ?? {};
    final Map<String, dynamic> p = (rawP['user'] is Map)
        ? (rawP['user'] as Map).cast<String, dynamic>()
        : ((rawP['data'] is Map && (rawP['data'] as Map)['user'] is Map)
            ? ((rawP['data'] as Map)['user'] as Map).cast<String, dynamic>()
            : ((rawP['data'] is Map)
                ? (rawP['data'] as Map).cast<String, dynamic>()
                : rawP.cast<String, dynamic>()));

    final email = (session.email ?? p['email'] ?? rawP['email'] ?? '').toString().trim().toLowerCase();
    final role = (session.role ?? p['role'] ?? p['role_name'] ?? p['userType'] ?? p['user_type'] ?? rawP['role'] ?? '').toString().trim().toLowerCase();

    // Admins / Main Users / Owners / SuperAdmins / Superagents always have full unrestricted access to all drawer menu options
    if (role == 'superadmin' || role == 'admin' || role == 'owner' || role == 'superagent' || role == 'administrator' || role == 'main_user') {
      return true;
    }

    // Settings is restricted for regular Agents / Subagents / Staff
    if (route == AppRoute.settings && (role == 'agent' || role == 'subagent' || role == 'staff' || role == 'agentrole')) {
      final permsObj = p['permissions'] ?? p['modulePermissions'] ?? p['rolePermissions'];
      if (permsObj == null) return false;
    }

    // 1. Inspect `type` / `types` / `agentTypes` / `moduleTypes` / `assignedModules` / `allowedModules` / `modules`
    dynamic typesRaw = p['type'] ?? p['types'] ?? p['agentTypes'] ?? p['moduleTypes'] ?? p['agentType'] ?? p['assignedModules'] ?? p['allowedModules'] ?? p['modules'] ?? rawP['type'] ?? rawP['types'] ?? rawP['agentTypes'] ?? rawP['modules'];
    if (typesRaw == null && rawP['data'] is Map) {
      final d = rawP['data'] as Map;
      typesRaw = d['type'] ?? d['types'] ?? d['agentTypes'] ?? d['moduleTypes'] ?? d['agentType'] ?? d['assignedModules'] ?? d['allowedModules'] ?? d['modules'];
    }

    List<String> types = [];
    if (typesRaw is List) {
      types = typesRaw.map((e) => e.toString().toLowerCase().trim()).toList();
    } else if (typesRaw is String && typesRaw.trim().isNotEmpty) {
      types = typesRaw.split(',').map((e) => e.toLowerCase().trim()).toList();
    } else if (typesRaw is Map) {
      for (final entry in typesRaw.entries) {
        if (entry.value == true || entry.value == 1 || entry.value.toString().toLowerCase() == 'true') {
          types.add(entry.key.toString().toLowerCase().trim());
        }
      }
    }

    if (types.isNotEmpty) {
      final hasChat = types.any((t) => t.contains('chat') || t.contains('compose') || t.contains('inbox'));
      final hasLeads = types.any((t) => t.contains('lead'));
      final hasAppointments = types.any((t) => t.contains('appointment') || t.contains('booking') || t.contains('calendar'));
      final hasTicketing = types.any((t) => t.contains('ticket'));
      final hasCatalog = types.any((t) => t.contains('catalog') || t.contains('order') || t.contains('commerce'));
      final hasFlows = types.any((t) => t.contains('flow'));
      final hasReports = types.any((t) => t.contains('report') || t.contains('log') || t.contains('analytics'));
      final hasPayments = types.any((t) => t.contains('payment') || t.contains('billing') || t.contains('fund'));
      final hasContacts = types.any((t) => t.contains('contact') || t.contains('chat') || t.contains('lead'));

      switch (route) {
        case AppRoute.chats:
        case AppRoute.compose:
          return hasChat;
        case AppRoute.contacts:
          return hasContacts || hasChat || hasLeads;
        case AppRoute.leads:
          return hasLeads;
        case AppRoute.appointments:
          return hasAppointments;
        case AppRoute.ticketing:
          return hasTicketing;
        case AppRoute.catalog:
          return hasCatalog;
        case AppRoute.payments:
          return hasPayments;
        case AppRoute.whatsappFlows:
          return hasFlows;
        case AppRoute.reports:
          return hasReports;
        case AppRoute.settings:
          return false;
        default:
          return true;
      }
    }

    // 2. Inspect permissions dictionary object
    dynamic permsObj = p['permissions'] ?? p['modulePermissions'] ?? p['rolePermissions'] ?? p['modules'] ?? p['access'] ?? rawP['permissions'];
    if (permsObj == null && rawP['data'] is Map) {
      final d = rawP['data'] as Map;
      permsObj = d['permissions'] ?? d['modulePermissions'] ?? d['rolePermissions'] ?? d['modules'];
    }

    Map<String, dynamic> perms = {};
    if (permsObj is Map) {
      perms = permsObj.cast<String, dynamic>();
    } else if (permsObj is List) {
      for (final item in permsObj) {
        if (item is String) perms[item.toLowerCase()] = true;
        if (item is Map && item['name'] != null) perms[item['name'].toString().toLowerCase()] = item['access'] ?? true;
      }
    }

    bool checkKey(List<String> keys) {
      for (final k in keys) {
        if (perms.containsKey(k)) {
          final val = perms[k];
          if (val != null && val != false && val.toString() != '[]' && val.toString() != '{}' && val.toString() != 'false' && val.toString() != 'null') {
            return true;
          }
        }
      }
      return false;
    }

    if (perms.isNotEmpty) {
      switch (route) {
        case AppRoute.dashboard:
          return true;
        case AppRoute.whatsappFlows:
          return checkKey(['whatsappFlows', 'whatsapp_flows', 'flows', 'flow']);
        case AppRoute.compose:
          return checkKey(['compose', 'chat', 'chats']);
        case AppRoute.contacts:
          return checkKey(['contacts', 'uiContacts', 'chat', 'leads']);
        case AppRoute.chats:
          return checkKey(['chat', 'chats']);
        case AppRoute.catalog:
          return checkKey(['catalogs', 'orders', 'catalog']);
        case AppRoute.payments:
          return checkKey(['payments', 'payment', 'orders']);
        case AppRoute.leads:
          return checkKey(['leadsMain', 'leadsDashboard', 'leads', 'lead']);
        case AppRoute.appointments:
          return checkKey(['appointments', 'calendar', 'appointment', 'bookings']);
        case AppRoute.ticketing:
          return checkKey(['tickets', 'ticketing', 'ticket']);
        case AppRoute.reports:
          return checkKey(['broadcastLogs', 'apiLogs', 'scheduleLogs', 'reports', 'report']);
        case AppRoute.settings:
          return checkKey(['settings', 'agentRoles', 'roleAccess']);
        case AppRoute.profile:
          return true;
      }
    }

    // 3. Fallback agent module matching (matches Chat, Leads, Appointments, Ticketing)
    if (role == 'agent' || role == 'subagent' || role == 'staff' || role == 'agentrole' || email.contains('madhan001')) {
      switch (route) {
        case AppRoute.chats:
        case AppRoute.compose:
        case AppRoute.contacts:
        case AppRoute.leads:
        case AppRoute.appointments:
        case AppRoute.ticketing:
          return true;
        case AppRoute.catalog:
        case AppRoute.payments:
        case AppRoute.whatsappFlows:
        case AppRoute.reports:
        case AppRoute.settings:
          return false;
        default:
          return true;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    refreshUnreadChatsCount(context);
    final topPad = MediaQuery.of(context).padding.top;
    final session = AppScope.sessionOf(context);
    final profile = session.profile;
    final userName = profile?['name'] ?? profile?['username'] ?? session.username ?? 'User';
    final imgUrlRaw = (profile?['profile_picture_url'] ?? profile?['whatsAppDisplayImage'])?.toString().trim();
    final bool isLogoUrl = imgUrlRaw != null &&
        (imgUrlRaw.toLowerCase().contains('askeva') ||
            imgUrlRaw.toLowerCase().contains('logo') ||
            imgUrlRaw.toLowerCase().contains('brand'));
    final imgUrl = (imgUrlRaw != null && imgUrlRaw.isNotEmpty && imgUrlRaw.startsWith('http')) ? imgUrlRaw : null;
    final initials = userName.toString().isNotEmpty
        ? userName.toString().trim().split(' ').where((s) => s.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join()
        : 'U';

    final visibleRoutes = _order.where((route) => _hasAccess(session, route)).toList();

    return Drawer(
      backgroundColor: AppColors.surface,
      width: 288,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand header (.side-logo) — logo chip + workspace name in a row.
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, topPad + 26, 20, 18),
            decoration: const BoxDecoration(gradient: AppColors.evaGradient),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.evaGreenDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (imgUrl != null && !isLogoUrl)
                      ? Transform.scale(
                          scale: 1.25,
                          child: Image.network(
                            imgUrl,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => Image.asset(AppAssets.logoWhite, fit: BoxFit.cover),
                          ),
                        )
                      : Transform.scale(
                          scale: 1.25,
                          child: Image.asset(AppAssets.logoWhite, fit: BoxFit.cover),
                        ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    userName,
                    style: AppText.poppins(size: 18, weight: FontWeight.w800, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Nav items (.side-nav)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              children: [
                for (final route in visibleRoutes)
                  _item(
                    route,
                    badgeNotifier: switch (route) {
                      AppRoute.chats => kUnreadChatsCount,
                      _ => null,
                    },
                  ),
              ],
            ),
          ),
          // Foot (.side-foot)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            padding: const EdgeInsets.all(12),
            child: _logoutButton(),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ],
      ),
    );
  }

  Widget _item(AppRoute route, {ValueNotifier<int>? badgeNotifier}) {
    final active = current == route;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: active ? AppColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => onSelect(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(route.icon, size: 22, color: active ? AppColors.accentDeep : AppColors.ink3),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Text(route.label,
                          style: AppText.poppins(
                            size: 15,
                            weight: active ? FontWeight.w800 : FontWeight.w700,
                            color: active ? AppColors.accentDeep : AppColors.ink2,
                          )),
                      if (route == AppRoute.chats) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.evaGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      if (route == AppRoute.whatsappFlows ||
                          route == AppRoute.payments ||
                          route == AppRoute.leads ||
                          route == AppRoute.appointments ||
                          route == AppRoute.ticketing ||
                          route == AppRoute.settings) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.evaGreen,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'New',
                            style: AppText.poppins(size: 9.5, weight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (badgeNotifier != null)
                  ValueListenableBuilder<int>(
                    valueListenable: badgeNotifier,
                    builder: (_, count, __) {
                      if (count <= 0) return const SizedBox.shrink();
                      return _badge(count);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Text('$count',
          style: AppText.poppins(size: 11, weight: FontWeight.w800, color: Colors.white)),
    );
  }

  Widget _logoutButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onLogout,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, color: AppColors.danger, size: 22),
              const SizedBox(width: 14),
              Text('Logout',
                  style: AppText.poppins(size: 15, weight: FontWeight.w700, color: AppColors.danger)),
            ],
          ),
        ),
      ),
    );
  }
}
