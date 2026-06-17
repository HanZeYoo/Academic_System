import 'package:flutter/material.dart';
import 'admin_overview_screen.dart';
import 'student_management_screen.dart';
import 'teacher_management_screen.dart';
import 'subject_class_screen.dart';
import 'academic_evaluation_screen.dart';
import 'failure_analytics_screen.dart';
import 'parent_notification_screen.dart';
import 'reports_generation_screen.dart';
import 'announcement_management_screen.dart';
import 'admin_profile_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'admin_archive_screen.dart';

class AdminDashboard extends StatefulWidget {
  final String username;
  const AdminDashboard({super.key, this.username = 'admin'});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Set to 0 initially to match the Dashboard Overview screen
  int _selectedIndex = 0;

  Future<bool> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const Color appBarColor = Color(0xFF2B81B7);
    const Color drawerColor = Color(0xFF24445A);
    const Color hoveredColor = Color(0xFF335C7A);
    const Color backgroundColor = Color(0xFFCBEAFB);
    const Color textWhite = Colors.white;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }
        final shouldLogout = await _showLogoutDialog();
        if (shouldLogout && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          iconTheme: const IconThemeData(color: textWhite),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedIndex = 9; // Index para sa Admin Profile
                  });
                },
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: drawerColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(
                    top: 20,
                    left: 24,
                    right: 16,
                    bottom: 20,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white24, width: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Menu',
                        style: TextStyle(
                          color: textWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Icon(
                          Icons.arrow_back,
                          color: textWhite,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuItem(0, Icons.home, 'Dashboard', hoveredColor),
                      _buildMenuItem(
                        1,
                        Icons.people,
                        'Student Management',
                        hoveredColor,
                      ),
                      _buildMenuItem(
                        2,
                        Icons.co_present,
                        'Teacher Management',
                        hoveredColor,
                      ),
                      _buildMenuItem(
                        3,
                        Icons.menu_book,
                        'Subject & Classes',
                        hoveredColor,
                      ),
                      _buildMenuItem(
                        4,
                        Icons.assignment_turned_in,
                        'Academic Evaluation',
                        hoveredColor,
                      ),
                      _buildMenuItem(
                        5,
                        Icons.show_chart,
                        'Failure Analytics',
                        hoveredColor,
                      ),
                      _buildMenuItem(
                        6,
                        Icons.notifications,
                        'Parent Notification',
                        hoveredColor,
                      ),
                      _buildMenuItem(
                        7,
                        Icons.pie_chart,
                        'Reports Generation',
                        hoveredColor,
                      ),
                      _buildMenuItem(
                        8,
                        Icons.campaign,
                        'Announcements',
                        hoveredColor,
                      ),
                      _buildMenuItem(
                        11,
                        Icons.archive,
                        'Archive & Bin',
                        hoveredColor,
                      ),
                      _buildMenuItem(
                        10,
                        Icons.settings,
                        'Settings',
                        hoveredColor,
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white24, width: 0.5),
                    ),
                  ),
                  child: ListTile(
                    leading: const Padding(
                      padding: EdgeInsets.only(left: 16.0),
                      child: Icon(Icons.logout, color: textWhite),
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: textWhite, fontSize: 15),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context); // Close dialog
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const AdminOverviewScreen();
      case 1:
        return const StudentManagementScreen();
      case 2:
        return const TeacherManagementScreen();
      case 3:
        return const SubjectClassScreen();
      case 4:
        return const AcademicEvaluationScreen();
      case 5:
        return FailureAnalyticsScreen(username: widget.username);
      case 6:
        return const ParentNotificationScreen();
      case 7:
        return const ReportsGenerationScreen();
      case 8:
        return const AnnouncementManagementScreen();
      case 9:
        return const AdminProfileScreen();
      case 10:
        return SettingsScreen(username: widget.username);
      case 11:
        return const AdminArchiveScreen();
      default:
        return const Center(child: Text('Placeholder Screen'));
    }
  }

  Widget _buildMenuItem(
    int index,
    IconData icon,
    String title,
    Color hoveredColor,
  ) {
    bool isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? hoveredColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          Navigator.pop(context); // Optional: close drawer when selected
        },
      ),
    );
  }
}
