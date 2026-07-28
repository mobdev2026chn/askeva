import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_scope.dart';
import '../api/session.dart';
import '../data/mock_data.dart';
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

  // Nav order mirrors the design's `.side-nav`.
  static const _order = [
    AppRoute.dashboard,
    AppRoute.compose,
    AppRoute.contacts,
    AppRoute.chats,
    AppRoute.catalog,
    AppRoute.leads,
    AppRoute.appointments,
    AppRoute.ticketing,
    AppRoute.reports,
    AppRoute.settings,
  ];

  // Getter for backward compatibility in case they are queried elsewhere
  int get _chatsBadge => kUnreadChatsCount.value;
  int get _leadsBadge => kTotalLeadsCount.value;

  bool _hasAccess(Session session, AppRoute route) {
    final role = (session.role ?? session.profile?['role'] ?? session.profile?['role_name'] ?? '').toString().trim().toLowerCase();
    
    // SuperAdmin / Admin / Owner have unrestricted access to all modules
    if (role == 'superadmin' || role == 'admin' || role == 'owner' || role.isEmpty) {
      return true;
    }

    final permsObj = session.profile?['permissions'] ?? session.profile?['modulePermissions'] ?? session.profile?['rolePermissions'];
    Map<String, dynamic> perms = {};
    if (permsObj is Map) {
      perms = permsObj.cast<String, dynamic>();
    }

    if (perms.isEmpty) {
      switch (route) {
        case AppRoute.dashboard:
        case AppRoute.chats:
        case AppRoute.contacts:
        case AppRoute.profile:
          return true;
        case AppRoute.leads:
          return role.contains('lead') || role.contains('agent') || role.contains('manager');
        case AppRoute.ticketing:
          return role.contains('ticket') || role.contains('agent') || role.contains('support');
        case AppRoute.appointments:
          return role.contains('appointment') || role.contains('agent');
        case AppRoute.catalog:
          return role.contains('catalog') || role.contains('order') || role.contains('agent');
        case AppRoute.compose:
          return role.contains('compose') || role.contains('agent');
        case AppRoute.reports:
          return role.contains('report') || role.contains('manager');
        case AppRoute.settings:
          return role.contains('admin') || role.contains('manager');
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

    switch (route) {
      case AppRoute.dashboard:
        return checkKey(['dashboard', 'leadsDashboard']);
      case AppRoute.compose:
        return checkKey(['compose', 'chat']);
      case AppRoute.contacts:
        return checkKey(['contacts', 'uiContacts', 'optOut']);
      case AppRoute.chats:
        return checkKey(['chat']);
      case AppRoute.catalog:
        return checkKey(['catalogs', 'orders', 'coupons']);
      case AppRoute.leads:
        return checkKey(['leadsMain', 'leadsDashboard', 'leads']);
      case AppRoute.appointments:
        return checkKey(['appointments', 'calendar']);
      case AppRoute.ticketing:
        return checkKey(['tickets', 'ticketing']);
      case AppRoute.reports:
        return checkKey(['broadcastLogs', 'apiLogs', 'scheduleLogs', 'reports']);
      case AppRoute.settings:
        return checkKey(['settings', 'agentRoles', 'roleAccess']);
      case AppRoute.profile:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    refreshUnreadChatsCount(context);
    final topPad = MediaQuery.of(context).padding.top;
    final session = AppScope.sessionOf(context);
    final profile = session.profile;
    final userName = profile?['name'] ?? profile?['username'] ?? session.username ?? MockData.userName;
    final imgUrlRaw = (profile?['profile_picture_url'] ?? profile?['whatsAppDisplayImage'])?.toString().trim();
    final isLogoUrl = imgUrlRaw != null && (imgUrlRaw.toLowerCase().contains('askeva') || imgUrlRaw.toLowerCase().contains('logo'));
    final imgUrl = (imgUrlRaw != null && imgUrlRaw.isNotEmpty && imgUrlRaw.startsWith('http') && !isLogoUrl) ? imgUrlRaw : null;
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imgUrl != null
                      ? Image.network(
                          imgUrl,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, _) => Container(
                            color: AppColors.evaGreenDeep,
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: AppText.poppins(size: 17, weight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.evaGreenDeep,
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: AppText.poppins(size: 17, weight: FontWeight.w800, color: Colors.white),
                          ),
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
                      AppRoute.leads => kTotalLeadsCount,
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
                  child: Text(route.label,
                      style: AppText.poppins(
                        size: 15,
                        weight: active ? FontWeight.w800 : FontWeight.w700,
                        color: active ? AppColors.accentDeep : AppColors.ink2,
                      )),
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
