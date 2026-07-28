import 'package:flutter/material.dart';
import 'package:askeva/modules/settings/agents/tabs/agents_list_tab.dart';
import 'package:askeva/modules/settings/agents/tabs/roles_list_tab.dart';
import 'package:askeva/widgets/app_drawer.dart';
import 'package:askeva/widgets/drawer_menu_icon.dart';

class AgentsManagementPage extends StatefulWidget {
  const AgentsManagementPage({super.key});

  @override
  State<AgentsManagementPage> createState() => _AgentsManagementPageState();
}

class _AgentsManagementPageState extends State<AgentsManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuIcon(),
        foregroundColor: Colors.white,
        title: const Text('Agents Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Agents'),
            Tab(text: 'Role Configuration'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: const [AgentsListTab(), RolesListTab()],
      ),
    );
  }
}
