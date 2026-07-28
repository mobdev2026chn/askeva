
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/drawer_menu_icon.dart';

class LeadSettingsPage extends StatelessWidget {
  const LeadSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuIcon(),
        title: const Text('Lead Settings'),
      ),
      drawer: const AppDrawer(),
      body: Center(
        child: Text(
          'Lead Settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
