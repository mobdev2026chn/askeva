import 'package:flutter/material.dart';

import 'api/app_scope.dart';
import 'api/background_notification_service.dart';
import 'api/global_notification_poller.dart';
import 'api/local_notification_service.dart';
import 'api/session.dart';
import 'api/ticketing_repository.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'widgets/settings_extra.dart' show kDarkMode;
import 'widgets/dashboard_sheets.dart' show appToast;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.init();
  await BackgroundNotificationService.init();
  
  TicketingRepository.onApiCall = (msg, {isError = false}) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      appToast(ctx, msg, isError: isError, isSuccess: !isError);
    }
  };

  final session = Session();
  await session.load();
  final services = AppServices(session);
  GlobalNotificationPoller.start(services);
  runApp(AskEvaApp(services: services));
}

class AskEvaApp extends StatelessWidget {
  final AppServices services;
  const AskEvaApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: ValueListenableBuilder<bool>(
        valueListenable: kDarkMode,
        builder: (_, dark, _) => MaterialApp(
          navigatorKey: navigatorKey,
          title: 'AskEva',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
