import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api_config.dart';
import 'local_notification_service.dart';

const String kBackgroundNotificationTaskKey = 'askeva_background_notification_task';
const String kBackgroundFetchNotificationsName = 'askeva_fetch_notifications';
const String kOneOffNotificationTaskKey = 'askeva_oneoff_notification_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await BackgroundNotificationService.pollUnreadNotificationsInBackground();
    } catch (e) {
      debugPrint('[BackgroundNotificationService] Workmanager task error: $e');
    }
    return Future.value(true);
  });
}

class BackgroundNotificationService with WidgetsBindingObserver {
  static bool _initialized = false;
  static final BackgroundNotificationService instance = BackgroundNotificationService._();
  BackgroundNotificationService._();

  /// Initialize WorkManager and register periodic background task
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );

      await Workmanager().registerPeriodicTask(
        kBackgroundNotificationTaskKey,
        kBackgroundFetchNotificationsName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );

      WidgetsBinding.instance.addObserver(instance);
      _initialized = true;
    } catch (e) {
      debugPrint('[BackgroundNotificationService] init error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Schedule an immediate one-off background check when app is minimized or closed
      scheduleOneOffCheck();
    }
  }

  /// Schedule a one-off task to run right after app is minimized/closed
  static Future<void> scheduleOneOffCheck() async {
    try {
      await Workmanager().registerOneOffTask(
        '${kOneOffNotificationTaskKey}_${DateTime.now().millisecondsSinceEpoch}',
        kBackgroundFetchNotificationsName,
        initialDelay: const Duration(seconds: 10),
        existingWorkPolicy: ExistingWorkPolicy.append,
      );
    } catch (e) {
      debugPrint('[BackgroundNotificationService] Schedule one-off check error: $e');
    }
  }

  /// Task executed in background isolate when app is closed or minimized
  static Future<void> pollUnreadNotificationsInBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return;

    final email = prefs.getString('auth_email') ?? 'global';
    final rawNotified = prefs.getStringList('notified_bg_ids') ?? [];
    final notifiedSet = Set<String>.from(rawNotified);

    // List of endpoints to try: primary active host first, followed by fallback host
    final primaryHost = '${ApiConfig.apiV1}/users/notifications?isRead=false&limit=20';
    final fallbackHost = (ApiConfig.env == AppEnv.production)
        ? 'https://api.askeva.net/v1/users/notifications?isRead=false&limit=20'
        : 'https://apiv2.askeva.io/v1/users/notifications?isRead=false&limit=20';

    final endpoints = [primaryHost, fallbackHost];

    for (final url in endpoints) {
      try {
        final uri = Uri.parse(url);
        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode != 200) continue;

        final dynamic data = jsonDecode(response.body);
        List items = [];
        if (data is List) {
          items = data;
        } else if (data is Map && data['data'] is List) {
          items = data['data'];
        }

        bool updatedNotified = false;
        for (final item in items) {
          if (item is! Map) continue;
          final id = item['id']?.toString() ?? item['_id']?.toString();
          if (id == null || id.isEmpty) continue;

          if (!notifiedSet.contains(id)) {
            notifiedSet.add(id);
            updatedNotified = true;

            final title = (item['title'] ?? item['subject'] ?? 'Lead Notification').toString().trim();
            final body = (item['body'] ?? item['message'] ?? 'New notification received').toString().trim();

            await LocalNotificationService.showNotification(
              title: title.isNotEmpty ? title : 'Lead Notification',
              body: body.isNotEmpty ? body : 'New notification received',
              email: email,
            );
          }
        }

        if (updatedNotified) {
          await prefs.setStringList('notified_bg_ids', notifiedSet.toList());
        }

        // Successfully processed from endpoint
        break;
      } catch (e) {
        debugPrint('[BackgroundNotificationService] Poll error on $url: $e');
      }
    }
  }
}
