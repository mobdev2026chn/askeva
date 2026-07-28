import 'package:flutter/material.dart';

class LeadTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabController;
  final List<Widget> tabs;

  const LeadTabBar({
    super.key,
    required this.tabController,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        indicatorColor: Colors.green,
        labelColor: Colors.green,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: tabs,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}
