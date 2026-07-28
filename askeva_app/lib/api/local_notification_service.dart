import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      try {
        await Permission.notification.request();
      } catch (_) {}

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _plugin.initialize(settings);

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        try {
          await androidImpl.requestNotificationsPermission();
        } catch (_) {}

        // Create high-importance Android channels for heads-up notification banners
        const soundChannel = AndroidNotificationChannel(
          'askeva_sound_channel',
          'Askeva Sound Notifications',
          description: 'Notifications from Askeva App with sound and banner',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        const vibrateChannel = AndroidNotificationChannel(
          'askeva_vibrate_channel',
          'Askeva Vibrate Notifications',
          description: 'Notifications from Askeva App with vibration banner',
          importance: Importance.high,
          playSound: false,
          enableVibration: true,
        );

        const silentChannel = AndroidNotificationChannel(
          'askeva_silent_channel',
          'Askeva Silent Notifications',
          description: 'Notifications from Askeva App silent banner',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        );

        try {
          await androidImpl.createNotificationChannel(soundChannel);
          await androidImpl.createNotificationChannel(vibrateChannel);
          await androidImpl.createNotificationChannel(silentChannel);
        } catch (_) {}
      }

      _initialized = true;
    } catch (_) {}
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? email,
  }) async {
    await init();
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = email ?? 'global';
      final pushEnabled = prefs.getBool('push_notifications_enabled_$userEmail') ?? true;

      // Suppress mobile system bar notification if push notifications are disabled
      if (!pushEnabled) return;

      final soundMode = prefs.getString('notification_sound_mode_$userEmail') ?? 'sound';

      String channelId;
      String channelName;
      Importance importance;
      Priority priority;
      bool playSound;
      bool enableVibration;

      if (soundMode == 'sound') {
        channelId = 'askeva_sound_channel';
        channelName = 'Askeva Sound Notifications';
        importance = Importance.max;
        priority = Priority.max;
        playSound = true;
        enableVibration = true;
      } else if (soundMode == 'vibrate') {
        channelId = 'askeva_vibrate_channel';
        channelName = 'Askeva Vibrate Notifications';
        importance = Importance.high;
        priority = Priority.high;
        playSound = false;
        enableVibration = true;
      } else {
        // Silent mode
        channelId = 'askeva_silent_channel';
        channelName = 'Askeva Silent Notifications';
        importance = Importance.low;
        priority = Priority.low;
        playSound = false;
        enableVibration = false;
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Notifications from Askeva App',
        importance: importance,
        priority: priority,
        playSound: playSound,
        enableVibration: enableVibration,
        icon: '@mipmap/launcher_icon',
        visibility: NotificationVisibility.public,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundMode == 'sound',
      );

      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }
}
