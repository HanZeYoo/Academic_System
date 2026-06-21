import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/login_screen.dart';
import '../screens/parent_dashboard_screen.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Initialize local notifications for Android
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(settings: initializationSettings);

    // 2. Create High Importance Channel for Android Banners
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Set Firebase foreground presentation options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Request permission for iOS and Android 13+
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get the token
      String? token = await _fcm.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }
      
      // TODO: Save token to Supabase or your preferred database here
      // saveTokenToDatabase(token);

      // Listen to token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('FCM Token Refreshed: $newToken');
        }
        // TODO: Update token in database
        // saveTokenToDatabase(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Received a foreground message: ${message.messageId}');
        }
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        // If message has notification payload, show local notification
        if (notification != null && android != null) {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                channelDescription: 'This channel is used for important notifications.',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
                styleInformation: BigTextStyleInformation(
                  notification.body ?? '',
                  htmlFormatBigText: true,
                  contentTitle: notification.title,
                  htmlFormatContentTitle: true,
                ),
              ),
            ),
          );
        }
      });
    }

    // 4. Handle Deep Linking
    // App is in Background, user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Notification caused app to open from background: ${message.data}');
      }
      _handleDeepLink(message);
    });

    // App is Terminated, user taps notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('Notification caused app to open from terminated state: ${initialMessage.data}');
      }
      _handleDeepLink(initialMessage);
    }
  }

  void _handleDeepLink(RemoteMessage message) {
    if (message.data.containsKey('route')) {
      String route = message.data['route'];
      
      // If user is currently logged in as parent, navigate directly
      if (LoginScreen.loggedInUser != null && LoginScreen.loggedInRole == 'parent') {
        if (navigatorKey.currentContext != null) {
          Navigator.pushReplacement(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (context) => ParentDashboardScreen(
                username: LoginScreen.loggedInUser!,
                initialMenu: route == 'notifications' ? 'Notifications' : null,
              ),
            ),
          );
        }
      } else {
        // App is opening from terminated state or user is not logged in.
        // Save it for LoginScreen to handle after successful login.
        pendingDeepLinkRoute = route;
      }
    }
  }
}
