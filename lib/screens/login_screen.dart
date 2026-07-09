import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import 'admin_dashboard.dart';
import 'teacher_dashboard_screen.dart';
import 'student_dashboard_screen.dart';
import 'parent_dashboard_screen.dart';
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

    if (user['role'] == 'teacher') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TeacherDashboardScreen(username: user['username'])),
      );
    } else if (user['role'] == 'student') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => StudentDashboardScreen(username: user['username'])),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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
      
      // 2. If Firebase succeeds, fetch user role from local SQLite
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
        _showError('User profile not found in local database.');
      }
    } on AuthException catch (e) {
      // 3. Fallback to SQLite (for legacy accounts like 'admin' without valid email format)
      if (e.message.contains('Invalid login credentials') || e.message.contains('Email not confirmed')) {
        final localUser = await dbHelper.login(username, password);
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
        setState(() => _isLoading = false);
        _showError(e.message ?? 'Authentication error');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('An error occurred. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color buttonColor = Color(0xFF2B81B7);
    const Color backgroundColor = Color(0xFFCBEAFB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: buttonColor,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text(
              'AcadInsight',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    const Text(
                      'AcadInsight',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to your account',
                      style: TextStyle(fontSize: 18, color: Colors.black87),
                    ),
                    const SizedBox(height: 32),
                    Image.asset(
                      'assets/images/logo.png',
                      height: 150,
                      width: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported,
                        size: 80,
                        color: Color(0xFF24445A),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Username Field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'User ID or Email',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(text: newValue.text.toLowerCase())),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g., student.id@school.edu',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Colors.black87,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: buttonColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Password',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.black87),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.black87,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Color(0xFF2B81B7)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFF2B81B7),
                        ),
                        const Text('Remember Me', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF2B81B7), fontWeight: FontWeight.bold)),
                                content: const Text(
                                  'For security reasons, password resets must be verified. Please contact your school administrator or IT department to request a password reset.',
                                  style: TextStyle(height: 1.4),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFF2B81B7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
              child: Column(
                children: [
                  const Text(
                    '@2026 AcadInsight. A Capstone Project',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.security,
                        size: 14,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Secure & Private',
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
