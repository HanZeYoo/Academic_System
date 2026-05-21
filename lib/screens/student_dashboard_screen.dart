import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'announcement_management_screen.dart';
import 'student_grades_view_screen.dart';
import 'student_schedule_screen.dart';
import 'student_attendance_view_screen.dart';
import 'student_profile_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String username; // The student's email/username
  const StudentDashboardScreen({super.key, this.username = 'student'});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  String _selectedMenu = 'Dashboard';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6F0FA), // Light blue background
      appBar: AppBar(
        backgroundColor: const Color(0xFF3383B3), // App bar blue color
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMenu = 'Profile';
                });
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                radius: 18,
                child: Icon(Icons.person, color: Color(0xFF3383B3), size: 24),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF224A60), // Dark teal drawer background
        child: SafeArea(
          child: Column(
            children: [
              // Drawer Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Student Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1, thickness: 1),
              const SizedBox(height: 8),

              // Drawer Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  children: [
                    _buildMenuItem(
                      title: 'Dashboard',
                      icon: Icons.home,
                      isSelected: _selectedMenu == 'Dashboard',
                      onTap: () => _onMenuTap('Dashboard'),
                    ),
                    _buildMenuItem(
                      title: 'My Grades',
                      icon: Icons.grade,
                      isSelected: _selectedMenu == 'My Grades',
                      onTap: () => _onMenuTap('My Grades'),
                    ),
                    _buildMenuItem(
                      title: 'Class Schedule',
                      icon: Icons.schedule,
                      isSelected: _selectedMenu == 'Class Schedule',
                      onTap: () => _onMenuTap('Class Schedule'),
                    ),
                    _buildMenuItem(
                      title: 'Attendance',
                      icon: Icons.assignment_turned_in,
                      isSelected: _selectedMenu == 'Attendance',
                      onTap: () => _onMenuTap('Attendance'),
                    ),
                    _buildMenuItem(
                      title: 'Announcements',
                      icon: Icons.campaign,
                      isSelected: _selectedMenu == 'Announcements',
                      onTap: () => _onMenuTap('Announcements'),
                    ),
                    _buildMenuItem(
                      title: 'Profile',
                      icon: Icons.person,
                      isSelected: _selectedMenu == 'Profile',
                      onTap: () => _onMenuTap('Profile'),
                    ),
                    _buildMenuItem(
                      title: 'Settings',
                      icon: Icons.settings,
                      isSelected: _selectedMenu == 'Settings',
                      onTap: () => _onMenuTap('Settings'),
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
                    child: Icon(Icons.logout, color: Colors.white),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white, fontSize: 15),
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
    );
  }

  Widget _buildBody() {
    if (_selectedMenu == 'Settings') {
      return SettingsScreen(username: widget.username);
    }
    if (_selectedMenu == 'Profile') {
      return StudentProfileScreen(username: widget.username);
    }
    if (_selectedMenu == 'Announcements') {
      return AnnouncementManagementScreen(username: widget.username, role: 'student');
    }
    if (_selectedMenu == 'My Grades') {
      return StudentGradesViewScreen(username: widget.username);
    }
    if (_selectedMenu == 'Class Schedule') {
      return StudentScheduleScreen(username: widget.username);
    }
    if (_selectedMenu == 'Attendance') {
      return StudentAttendanceViewScreen(username: widget.username);
    }

    return Center(
      child: Text(
        _selectedMenu,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF224A60),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF3383B3) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _onMenuTap(String menu) {
    setState(() {
      _selectedMenu = menu;
    });
    Navigator.pop(context); // Close the drawer
  }
}
