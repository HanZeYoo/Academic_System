import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../utils/dialog_utils.dart';
import 'landing_screen.dart';
import 'admin_dashboard.dart';
import 'teacher_dashboard_screen.dart';
import 'student_dashboard_screen.dart';
import 'parent_dashboard_screen.dart';
import 'student_profile_setup_screen.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final bool isLoggingOut;
  const LoginScreen({super.key, this.isLoggingOut = false});
  
  static String? loggedInUser;
  static String? loggedInRole;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggingOut) {
      _performLogout();
    }
  }

  Future<void> _performLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', false);
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Error during logout cleanup: $e');
    }
  }

  void _routeUser(Map<String, dynamic> user) async {
    if (!mounted) return;
    
    LoginScreen.loggedInUser = user['username'];
    LoginScreen.loggedInRole = user['role'];

    // Save remember_me state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', _rememberMe);
    
    // Fallback variable for route to pass
    String? deepLinkRoute = pendingDeepLinkRoute;
    pendingDeepLinkRoute = null; // Clear it once used

    if (!mounted) return;

    if (user['role'] == 'teacher') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TeacherDashboardScreen(username: user['username'])),
      );
    } else if (user['role'] == 'student') {
      // Check if profile is complete
      final studentData = await DatabaseHelper().getStudentByEmail(user['username']);
      if (!mounted) return;
      final isProfileIncomplete = studentData != null && 
                                 (studentData['address'] == null || 
                                  studentData['address'].toString().trim().isEmpty);
      
      if (isProfileIncomplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => StudentProfileSetupScreen(studentData: studentData)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => StudentDashboardScreen(username: user['username'])),
        );
      }
    } else if (user['role'] == 'parent') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ParentDashboardScreen(
          username: user['username'],
          initialMenu: deepLinkRoute == 'notifications' ? 'Notifications' : null,
        )),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminDashboard(username: user['username'])),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AestheticDialogs.showErrorDialog(context, 'Login Failed', message);
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    final dbHelper = DatabaseHelper();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      // 1. Try Supabase Auth first
      await Supabase.instance.client.auth.signInWithPassword(
        email: username,
        password: password,
      );
      
      // 2. Fetch user profile from database
      final user = await dbHelper.getUserByUsername(username);
      setState(() => _isLoading = false);
      
      if (user != null) {
        try {
          String? token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await dbHelper.updateUserFCMToken(username, token);
          }
        } catch (e) {
          debugPrint('Error getting or saving FCM token: $e');
        }
        _routeUser(user);
      } else {
        _showError('User profile not found in database.');
      }
    } on AuthException catch (e) {
      // Check if it's a network error
      if (AestheticDialogs.isNetworkError(e.message)) {
        // Fallback to local offline login if available
        final localUser = await dbHelper.login(username, password);
        setState(() => _isLoading = false);
        if (localUser != null) {
          _routeUser(localUser);
          return;
        }
        if (!mounted) return;
        AestheticDialogs.showNoInternetDialog(context, onRetry: _handleLogin);
        return;
      }

      // 3. Fallback to SQLite (for legacy accounts like 'admin' without valid email format)
      if (e.message.contains('Invalid login credentials') || e.message.contains('Email not confirmed')) {
        final localUser = await dbHelper.login(username, password);
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        if (localUser != null) {
          try {
            String? token = await FirebaseMessaging.instance.getToken();
            if (token != null) {
              await dbHelper.updateUserFCMToken(username, token);
            }
          } catch (e) {
            debugPrint('Error getting or saving FCM token: $e');
          }
          _routeUser(localUser);
        } else {
          _showError('Invalid username or password!');
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError(AestheticDialogs.getCleanErrorMessage(e.message));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (AestheticDialogs.isNetworkError(e)) {
        // Fallback to local offline login if available
        final localUser = await dbHelper.login(username, password);
        if (!mounted) return;
        if (localUser != null) {
          _routeUser(localUser);
          return;
        }
        AestheticDialogs.showNoInternetDialog(context, onRetry: _handleLogin);
        return;
      }
      _showError(AestheticDialogs.getCleanErrorMessage(e));
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Forgot Password?',
          style: GoogleFonts.poppins(
            color: const Color(0xFF2B81B7),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'For security reasons, password resets must be verified. Please contact your school administrator or IT department to request a password reset.',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            height: 1.45,
            color: const Color(0xFF334E68),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Understood',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2B81B7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB8D8EE).withValues(alpha: 0.7),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B81B7).withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF2B81B7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF243B53),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color buttonColor = Color(0xFF2B81B7);
    const Color deepNavy = Color(0xFF0F2B48);
    const Color subtitleColor = Color(0xFF486581);

    return Scaffold(
      body: Stack(
        children: [
          // Base Background Gradient
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
                    buttonColor.withValues(alpha: 0.16),
                    buttonColor.withValues(alpha: 0.0),
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
          Positioned(
            top: 260,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    buttonColor.withValues(alpha: 0.08),
                    buttonColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main Foreground Content
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LandingScreen()),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 12),
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
                              const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'Portal Access',
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 6),

                        // Welcoming Pill Badge
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
                                color: buttonColor.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.waving_hand_rounded, size: 15, color: Color(0xFFE5A134)),
                              const SizedBox(width: 6),
                              Text(
                                'Welcome Back',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: buttonColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Title
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                              fontSize: 34,
                              letterSpacing: -0.5,
                              shadows: [
                                Shadow(
                                  color: buttonColor.withValues(alpha: 0.18),
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
                                  color: buttonColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sign in to your account',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Portal Role Micro-Chips
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildRoleChip(Icons.school_rounded, 'Teacher'),
                            _buildRoleChip(Icons.person_outline_rounded, 'Student'),
                            _buildRoleChip(Icons.family_restroom_rounded, 'Parent'),
                            _buildRoleChip(Icons.admin_panel_settings_outlined, 'Admin'),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Logo in Dual-Ring Glowing Aura Badge
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                buttonColor.withValues(alpha: 0.28),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: buttonColor.withValues(alpha: 0.18),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 56,
                              width: 56,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_not_supported,
                                size: 40,
                                color: Color(0xFF24445A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Username Field Label
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: buttonColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'User ID or Email',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF102A43),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: buttonColor.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                blurRadius: 2,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _usernameController,
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              color: const Color(0xFF102A43),
                            ),
                            inputFormatters: [
                              TextInputFormatter.withFunction((oldValue, newValue) =>
                                  newValue.copyWith(text: newValue.text.toLowerCase())),
                            ],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'Enter your email or user ID',
                              hintStyle: GoogleFonts.poppins(
                                color: const Color(0xFF829AB1),
                                fontSize: 13,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 8, right: 6),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F4FD),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFB8D8EE).withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: buttonColor,
                                    size: 16,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 38),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(26),
                                borderSide: const BorderSide(color: Color(0xFFB8D8EE), width: 1.2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(26),
                                borderSide: const BorderSide(color: Color(0xFFB8D8EE), width: 1.2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(26),
                                borderSide: const BorderSide(color: buttonColor, width: 1.8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),

                        // Password Field Label
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: buttonColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Password',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF102A43),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: buttonColor.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                blurRadius: 2,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              color: const Color(0xFF102A43),
                            ),
                            onSubmitted: (_) {
                              if (!_isLoading) _handleLogin();
                            },
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              hintStyle: GoogleFonts.poppins(
                                color: const Color(0xFF829AB1),
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 8, right: 6),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F4FD),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFB8D8EE).withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    color: buttonColor,
                                    size: 16,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 38),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: const Color(0xFF627D98),
                                  size: 19,
                                ),
                                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                splashRadius: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(26),
                                borderSide: const BorderSide(color: Color(0xFFB8D8EE), width: 1.2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(26),
                                borderSide: const BorderSide(color: Color(0xFFB8D8EE), width: 1.2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(26),
                                borderSide: const BorderSide(color: buttonColor, width: 1.8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Remember Me & Forgot Password
                        Row(
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                activeColor: buttonColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                side: const BorderSide(color: Color(0xFF829AB1), width: 1.4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _rememberMe = !_rememberMe),
                              child: Text(
                                'Remember Me',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF243B53),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _showForgotPasswordDialog,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.help_outline_rounded, size: 13, color: buttonColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.poppins(
                                      color: buttonColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Login Button with Gradient & Icon Pill
                        Container(
                          width: double.infinity,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2272A3),
                                Color(0xFF2B81B7),
                                Color(0xFF3892C8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: buttonColor.withValues(alpha: 0.38),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sign In',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.22),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
              child: Column(
                children: [
                  Text(
                    '@2026 NotifyED. A Capstone Project',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: const Color(0xFF486581),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 13, color: buttonColor),
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
                ],
              ),
            ),
            ],
          ),
        ],
      ),
    );
  }
}
