import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database_helper.dart';
import '../main.dart';
import 'login_screen.dart';
import 'admin_dashboard.dart';
import 'teacher_dashboard_screen.dart';
import 'student_dashboard_screen.dart';
import 'parent_dashboard_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool rememberMe = prefs.getBool('remember_me') ?? false;

      if (!rememberMe) {
        // If remember me is false, sign out to clear the session and show Start button
        await Supabase.instance.client.auth.signOut();
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null && session.user.email != null) {
        final String email = session.user.email!;
        final dbHelper = DatabaseHelper();
        
        // Look up user role by email
        final user = await dbHelper.getUserByUsername(email);
        
        if (user != null && mounted) {
          LoginScreen.loggedInUser = user['username'];
          LoginScreen.loggedInRole = user['role'];

          String? deepLinkRoute = pendingDeepLinkRoute;
          pendingDeepLinkRoute = null;

          if (user['role'] == 'teacher') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TeacherDashboardScreen(username: user['username'])));
            return;
          } else if (user['role'] == 'student') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StudentDashboardScreen(username: user['username'])));
            return;
          } else if (user['role'] == 'parent') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ParentDashboardScreen(
              username: user['username'],
              initialMenu: deepLinkRoute == 'notifications' ? 'Notifications' : null,
            )));
            return;
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard(username: user['username'])));
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error during session check: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color headerBlue = Color(0xFF2B81B7);
    const Color pageBlue = Color(0xFFCBEAFB);

    return Scaffold(
      backgroundColor: pageBlue,
      appBar: AppBar(
        backgroundColor: headerBlue,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 28,
              width: 28,
              fit: BoxFit.contain,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'AcadInsight',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 56),
            const Text(
              'AcadInsight',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Academic Evaluation &\nParent Connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34 / 2,
                height: 1.35,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 36),
            Image.asset(
              'assets/images/logo.png',
              height: 120,
              width: 120,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported,
                size: 80,
                color: Color(0xFF24445A),
              ),
            ),
            const SizedBox(height: 56),
            _isCheckingSession
                ? const CircularProgressIndicator(color: headerBlue)
                : SizedBox(
                    width: 150,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: headerBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Start',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
            const Spacer(),
            const Text(
              '@2026 AcadInsight. A Capstone Project',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 14, color: Colors.black87),
                SizedBox(width: 4),
                Text(
                  'Secure & Private',
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
