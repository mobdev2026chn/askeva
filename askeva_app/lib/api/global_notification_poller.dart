import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dashboard_sheets.dart' show kNotificationUnreadCount;
import 'app_scope.dart';
import 'local_notification_service.dart';

class GlobalNotificationPoller {
  static Timer? _timer;
  static final Set<String> _notifiedIds = {};
  static bool _running = false;
  static bool _isFirstRun = true;

  static Future<void> start(AppServices services) async {
    if (_running) return;
    _running = true;
    _isFirstRun = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('notified_bg_ids') ?? [];
      _notifiedIds.addAll(list);
    } catch (_) {}

    await _poll(services);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll(services));
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _isFirstRun = true;
  }

  static Future<void> _poll(AppServices services) async {
    if (!services.session.isAuthenticated) return;
    try {
      final unreadList = await services.notifications.fetchNotifications(isRead: false, limit: 20);
      final count = await services.notifications.fetchUnreadCount();

      kNotificationUnreadCount.value = count;

      if (_isFirstRun) {
        _isFirstRun = false;
        // On initial login/app boot, seed pre-existing unread notification IDs into _notifiedIds
        // so past unread notifications do NOT trigger push notifications on login.
        for (final n in unreadList) {
          _notifiedIds.add(n.id);
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('notified_bg_ids', _notifiedIds.toList());
        } catch (_) {}
        return;
      }

      final email = services.session.email ?? 'global';
      bool newNotified = false;

      for (final n in unreadList) {
        if (!_notifiedIds.contains(n.id)) {
          _notifiedIds.add(n.id);
          newNotified = true;

          final title = n.title.trim().isNotEmpty ? n.title.trim() : 'Lead Notification';
          final body = n.body.trim().isNotEmpty ? n.body.trim() : 'New notification received';

          await LocalNotificationService.showNotification(
            title: title,
            body: body,
            email: email,
          );
        }
      }

      if (newNotified) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('notified_bg_ids', _notifiedIds.toList());
      }
    } catch (e) {
      debugPrint('[GlobalNotificationPoller] Poll error: $e');
    }
  }
}

