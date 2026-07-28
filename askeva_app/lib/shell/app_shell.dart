import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

import '../api/app_scope.dart';
import '../theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/leads_screen.dart';
import '../screens/chats_screen.dart';
import '../screens/catalog_orders_screen.dart';
import '../screens/compose_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/appointments_screen.dart';
import '../screens/ticketing_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/login_screen.dart';
import 'app_nav.dart';
import 'app_sidebar.dart';
import '../widgets/dashboard_sheets.dart' show appToast, showLogoutDialog;

/// Root authenticated shell: a drawer + a body that swaps per route.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  AppRoute _route = AppRoute.dashboard;

  void _goTo(AppRoute r) {
    setState(() => _route = r);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _toast(String msg) {
    appToast(context, msg);
  }

  @override
  void initState() {
    super.initState();
    // App-open push alert: low wallet balance (fires once after login).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWalletBanner();
    });
  }

  void _showWalletBanner() {
    late OverlayEntry entry;
    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 320),
    );
    entry = OverlayEntry(
      builder: (ctx) {
        final topPad = MediaQuery.of(ctx).padding.top;
        return Positioned(
          top: topPad + 8,
          left: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, child) {
              final slide = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
              return FadeTransition(
                opacity: slide,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(slide),
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.evaGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, size: 22, color: AppColors.evaGreenDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Wallet balance is low. Recharge the wallet ASAP.',
                      style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      controller.reverse().then((_) => entry.remove());
                    },
                    child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(entry);
    controller.forward();
    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (controller.isCompleted) {
        controller.reverse().then((_) {
          if (entry.mounted) entry.remove();
        });
      }
    });
  }

  Future<void> _logout() async {
    final ok = await showLogoutDialog(context);
    if (ok != true || !mounted) return;
    final scope = AppScope.of(context);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.of(context).pop(); // close drawer
    await scope.session.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _body() {
    switch (_route) {
      case AppRoute.dashboard:
        return const DashboardScreen();
      case AppRoute.leads:
        return const LeadsScreen();
      case AppRoute.chats:
        return const ChatsScreen();
      case AppRoute.catalog:
        return const CatalogOrdersScreen();
      case AppRoute.compose:
        return const ComposeScreen();
      case AppRoute.reports:
        return const ReportsScreen();
      case AppRoute.appointments:
        return const AppointmentsScreen();
      case AppRoute.ticketing:
        return const TicketingScreen();
      case AppRoute.contacts:
        return const ContactsScreen();
      case AppRoute.profile:
        return const ProfileScreen();
      case AppRoute.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dashboard sheet shows a light status bar over the green header.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusLight,
      child: AppNav(
        current: _route,
        goTo: _goTo,
        openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        toast: _toast,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: AppSidebar(current: _route, onSelect: _goTo, onLogout: _logout),
          drawerEnableOpenDragGesture: false,
          body: _body(),
        ),
      ),
    );
  }
}
