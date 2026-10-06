import 'package:flutter/material.dart';

enum AppRoute { dashboard, whatsappFlows, leads, chats, catalog, payments, compose, reports, appointments, ticketing, contacts, profile, settings }

extension AppRouteX on AppRoute {
  String get label => switch (this) {
        AppRoute.dashboard => 'Dashboard',
        AppRoute.whatsappFlows => 'WhatsApp Flows',
        AppRoute.leads => 'Leads',
        AppRoute.chats => 'Chats',
        AppRoute.catalog => 'Catalog',
        AppRoute.payments => 'Payments',
        AppRoute.compose => 'Compose Message',
        AppRoute.reports => 'Reports',
        AppRoute.appointments => 'Appointments',
        AppRoute.ticketing => 'Ticketing',
        AppRoute.contacts => 'Contacts',
        AppRoute.profile => 'Profile',
        AppRoute.settings => 'Settings',
      };

  IconData get icon => switch (this) {
        AppRoute.dashboard => Icons.grid_view_rounded,
        AppRoute.whatsappFlows => Icons.alt_route_rounded,
        AppRoute.leads => Icons.people_outline_rounded,
        AppRoute.chats => Icons.forum_outlined,
        AppRoute.catalog => Icons.shopping_bag_outlined,
        AppRoute.payments => Icons.payments_outlined,
        AppRoute.compose => Icons.near_me_outlined,
        AppRoute.reports => Icons.bar_chart_rounded,
        AppRoute.appointments => Icons.calendar_today_outlined,
        AppRoute.ticketing => Icons.confirmation_number_outlined,
        AppRoute.contacts => Icons.badge_outlined,
        AppRoute.profile => Icons.person_outline_rounded,
        AppRoute.settings => Icons.settings_outlined,
      };
}


/// Lightweight nav controller exposed to all screens via InheritedWidget.
class AppNav extends InheritedWidget {
  final AppRoute current;
  final void Function(AppRoute) goTo;
  final VoidCallback openDrawer;
  final void Function(String) toast;

  const AppNav({
    super.key,
    required this.current,
    required this.goTo,
    required this.openDrawer,
    required this.toast,
    required super.child,
  });

  static AppNav? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppNav>();
  }

  static AppNav of(BuildContext context) {
    final nav = context.dependOnInheritedWidgetOfExactType<AppNav>();
    assert(nav != null, 'AppNav not found in context');
    return nav!;
  }

  @override
  bool updateShouldNotify(AppNav oldWidget) => oldWidget.current != current;
}

final ValueNotifier<String?> kSendQrCodeTarget = ValueNotifier<String?>(null);
final ValueNotifier<int> kReportsSelectedTab = ValueNotifier<int>(0);

