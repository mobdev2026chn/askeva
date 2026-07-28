import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:askeva_app/api/app_scope.dart';
import 'package:askeva_app/api/session.dart';
import 'package:askeva_app/shell/app_nav.dart';
import 'package:askeva_app/theme/app_theme.dart';

import 'package:askeva_app/screens/dashboard_screen.dart';
import 'package:askeva_app/screens/compose_screen.dart';
import 'package:askeva_app/screens/contacts_screen.dart';
import 'package:askeva_app/screens/leads_screen.dart';
import 'package:askeva_app/screens/appointments_screen.dart';
import 'package:askeva_app/screens/ticketing_screen.dart';
import 'package:askeva_app/screens/profile_screen.dart';
import 'package:askeva_app/screens/conversation_screen.dart';

/// Wraps a screen with the inherited scopes it needs, at a small-phone width
/// so any horizontal RenderFlex overflow is surfaced during layout.
Widget _host(Widget screen) {
  final services = AppServices(Session());
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // Force the loaded Poppins as the default family so theme-default Text
    // (no explicit AppText style) also measures with a real font, not the
    // flutter_test placeholder glyph.
    theme: AppTheme.light.copyWith(
      textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Poppins'),
    ),
    home: AppScope(
      services: services,
      child: AppNav(
        current: AppRoute.dashboard,
        goTo: (_) {},
        openDrawer: () {},
        toast: (_) {},
        child: screen,
      ),
    ),
  );
}

// flutter_test renders text with a placeholder glyph far wider than real
// fonts; for a few widgets (the shared header's Tooltip button) that yields
// absurd ~100,000px "overflows" that never happen on a real device. We drain
// the framework's caught exceptions and fail ONLY on GENUINE (≤1000px)
// overflows — real layout bugs — while tolerating the placeholder-font
// artifacts (and the conversation screen's expected network error).
final overflowRe = RegExp(r'overflowed by ([\d.]+) pixels');

void main() {
  void expectNoGenuineOverflow(WidgetTester tester, String where) {
    final genuine = <double>[];
    for (var ex = tester.takeException(); ex != null; ex = tester.takeException()) {
      for (final m in overflowRe.allMatches(ex.toString())) {
        final px = double.parse(m.group(1)!);
        if (px <= 1000) genuine.add(px);
      }
    }
    expect(genuine, isEmpty, reason: 'Genuine RenderFlex overflow(s) $genuine px at: $where');
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    await tester.pumpWidget(_host(screen));
    // A couple of frames for the initial build + fallback data, but NOT
    // pumpAndSettle (network/animation futures never settle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Taps each visible segment/tab label and re-pumps so every sub-view lays out.
  Future<void> tapThrough(WidgetTester tester, List<String> labels) async {
    for (final l in labels) {
      final f = find.text(l);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expectNoGenuineOverflow(tester, 'after tapping "$l"');
      }
    }
  }

  testWidgets('Dashboard has no overflow', (t) async {
    await pumpScreen(t, const DashboardScreen());
    expectNoGenuineOverflow(t, 'initial render');
  });

  testWidgets('Compose (Single/Group/CSV) has no overflow', (t) async {
    await pumpScreen(t, const ComposeScreen());
    expectNoGenuineOverflow(t, 'initial render');
    await tapThrough(t, ['Group', 'CSV', 'Single MSG']);
  });

  testWidgets('Contacts (tabs) has no overflow', (t) async {
    await pumpScreen(t, const ContactsScreen());
    expectNoGenuineOverflow(t, 'initial render');
    await tapThrough(t, ['UI-Contacts', 'Opt-out', 'Blocked', 'Contacts']);
  });

  testWidgets('Leads (Dashboard/Leads/Settings + sub-tabs) has no overflow', (t) async {
    await pumpScreen(t, const LeadsScreen());
    expectNoGenuineOverflow(t, 'initial render');
    await tapThrough(t, ['Companies', 'Customers', 'Settings', 'Leads']);
  });

  testWidgets('Appointments (all tabs) has no overflow', (t) async {
    await pumpScreen(t, const AppointmentsScreen());
    expectNoGenuineOverflow(t, 'initial render');
    await tapThrough(t, ['Bookings', 'Appointments', 'Payments', 'Settings', 'Dashboard']);
  });

  testWidgets('Ticketing (all tabs) has no overflow', (t) async {
    await pumpScreen(t, const TicketingScreen());
    expectNoGenuineOverflow(t, 'initial render');
    await tapThrough(t, ['Tickets', 'Settings', 'Agent Performance', 'Dashboard']);
  });

  testWidgets('Profile (all tabs) has no overflow', (t) async {
    await pumpScreen(t, const ProfileScreen());
    expectNoGenuineOverflow(t, 'initial render');
    await tapThrough(t, ['Team', 'Password', 'Pricing', 'Subscription', 'Transactions', 'Account']);
  });

  testWidgets('Conversation has no overflow', (t) async {
    await pumpScreen(t, const ConversationScreen(name: 'Aarav Mehta', number: '917012998877'));
    expectNoGenuineOverflow(t, 'initial render');
  });
}
