import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:askeva_app/api/app_scope.dart';
import 'package:askeva_app/api/session.dart';
import 'package:askeva_app/theme/app_theme.dart';
import 'package:askeva_app/widgets/profile_sheets.dart';

Widget _host(void Function(BuildContext) onTap) {
  final services = AppServices(Session());
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light.copyWith(
      textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Poppins'),
    ),
    home: AppScope(
      services: services,
      child: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(onPressed: () => onTap(ctx), child: const Text('open')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Check other plans sheet renders for an ecommerce renewal', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 720));
    await t.pumpWidget(_host((ctx) => showPlansSheet(
          ctx,
          currentPlan: 'ecommerce',
          validity: 'unlimited',
          startDate: '2026-06-25',
          toast: (_) {},
          isRenewal: true,
        )));
    await t.tap(find.text('open'));
    await t.pump(); // start the sheet route
    await t.pump(const Duration(milliseconds: 350)); // let it animate in

    // Surface any render exception thrown while building the sheet.
    final ex = t.takeException();
    expect(ex, isNull, reason: 'sheet threw: $ex');

    expect(find.text('Renew Your Plan'), findsOneWidget);
    expect(find.text('Ecommerce'), findsWidgets); // card title + table header
    expect(find.text('Pay with Wallet'), findsOneWidget);
    // Feature table row + a price for the 3-month default term.
    expect(find.text('Broadcast & Analytics'), findsOneWidget);
    expect(find.textContaining('8,100'), findsWidgets);
  });
}
