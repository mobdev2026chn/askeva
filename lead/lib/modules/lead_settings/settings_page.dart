import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/drawer_menu_icon.dart';
import '../settings/agents/agents_management_page.dart';
import './lead_configuration_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: const DrawerMenuIcon(),
        foregroundColor: Colors.white,
        title: const Text('Settings'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
          ListTile(
            leading: Icon(Icons.people, color: AppColors.primary),
            title: const Text('Agents'),
            subtitle: const Text('Manage agents and roles'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AgentsManagementPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.leaderboard, color: AppColors.primary),
            title: const Text('Lead Configuration'),
            subtitle: const Text('Manage webhook, quick replies, and more'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeadConfigurationPage(),
                ),
              );
            },
          ),
          const Divider(),
          // Add other settings here...
        ],
        ),
      ),
    );
  }
}
