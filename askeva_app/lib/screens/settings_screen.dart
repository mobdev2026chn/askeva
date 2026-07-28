import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_scope.dart';
import '../shell/app_nav.dart';
import '../screens/about_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/settings_extra.dart';
import '../widgets/dashboard_sheets.dart'; // For NotificationsScreen

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _agentCount = 14;
  int _attrCount = 25;
  bool _twofaEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  void _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final agents = await AppScope.of(context).agents.fetchAgents();
      final attrs = await AppScope.of(context).agents.fetchUserAttributes();
      final email = AppScope.of(context).session.email ?? 'global';
      final prefs = await SharedPreferences.getInstance();
      final twofa = prefs.getBool('twofa_enabled_$email') ?? false;
      if (mounted) {
        setState(() {
          _agentCount = agents.length;
          _attrCount = attrs.length;
          _twofaEnabled = twofa;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    return GreenHeaderScaffold(
      title: 'Settings',
      onMenu: nav.openDrawer,
      sheet: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          const SectionRow(title: 'Workspace'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingsRow(
                  icon: Icons.people_outline_rounded,
                  title: 'Agents',
                  subtitle: 'Manage agents & role ...',
                  first: true,
                  trailingBadge: _countBadge('$_agentCount agents'),
                  onTap: () => _push(const AgentsRolesScreen()),
                ),
                _settingsRow(
                  icon: Icons.qr_code_2_rounded,
                  title: 'QR Code',
                  subtitle: 'Generate chat QR codes',
                  onTap: () => _push(QrCodeScreen(nav: nav)),
                ),
                _settingsRow(
                  icon: Icons.playlist_add_check_rounded,
                  title: 'User Attributes',
                  subtitle: 'Manage template variables',
                  trailingBadge: _countBadge('$_attrCount'),
                  onTap: () => _push(const UserAttributesScreen()),
                ),
              ],
            ),
          ),
          const SectionRow(title: 'Security & Preferences'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingsRow(
                  icon: Icons.shield_outlined,
                  title: 'Securities',
                  subtitle: 'Two-factor authe...',
                  first: true,
                  trailingBadge: _statusBadge(_twofaEnabled),
                  onTap: () => _push(const SecurityScreen()),
                ),
                _settingsRow(
                  icon: Icons.access_time_rounded,
                  title: 'Login Activity',
                  subtitle: 'Last login 12 Jan, 2:31 pm',
                  onTap: () => _push(const LoginActivityScreen()),
                ),
                _settingsRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Push, email & sounds',
                  onTap: () => _push(const NotificationSettingsScreen()),
                ),
                _settingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: 'Version, Meta partner & terms',
                  onTap: () => _push(const AboutScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          
          // Logout Card matching mockup exactly
          AppCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () async {
                final ok = await showLogoutDialog(context);
                if (ok == true && context.mounted) {
                  await AppScope.of(context).session.clear();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Logout',
                      style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'AskEva - v2.4.0',
              style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppText.poppins(size: 11, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
      ),
    );
  }

  Widget _statusBadge(bool enabled) {
    final bgColor = enabled ? const Color(0xFFE8F5E9) : const Color(0xFFFFFDE7);
    final dotColor = enabled ? AppColors.evaGreenDeep : const Color(0xFFFBC02D);
    final textColor = enabled ? AppColors.evaGreenDeep : const Color(0xFFF57F17);
    final text = enabled ? 'Enabled' : 'Not Enabled';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppText.poppins(size: 11, weight: FontWeight.w800, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailingBadge,
    required VoidCallback onTap,
    bool first = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: first ? null : const Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.evaGreenDeep, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailingBadge != null) ...[
              trailingBadge,
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink4, size: 20),
          ],
        ),
      ),
    );
  }
}
