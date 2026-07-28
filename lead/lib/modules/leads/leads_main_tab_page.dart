// PAGE: LeadsMainTabPage
// FUNCTIONALITY: This page provides a tabbed interface for managing Leads and Companies.
// It is used as the content of the "Leads" tab in LeadsSectionPage, so it does NOT
// use its own Scaffold/AppBar to avoid a duplicate app bar (parent already has one).

import 'package:flutter/material.dart';
import 'leads_page.dart';
import 'company_list_page.dart';
import '../../theme/app_colors.dart';

class LeadsMainTabPage extends StatelessWidget {
  final Widget? drawer;
  const LeadsMainTabPage({super.key, this.drawer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: cs.surface,
            child: TabBar(
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: cs.onSurface,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 16),
              tabs: const [
                Tab(text: 'Leads'),
                Tab(text: 'Companies'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [LeadsPage(), CompanyListPage()]),
          ),
        ],
      ),
    );
  }
}
