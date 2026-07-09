import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'my_classes_screen.dart';
import 'assessment_setup_screen.dart';
import 'encode_scores_screen.dart';
import 'teacher_student_screen.dart';
import 'shared_profile_screen.dart';
import 'academic_evaluation_screen.dart';
import 'failure_analytics_screen.dart';
import 'parent_notification_screen.dart';
import 'teacher_attendance_screen.dart';
import 'reports_generation_screen.dart';
import 'announcement_management_screen.dart';
import '../database_helper.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final String username;
  const TeacherDashboardScreen({super.key, this.username = 'teacher'});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  String _selectedMenu = 'Dashboard';
  bool _isLoading = true;
  String _teacherName = '';
  int _totalClasses = 0;
  int _totalStudents = 0;
  String _avgAttendance = '0%';
  List<Map<String, dynamic>> _recentAnnouncements = [];
  
  String? _pendingStudentId;
  String? _pendingMessage;

  String? _selectedSchoolYear;
  List<String> _schoolYears = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }
    final db = DatabaseHelper();
    
    // Load school years
    final years = await db.getAllSchoolYears();
    final activeYear = await db.getActiveSchoolYear();
    
    if (_selectedSchoolYear == null) {
      _selectedSchoolYear = activeYear;
    }
    
    final teacher = await db.getTeacherByEmail(widget.username);
    final tName = teacher?['name']?.toString() ?? 'Teacher';
    
    final classes = await db.getSubjectClassesByTeacher(tName, _selectedSchoolYear);
    
    // Calculate total students across all classes
    int studentCount = 0;
    Set<String> processedSections = {};
    for (var c in classes) {
      final sec = '${c['grade_level']}-${c['section_name']}';
      if (!processedSections.contains(sec)) {
        processedSections.add(sec);
        final students = await db.getStudentsBySection(c['grade_level']?.toString() ?? '', c['section_name']?.toString() ?? '', _selectedSchoolYear);
        studentCount += students.length;
      }
    }

    // Get Announcements
    final announcements = await db.getAnnouncements(widget.username, role: 'teacher');
    
    // Get Avg Attendance
    final avgAtt = await db.getAverageAttendanceForTeacher(tName);

    if (mounted) {
      setState(() {
        _schoolYears = years.isNotEmpty ? years : [activeYear];
        _teacherName = tName;
        _totalClasses = classes.length;
        _totalStudents = studentCount;
        _avgAttendance = avgAtt;
        _recentAnnouncements = announcements.take(3).toList();
        _isLoading = false;
      });
    }
  }

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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_selectedMenu != 'Dashboard') {
          setState(() {
            _selectedMenu = 'Dashboard';
          });
          return;
        }
        final shouldLogout = await _showLogoutDialog();
        if (shouldLogout && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen(isLoggingOut: true)),
          );
        }
      },
      child: Scaffold(
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
            if (_schoolYears.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSchoolYear,
                      dropdownColor: const Color(0xFF224A60),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != _selectedSchoolYear) {
                          setState(() {
                            _selectedSchoolYear = newValue;
                            // When changing school year, reload the dashboard data
                            _loadDashboardData();
                          });
                        }
                      },
                      items: _schoolYears.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
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
                      _buildExpandableMenuItem(
                        title: 'Grade Encoding',
                        icon: Icons.assignment_add,
                        subItems: ['Encode score', 'Assessment setup'],
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
                                    builder: (context) => const LoginScreen(isLoggingOut: true),
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
    if (_selectedMenu == 'Settings') {
      return SettingsScreen(username: widget.username);
    }
    if (_selectedMenu == 'My Classes') {
      return MyClassesScreen(username: widget.username);
    }
    if (_selectedMenu == 'Student') {
      return TeacherStudentScreen(username: widget.username);
    }
    if (_selectedMenu == 'Assessment setup') {
      return AssessmentSetupScreen(username: widget.username);
    }
    if (_selectedMenu == 'Encode score') {
      return EncodeScoresScreen(username: widget.username);
    }
    if (_selectedMenu == 'Profile') {
      return SharedProfileScreen(username: widget.username, role: UserRole.teacher);
    }
    if (_selectedMenu == 'Academic Evaluation') {
      return AcademicEvaluationScreen(username: widget.username, role: 'teacher');
    }
    if (_selectedMenu == 'Failure Analytics') {
      return FailureAnalyticsScreen(
        username: widget.username,
        onComposeNotification: (studentId, message) {
          setState(() {
            _pendingStudentId = studentId;
            _pendingMessage = message;
            _selectedMenu = 'Parent Notification';
          });
        },
      );
    }
    if (_selectedMenu == 'Parent Notification') {
      final screen = ParentNotificationScreen(
        username: widget.username,
        initialStudentId: _pendingStudentId,
        initialMessage: _pendingMessage,
      );
      // Clear after assigning so it doesn't stick
      _pendingStudentId = null;
      _pendingMessage = null;
      return screen;
    }
    if (_selectedMenu == 'Attendance') {
      return TeacherAttendanceScreen(username: widget.username);
    }
    if (_selectedMenu == 'Reports') {
      return ReportsGenerationScreen(username: widget.username);
    }
    if (_selectedMenu == 'Announcement') {
      return AnnouncementManagementScreen(username: widget.username);
    }

    return _buildDashboardOverview();
  }

  String get _currentDate {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Widget _buildDashboardOverview() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadDashboardData(isRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3383B3), Color(0xFF1E5676)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentDate,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back, $_teacherName!',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Here is what is happening with your classes today.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
  
            // Overview Stats
            const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF224A60))),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                double width = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard(title: 'Total Classes', value: '$_totalClasses', icon: Icons.class_, color: const Color(0xFF4C51BF), width: width),
                    _buildStatCard(title: 'Total Students', value: '$_totalStudents', icon: Icons.people, color: const Color(0xFF00A364), width: width),
                    _buildStatCard(title: 'Pending Grades', value: '0', icon: Icons.pending_actions, color: const Color(0xFFDD6B20), width: width),
                    _buildStatCard(title: 'Avg. Attendance', value: _avgAttendance, icon: Icons.how_to_reg, color: const Color(0xFFD53F8C), width: width),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
  
            // Quick Actions
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF224A60))),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildActionChip('Encode Scores', Icons.edit_document, () => setState(() => _selectedMenu = 'Encode score')),
                  const SizedBox(width: 12),
                  _buildActionChip('Take Attendance', Icons.check_circle_outline, () => setState(() => _selectedMenu = 'Attendance')),
                  const SizedBox(width: 12),
                  _buildActionChip('View Students', Icons.groups, () => setState(() => _selectedMenu = 'Student')),
                ],
              ),
            ),
            const SizedBox(height: 24),
  
            // Announcements
            const Text('Recent Announcements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF224A60))),
            const SizedBox(height: 12),
            if (_recentAnnouncements.isEmpty)
              const Text('No recent announcements', style: TextStyle(color: Colors.grey))
            else
              ..._recentAnnouncements.map((a) => _buildAnnouncementCard(a)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> a) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: Color(0xFFDD6B20), size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(a['title']?.toString() ?? 'Announcement', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3748)), overflow: TextOverflow.ellipsis)),
              Text(a['date_posted']?.toString() ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(a['content']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3383B3).withOpacity(0.3)),
          boxShadow: [BoxShadow(color: const Color(0xFF3383B3).withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF3383B3)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF224A60))),
          ],
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
        leading: Icon(icon, color: Colors.white, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 0.0,
        ),
        visualDensity: const VisualDensity(
          horizontal: 0,
          vertical: -2,
        ), // Makes it a bit more compact
      ),
    );
  }

  Widget _buildExpandableMenuItem({
    required String title,
    required IconData icon,
    required List<String> subItems,
  }) {
    bool isExpandedOrSelected = subItems.contains(_selectedMenu);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isExpandedOrSelected
            ? const Color(0xFF36617A).withOpacity(0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpandedOrSelected,
          leading: Icon(icon, color: Colors.white, size: 24),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 0.0,
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          childrenPadding: EdgeInsets.zero,
          children: subItems.map((subItem) {
            final isSubItemSelected = _selectedMenu == subItem;
            return Container(
              margin: const EdgeInsets.only(left: 40, right: 8, bottom: 4),
              decoration: BoxDecoration(
                color: isSubItemSelected
                    ? const Color(0xFF36617A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(
                  subItem,
                  style: TextStyle(
                    color: isSubItemSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSubItemSelected
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
                onTap: () => _onMenuTap(subItem),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              ),
            );
          }).toList(),
        ),
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
