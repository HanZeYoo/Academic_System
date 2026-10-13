import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFB8D8EE).withValues(alpha: 0.85),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B81B7).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F4FD),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: const Color(0xFF2B81B7)),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF102A43),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color headerBlue = Color(0xFF2B81B7);
    const Color deepNavy = Color(0xFF0F2B48);
    const Color subtitleColor = Color(0xFF334E68);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient with Ambient Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE4F3FD),
                    Color(0xFFCBEAFB),
                    Color(0xFFBDDFF6),
                  ],
                ),
              ),
            ),
          ),

          // Ambient Decorative Glow Orbs
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    headerBlue.withValues(alpha: 0.16),
                    headerBlue.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.65),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Foreground Content
          Column(
            children: [
              // Top App Bar
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF2272A3),
                      Color(0xFF2B81B7),
                      Color(0xFF358FC5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 28,
                          width: 28,
                          fit: BoxFit.contain,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.image_not_supported, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                              fontSize: 21,
                              letterSpacing: 0.3,
                              shadows: const [
                                Shadow(
                                  color: Color(0x33000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            children: const [
                              TextSpan(
                                text: 'Notify',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: 'ED',
                                style: TextStyle(
                                  color: Color(0xFFBAE3FF),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.school_outlined, size: 12, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'Academic Portal',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content Body
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // Welcoming School Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: headerBlue.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_rounded, size: 16, color: headerBlue),
                            const SizedBox(width: 6),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: headerBlue,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Welcome to ',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                    text: 'Notify',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(
                                    text: 'ED',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Main App Name
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.outfit(
                            fontSize: 40,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: headerBlue.withValues(alpha: 0.18),
                                offset: const Offset(0, 3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          children: const [
                            TextSpan(
                              text: 'Notify',
                              style: TextStyle(
                                color: deepNavy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: 'ED',
                              style: TextStyle(
                                color: headerBlue,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Subtitle
                      Text(
                        'Academic Evaluation &\nParent Connection',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Feature Highlights Micro-Badges
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildFeatureChip(Icons.assessment_rounded, 'Academic Tracking'),
                          _buildFeatureChip(Icons.connect_without_contact_rounded, 'Parent Connect'),
                          _buildFeatureChip(Icons.notifications_active_rounded, 'Instant Alerts'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Logo with Dual-Ring Glowing Aura Badge
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              headerBlue.withValues(alpha: 0.3),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: headerBlue.withValues(alpha: 0.22),
                              blurRadius: 24,
                              spreadRadius: 3,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 74,
                            width: 74,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported,
                              size: 54,
                              color: Color(0xFF24445A),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Start Button with Sleek Gradient & Icon Pill
                      _isCheckingSession
                          ? const CircularProgressIndicator(color: headerBlue)
                          : Container(
                              width: 175,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2272A3),
                                    Color(0xFF2B81B7),
                                    Color(0xFF3892C8),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: headerBlue.withValues(alpha: 0.38),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Start',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.22),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      const Spacer(flex: 3),

                      // Welcoming Trust Footer
                      Text(
                        '@2026 NotifyED. A Capstone Project',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: const Color(0xFF486581),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: headerBlue.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 14, color: headerBlue),
                            const SizedBox(width: 5),
                            Text(
                              'Secure & Private',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334E68),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
