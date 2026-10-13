import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    try {
      await PushNotificationService().initialize();
    } catch (e) {
      debugPrint('Failed to initialize push notifications: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2B81B7);
    const Color deepNavy = Color(0xFF0F2B48);
    const Color pageBackground = Color(0xFFEAF5FD);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'NotifyED',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: const Color(0xFF486581),
          surface: Colors.white,
          surfaceTint: Colors.transparent,
        ),
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: deepNavy),
          displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: deepNavy),
          displaySmall: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: deepNavy),
          headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: deepNavy),
          headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: deepNavy),
          headlineSmall: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: deepNavy),
          titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: deepNavy),
          titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: deepNavy),
          titleSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: deepNavy),
          bodyLarge: GoogleFonts.poppins(color: const Color(0xFF102A43)),
          bodyMedium: GoogleFonts.poppins(color: const Color(0xFF243B53)),
          bodySmall: GoogleFonts.poppins(color: const Color(0xFF486581)),
          labelLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 1.5,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: primaryBlue.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            side: const BorderSide(color: Color(0xFFB8D8EE), width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryBlue,
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB8D8EE), width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB8D8EE), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryBlue, width: 1.8),
          ),
          hintStyle: GoogleFonts.poppins(
            color: const Color(0xFF829AB1),
            fontSize: 13.5,
          ),
          labelStyle: GoogleFonts.poppins(
            color: const Color(0xFF102A43),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: const Color(0xFF1E4663).withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: deepNavy,
          ),
          contentTextStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF334E68),
            height: 1.45,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          contentTextStyle: GoogleFonts.poppins(
            fontSize: 13.5,
            color: Colors.white,
          ),
        ),
      ),
      home: const LandingScreen(),
    );
  }
}
