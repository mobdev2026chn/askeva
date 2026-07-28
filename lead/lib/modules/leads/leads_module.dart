import 'package:flutter/material.dart';
import 'package:askeva/modules/leads/leads_page.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/drawer_menu_icon.dart';
import 'company_list_page.dart';

class LeadsModule extends StatelessWidget {
  const LeadsModule({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          leading: const DrawerMenuIcon(),
          title: const Text('Leads'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Leads'),
              Tab(text: 'Companies'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Refresh pressed'))),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export URL: /api/leads/export')),
              ),
              icon: const Icon(Icons.upload_file),
            ),
          ],
        ),
        body: const TabBarView(children: [LeadsTab(), CompanyListPage()]),
      ),
    );
  }
}

class LeadsTab extends StatelessWidget {
  const LeadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const LeadsPage();
  }
}
