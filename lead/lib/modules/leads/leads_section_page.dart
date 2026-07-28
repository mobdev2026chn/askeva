// When user taps "Leads" in the bottom navbar, this page is shown.
// Navigation: Dashboard, Leads, Lead Settings via right drawer (no top tabs).

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/drawer_menu_icon.dart';
import '../dashboard/leads_dashboard_page.dart';
import '../lead_settings/lead_configuration_page.dart';
import 'leads_main_tab_page.dart';

enum _LeadsSection { dashboard, leads, settings }

class LeadsSectionPage extends StatefulWidget {
  final Widget? drawer;
  final String? email;
  final String? name;

  const LeadsSectionPage({
    super.key,
    this.drawer,
    this.email,
    this.name,
  });

  @override
  State<LeadsSectionPage> createState() => _LeadsSectionPageState();
}

class _LeadsSectionPageState extends State<LeadsSectionPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  _LeadsSection _selected = _LeadsSection.leads;

  void _openRightDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _select(_LeadsSection section) {
    setState(() => _selected = section);
    Navigator.of(context).pop();
  }

  static const _sections = [
    (_LeadsSection.dashboard, Icons.dashboard_rounded, 'Dashboard'),
    (_LeadsSection.leads, Icons.people_rounded, 'Leads'),
    (_LeadsSection.settings, Icons.settings_rounded, 'Lead Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveDrawer = widget.drawer ?? AppDrawer(email: widget.email, name: widget.name);

    return Scaffold(
      key: _scaffoldKey,
      drawer: effectiveDrawer,
      endDrawer: Drawer(
        child: Container(
          color: cs.surface,
          child: SafeArea(
            left: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Leads',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    children: _sections.map((item) {
                      final section = item.$1;
                      final icon = item.$2;
                      final title = item.$3;
                      final isSelected = _selected == section;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            leading: Icon(
                              icon,
                              size: 22,
                              color: isSelected ? AppColors.primary : cs.onSurfaceVariant,
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary)
                                : null,
                            onTap: () => _select(section),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      appBar: AppBar(
        leading: const DrawerMenuIcon(),
        title: Text(
          _selected == _LeadsSection.dashboard
              ? 'Leads Dashboard'
              : _selected == _LeadsSection.leads
                  ? 'Leads'
                  : 'Lead Settings',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openRightDrawer,
            icon: const Icon(Icons.people_rounded, size: 24),
            tooltip: 'Dashboard, Leads, Settings',
          ),
        ],
      ),
      body: _selected == _LeadsSection.dashboard
          ? const LeadsDashboardPage()
          : _selected == _LeadsSection.leads
              ? LeadsMainTabPage(drawer: effectiveDrawer)
              : LeadConfigurationPage(
                  email: widget.email,
                  name: widget.name,
                  showAppBar: false,
                  showOnlyQuickReply: true,
                ),
    );
  }
}
