import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'screens/landing_screen.dart';

import 'package:flutter/foundation.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
String? pendingDeepLinkRoute;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print("Handling a background message: ${message.messageId}");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Mobile only)
  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  await Supabase.initialize(
    url: 'https://vslqselpnkpghtpnxryg.supabase.co',
    anonKey: 'sb_publishable_qAfWW1fw67Xb85gAtWyBZg_sKB-ISaW',
  );

  // Request Permissions and Get Token (Mobile only)
  if (!kIsWeb) {
    await PushNotificationService().initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Academic System Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Segoe UI', useMaterial3: true),
      home: const LandingScreen(),
    );
  }
}
