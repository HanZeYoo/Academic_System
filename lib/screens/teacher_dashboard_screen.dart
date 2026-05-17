import 'package:flutter/material.dart';
import 'login_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
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
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: const Icon(Icons.person, color: Color(0xFF3383B3), size: 24),
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Menu',
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
                      title: 'My Classes',
                      icon: Icons.menu_book,
                      isSelected: _selectedMenu == 'My Classes',
                      onTap: () => _onMenuTap('My Classes'),
                    ),
                    _buildMenuItem(
                      title: 'Student',
                      icon: Icons.people,
                      isSelected: _selectedMenu == 'Student',
                      onTap: () => _onMenuTap('Student'),
                    ),
                    _buildMenuItem(
                      title: 'Grade Encoding',
                      icon: Icons.assignment_add,
                      isSelected: _selectedMenu == 'Grade Encoding',
                      onTap: () => _onMenuTap('Grade Encoding'),
                    ),
                    _buildMenuItem(
                      title: 'Academic Evaluation',
                      icon: Icons.fact_check,
                      isSelected: _selectedMenu == 'Academic Evaluation',
                      onTap: () => _onMenuTap('Academic Evaluation'),
                    ),
                    _buildMenuItem(
                      title: 'Failure Analytics',
                      icon: Icons.show_chart,
                      isSelected: _selectedMenu == 'Failure Analytics',
                      onTap: () => _onMenuTap('Failure Analytics'),
                    ),
                    _buildMenuItem(
                      title: 'Parent Notification',
                      icon: Icons.notifications,
                      isSelected: _selectedMenu == 'Parent Notification',
                      onTap: () => _onMenuTap('Parent Notification'),
                    ),
                    _buildMenuItem(
                      title: 'Attendance',
                      icon: Icons.assignment_turned_in,
                      isSelected: _selectedMenu == 'Attendance',
                      onTap: () => _onMenuTap('Attendance'),
                    ),
                    _buildMenuItem(
                      title: 'Reports',
                      icon: Icons.pie_chart,
                      isSelected: _selectedMenu == 'Reports',
                      onTap: () => _onMenuTap('Reports'),
                    ),
                    _buildMenuItem(
                      title: 'Announcement',
                      icon: Icons.campaign,
                      isSelected: _selectedMenu == 'Announcement',
                      onTap: () => _onMenuTap('Announcement'),
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
      body: Center(
        child: Text(
          _selectedMenu,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF224A60),
          ),
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
        color: isSelected ? const Color(0xFF36617A) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2), // Makes it a bit more compact
      ),
    );
  }

  void _onMenuTap(String title) {
    setState(() {
      _selectedMenu = title;
    });
    Navigator.pop(context); // Close the drawer
  }
}
