import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:askeva_app/api/app_scope.dart';
import 'package:askeva_app/api/session.dart';
import 'package:askeva_app/theme/app_theme.dart';
import 'package:askeva_app/widgets/dashboard_sheets.dart';

Widget _host(Widget child) {
  final services = AppServices(Session());
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light.copyWith(
      textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Poppins'),
    ),
    home: AppScope(
      services: services,
      child: child,
    ),
  );
}

void main() {
  testWidgets('Check NotificationsScreen renders without exception', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 720));
    await t.pumpWidget(_host(const NotificationsScreen()));
    await t.pump(); // trigger loading/initState

    final ex = t.takeException();
    expect(ex, isNull, reason: 'NotificationsScreen threw: $ex');

    // Should find the screen title
    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('See all updates at a glance'), findsOneWidget);
  });
}
