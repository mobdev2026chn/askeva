import 'package:flutter_test/flutter_test.dart';

import 'package:askeva_app/api/app_scope.dart';
import 'package:askeva_app/api/session.dart';
import 'package:askeva_app/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    final session = Session();
    final services = AppServices(session);
    await tester.pumpWidget(AskEvaApp(services: services));
    expect(find.byType(AskEvaApp), findsOneWidget);
  });
}
