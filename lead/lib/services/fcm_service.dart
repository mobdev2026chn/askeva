import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart'; // Added for background handler
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../modules/leads/lead_details_page.dart';
import '../main.dart'; // To access navigatorKey
import 'dart:convert';
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Register Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. Request Permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined or has not accepted permission');
    }

    // 2. Setup Local Notifications for Foreground
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final data = json.decode(response.payload!);
          _handleMessageNavigation(data);
        }
      },
    );

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('[FCM] Foreground Message Received: ${message.data}'); // Added Log

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: android.smallIcon,
            ),
          ),
          payload: json.encode(message.data),
        );
      }
    });

    // 4. Handle Background/Terminated Click
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      _handleMessageNavigation(message.data);
    });

    // Check if app was opened from terminated state
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      _handleMessageNavigation(initialMessage.data);
    }

    // 5. Get and Update Token
    updateToken();
  }

  static Future<void> updateToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        // Send to backend
        await _sendTokenToBackend(token);
      }

      _messaging.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(newToken);
      });
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final userToken = await AuthService.getToken();
      if (userToken == null) {
        print(
          'FCM: Cannot update backend. No Auth Token found (user not logged in).',
        );
        return;
      }

      final baseUrl = AuthService.baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/v1/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userToken',
        },
        body: json.encode({'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        print('FCM Token updated on backend');
      } else {
        print('Failed to update FCM Token on backend: ${response.body}');
      }
    } catch (e) {
      print('Error sending token to backend: $e');
    }
  }

  static Future<void> clearToken() async {
    try {
      final userToken = await AuthService.getToken();
      if (userToken == null) return;

      final baseUrl = AuthService.baseUrl;
      await http.post(
        Uri.parse('$baseUrl/v1/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userToken',
        },
        body: json.encode({'fcmToken': null}),
      );
      print('FCM Token cleared on backend');
    } catch (e) {
      print('Error clearing FCM token on backend: $e');
    }
  }

  static void _handleMessageNavigation(Map<String, dynamic> data) {
    if (data['actionType'] == 'NEW_LEAD') {
      final leadId = data['leadId'];
      if (leadId != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => LeadDetailsPage(leadId: leadId),
          ),
        );
      }
      print('Navigate to Lead ID: $leadId');
    }
  }
}
