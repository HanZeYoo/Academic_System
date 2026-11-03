import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'my_classes_screen.dart';
import 'assessment_setup_screen.dart';
import 'encode_scores_screen.dart';
import 'ecr_import_screen.dart';
import 'teacher_student_screen.dart';
import 'shared_profile_screen.dart';
import 'academic_evaluation_screen.dart';
import 'performance_analytics_screen.dart';
import 'parent_notification_screen.dart';
import 'teacher_attendance_screen.dart';
import 'reports_generation_screen.dart';
import 'announcement_management_screen.dart';
import '../database_helper.dart';
import '../utils/avatar_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/role_theme.dart';

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
  String? _profilePicture;
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
    try {
      final db = DatabaseHelper();
    
      // Load school years
      final years = await db.getAllSchoolYears();
      final activeYear = await db.getActiveSchoolYear();
      
      if (_selectedSchoolYear == null) {
        _selectedSchoolYear = activeYear;
      }
      
      final teacher = await db.getTeacherByEmail(widget.username);
      final tName = teacher?['name']?.toString() ?? 'Teacher';
      _profilePicture = teacher?['profile_picture']?.toString();
      
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (AestheticDialogs.isNetworkError(e)) {
          AestheticDialogs.showNoInternetSnackBar(context);
        }
      }
    }
  }

  Future<bool> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _showDiscardSectionDialog(String sectionName) async {
    // Read-only or safe navigation sections can return directly
    if (sectionName == 'Reports' || sectionName == 'Settings' || sectionName == 'Student Profiling') {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Leave Page?'),
          ],
        ),
        content: Text(
          'Are you sure you want to leave $sectionName? Any unsaved input or progress will be lost.',
          style: GoogleFonts.poppins(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Stay Here',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF0F52BA)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Leave Page',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_selectedMenu != 'Dashboard') {
          final shouldLeave = await _showDiscardSectionDialog(_selectedMenu);
          if (!shouldLeave) return;
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          final roleTheme = RoleTheme.teacherTheme;

          Widget drawerContent = Column(
            children: [
              // Drawer Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                decoration: BoxDecoration(
                  color: roleTheme.drawerHeader,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 24,
                          width: 24,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (_, _, _) => const Icon(Icons.school, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.outfit(fontSize: 18, letterSpacing: 0.2),
                                children: const [
                                  TextSpan(text: 'Notify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  TextSpan(text: 'ED', style: TextStyle(color: Color(0xFFBAE3FF), fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            RoleTheme.buildRoleBadge('teacher', fontSize: 9.5),
                          ],
                        ),
                      ],
                    ),
                    if (!isDesktop)
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
                      icon: Icons.home_rounded,
                      isSelected: _selectedMenu == 'Dashboard',
                      onTap: () => _onMenuTap('Dashboard', isDesktop: isDesktop),
                    ),
                    _buildMenuItem(
                      title: 'My Classes',
                      icon: Icons.menu_book_rounded,
                      isSelected: _selectedMenu == 'My Classes',
                      onTap: () => _onMenuTap('My Classes', isDesktop: isDesktop),
                    ),
                    _buildMenuItem(
                      title: 'Student',
                      icon: Icons.people_rounded,
                      isSelected: _selectedMenu == 'Student',
                      onTap: () => _onMenuTap('Student', isDesktop: isDesktop),
                    ),
                    _buildExpandableMenuItem(
                      title: 'Grade Encoding',
                      icon: Icons.assignment_add,
                      subItems: ['Encode score', 'Assessment setup', 'ECR Import'],
                      isDesktop: isDesktop,
                    ),
                    _buildMenuItem(
                      title: 'Academic Evaluation',
                      icon: Icons.fact_check_rounded,
                      isSelected: _selectedMenu == 'Academic Evaluation',
                      onTap: () => _onMenuTap('Academic Evaluation', isDesktop: isDesktop),
                    ),
                    _buildMenuItem(
                      title: 'Performance Analytics',
                      icon: Icons.insights_rounded,
                      isSelected: _selectedMenu == 'Performance Analytics' || _selectedMenu == 'Failure Analytics',
                      onTap: () => _onMenuTap('Performance Analytics', isDesktop: isDesktop),
                    ),
                    _buildMenuItem(
                      title: 'Parent Notification',
                      icon: Icons.notifications_rounded,
                      isSelected: _selectedMenu == 'Parent Notification',
                      onTap: () => _onMenuTap('Parent Notification', isDesktop: isDesktop),
                    ),
                    _buildMenuItem(
                      title: 'Attendance',
                      icon: Icons.assignment_turned_in_rounded,
                      isSelected: _selectedMenu == 'Attendance',
                      onTap: () => _onMenuTap('Attendance', isDesktop: isDesktop),
                    ),
                    _buildMenuItem(
                      title: 'Reports',
                      icon: Icons.pie_chart_rounded,
                      isSelected: _selectedMenu == 'Reports',
                      onTap: () => _onMenuTap('Reports', isDesktop: isDesktop),
                    ),
                    _buildMenuItem(
                      title: 'Announcement',
                      icon: Icons.campaign_rounded,
                      isSelected: _selectedMenu == 'Announcement',
                      onTap: () => _onMenuTap('Announcement', isDesktop: isDesktop),
                    ),
                    _buildMenuItem(
                      title: 'Settings',
                      icon: Icons.settings_rounded,
                      isSelected: _selectedMenu == 'Settings',
                      onTap: () => _onMenuTap('Settings', isDesktop: isDesktop),
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
                  onTap: () async {
                    final logout = await _showLogoutDialog();
                    if (logout && mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(isLoggingOut: true),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          );

          return Scaffold(
            backgroundColor: roleTheme.scaffoldBackground,
            appBar: AppBar(
              backgroundColor: roleTheme.primary,
              elevation: 0,
              flexibleSpace: Container(
                decoration: BoxDecoration(gradient: roleTheme.appBarGradient),
              ),
              automaticallyImplyLeading: !isDesktop,
              title: isDesktop
                  ? Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 24,
                          width: 24,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (_, _, _) => const Icon(Icons.school, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(fontSize: 18, letterSpacing: 0.2),
                            children: const [
                              TextSpan(text: 'Notify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              TextSpan(text: 'ED', style: TextStyle(color: Color(0xFFBAE3FF), fontWeight: FontWeight.w900)),
                              TextSpan(text: '  •  Teacher Portal', style: TextStyle(color: Color(0xFFE2F1FC), fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : null,
              actions: [
                if (_schoolYears.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSchoolYear,
                          dropdownColor: roleTheme.drawerBackground,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          onChanged: (String? newValue) {
                            if (newValue != null && newValue != _selectedSchoolYear) {
                              setState(() {
                                _selectedSchoolYear = newValue;
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
                    child: AvatarUtils.buildAvatar(
                      photo: _profilePicture,
                      name: _teacherName,
                      radius: 18,
                      foregroundColor: roleTheme.primary,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            drawer: !isDesktop
                ? Drawer(
                    backgroundColor: roleTheme.drawerBackground,
                    child: SafeArea(child: drawerContent),
                  )
                : null,
            body: Row(
              children: [
                if (isDesktop)
                  Container(
                    width: 260,
                    color: roleTheme.drawerBackground,
                    child: SafeArea(child: drawerContent),
                  ),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedMenu == 'Settings') {
      return SettingsScreen(username: widget.username, role: 'teacher');
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
    if (_selectedMenu == 'ECR Import') {
      return EcrImportScreen(
        username: widget.username,
        onBackToDashboard: () {
          setState(() {
            _selectedMenu = 'Dashboard';
          });
        },
      );
    }
    if (_selectedMenu == 'Profile') {
      return SharedProfileScreen(username: widget.username, role: UserRole.teacher);
    }
    if (_selectedMenu == 'Academic Evaluation') {
      return AcademicEvaluationScreen(username: widget.username, role: 'teacher');
    }
    if (_selectedMenu == 'Performance Analytics' || _selectedMenu == 'Failure Analytics') {
      return PerformanceAnalyticsScreen(
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
      color: RoleTheme.teacherTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: RoleTheme.teacherTheme.cardGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: RoleTheme.teacherTheme.primaryDark.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -20,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 28),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  _currentDate,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF67E8F9)),
                                SizedBox(width: 6),
                                Text(
                                  'Active Term',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Welcome back, $_teacherName!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Here is what is happening with your classes and teaching schedule today.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
  
            // Overview Stats
            const Text(
              'Instructional Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final double width;
                if (constraints.maxWidth >= 900) {
                  width = (constraints.maxWidth - 48) / 4;
                } else if (constraints.maxWidth < 450) {
                  width = constraints.maxWidth;
                } else {
                  width = (constraints.maxWidth - 16) / 2;
                }
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard(title: 'Assigned Classes', value: '$_totalClasses', icon: Icons.class_rounded, color: const Color(0xFF1E40AF), width: width),
                    _buildStatCard(title: 'Active Students', value: '$_totalStudents', icon: Icons.people_rounded, color: const Color(0xFF059669), width: width),
                    _buildStatCard(title: 'Pending Grades', value: '0', icon: Icons.pending_actions_rounded, color: const Color(0xFFD97706), width: width),
                    _buildStatCard(title: 'Avg. Attendance', value: _avgAttendance, icon: Icons.how_to_reg_rounded, color: const Color(0xFF7C3AED), width: width),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
  
            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildActionChip('Encode Scores', Icons.edit_document, () => setState(() => _selectedMenu = 'Encode score')),
                _buildActionChip('Take Attendance', Icons.check_circle_outline_rounded, () => setState(() => _selectedMenu = 'Attendance')),
                _buildActionChip('View Students', Icons.groups_rounded, () => setState(() => _selectedMenu = 'Student')),
                _buildActionChip('My Classes', Icons.menu_book_rounded, () => setState(() => _selectedMenu = 'My Classes')),
              ],
            ),
            const SizedBox(height: 24),
  
            // Announcements
            const Text(
              'Recent School Announcements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            if (_recentAnnouncements.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.campaign_outlined, size: 36, color: Color(0xFF94A3B8)),
                    SizedBox(height: 8),
                    Text('No recent announcements posted.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  ],
                ),
              )
            else
              ..._recentAnnouncements.map((a) => _buildAnnouncementCard(a)),
            const SizedBox(height: 20),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDD6B20).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFFDD6B20), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  a['title']?.toString() ?? 'Announcement',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  a['date_posted']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a['content']?.toString() ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: RoleTheme.teacherTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: RoleTheme.teacherTheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
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
        color: isSelected ? RoleTheme.teacherTheme.drawerSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 0.0,
        ),
        dense: true,
      ),
    );
  }

  Widget _buildExpandableMenuItem({
    required String title,
    required IconData icon,
    required List<String> subItems,
    bool isDesktop = false,
  }) {
    bool isExpandedOrSelected = subItems.contains(_selectedMenu);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isExpandedOrSelected
            ? RoleTheme.teacherTheme.drawerSelected.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpandedOrSelected,
          leading: Icon(icon, color: Colors.white, size: 22),
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
              margin: const EdgeInsets.only(left: 36, right: 8, bottom: 4),
              decoration: BoxDecoration(
                color: isSubItemSelected
                    ? RoleTheme.teacherTheme.drawerSelected
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
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                onTap: () => _onMenuTap(subItem, isDesktop: isDesktop),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                dense: true,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _onMenuTap(String title, {bool isDesktop = false}) {
    setState(() {
      _selectedMenu = title;
    });
    if (!isDesktop) {
      Navigator.pop(context); // Close the drawer on mobile
    }
  }
}
