import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'announcement_management_screen.dart';
import 'student_grades_view_screen.dart';
import 'student_attendance_view_screen.dart';
import '../database_helper.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String username;
  const ParentDashboardScreen({super.key, required this.username});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  String _selectedMenu = 'Dashboard';
  bool _isLoading = true;

  List<Map<String, dynamic>> _children = [];
  int _selectedChildIndex = 0;

  List<Map<String, dynamic>> _schedule = [];
  List<Map<String, dynamic>> _subjectGrades = [];
  double _overallAverage = 0.0;
  double _attendancePercentage = 0.0;
  bool _hasAttendance = false;

  @override
  void initState() {
    super.initState();
    _fetchParentAndChildrenData();
  }

  Future<void> _fetchParentAndChildrenData() async {
    final dbHelper = DatabaseHelper();
    _children = await dbHelper.getStudentsByParentEmail(widget.username);
    if (_children.isNotEmpty) {
      await _fetchDashboardDataForChild(_children[_selectedChildIndex]);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDashboardDataForChild(Map<String, dynamic> student) async {
    setState(() => _isLoading = true);

    final dbHelper = DatabaseHelper();
    final studentEmail = student['email'] ?? '';
    final gradeLevel = student['grade_level'] ?? '';
    final sectionName = student['section'] ?? '';
    const gradingPeriod = '1st Quarter';

    _schedule = await dbHelper.getStudentSchedule(studentEmail);

    final attendanceRecords = await dbHelper.getStudentAttendance(studentEmail);
    _hasAttendance = attendanceRecords.isNotEmpty;
    if (_hasAttendance) {
      final presentCount = attendanceRecords
          .where((r) => r['status'] == 'Present' || r['status'] == 'Late')
          .length;
      _attendancePercentage = (presentCount / attendanceRecords.length) * 100;
    } else {
      _attendancePercentage = 0.0;
    }

    final scores = await dbHelper.getStudentAllScores(studentEmail);
    _subjectGrades.clear();
    double sumOfAverages = 0.0;
    int validSubjects = 0;

    final Map<String, Map<String, dynamic>> uniqueSubjects = {};
    for (var s in _schedule) {
      uniqueSubjects[s['subject_code'] ?? 'Unknown'] = s;
    }

    for (var subjectData in uniqueSubjects.values) {
      final subjectName = subjectData['subject_name'] ?? 'Unknown';
      final subjectCode = subjectData['subject_code'] ?? 'Unknown';
      final classAttendancePct = _hasAttendance ? _attendancePercentage : 100.0;
      final subjectScores = scores
          .where((s) =>
              s['subject_code'] == subjectCode &&
              s['grading_period'] == gradingPeriod)
          .toList();
      double grade = 0.0;

      if (subjectScores.isNotEmpty) {
        final setup = await dbHelper.getAssessmentSetup(
          subjectCode: subjectCode,
          sectionName: sectionName,
          gradeLevel: gradeLevel,
          gradingPeriod: gradingPeriod,
        );

        double categoryAvg(String category) {
          final catScores = subjectScores
              .where((r) =>
                  r['category'].toString().toLowerCase() ==
                  category.toLowerCase())
              .toList();
          if (catScores.isEmpty) return 0.0;
          double total = 0, max = 0;
          for (final r in catScores) {
            total += (r['score'] as num?)?.toDouble() ?? 0;
            max += (r['total_score'] as num?)?.toDouble() ?? 0;
          }
          return max == 0 ? 0.0 : (total / max) * 100;
        }

        if (setup != null) {
          final wQuiz = (setup['quiz_weight'] as num?)?.toDouble() ?? 20;
          final wAssignment = (setup['assignment_weight'] as num?)?.toDouble() ?? 15;
          final wActivity = (setup['activity_weight'] as num?)?.toDouble() ?? 20;
          final wProject = (setup['project_weight'] as num?)?.toDouble() ?? 15;
          final wExam = (setup['exam_weight'] as num?)?.toDouble() ?? 30;
          final wAttendance = (setup['attendance_weight'] as num?)?.toDouble() ?? 0;

          grade = (categoryAvg('Quiz') * (wQuiz / 100)) +
              (categoryAvg('Assignment') * (wAssignment / 100)) +
              (categoryAvg('Activity') * (wActivity / 100)) +
              (categoryAvg('Project') * (wProject / 100)) +
              (categoryAvg('Exam') * (wExam / 100)) +
              (classAttendancePct * (wAttendance / 100));
        } else {
          double total = 0, max = 0;
          for (final r in subjectScores) {
            total += (r['score'] as num?)?.toDouble() ?? 0;
            max += (r['total_score'] as num?)?.toDouble() ?? 0;
          }
          if (max > 0) grade = (total / max) * 100;
        }

        sumOfAverages += grade;
        validSubjects++;
      }

      String status = 'No Grades';
      Color color = Colors.grey;
      if (grade >= 90) {
        status = 'Excellent'; color = const Color(0xFF1976D2);
      } else if (grade >= 75) {
        status = 'Passed'; color = const Color(0xFF388E3C);
      } else if (grade > 0) {
        status = 'At-Risk'; color = const Color(0xFFD32F2F);
      }

      _subjectGrades.add({
        'subjectName': subjectName,
        'subjectCode': subjectCode,
        'grade': grade,
        'status': status,
        'color': color,
        'schedule': subjectData['schedule'] ?? 'TBA',
        'time': subjectData['time'] ?? 'TBA',
      });
    }

    _overallAverage = validSubjects > 0 ? sumOfAverages / validSubjects : 0.0;
    if (mounted) setState(() => _isLoading = false);
  }

  void _onChildSelected(int index) {
    if (index != _selectedChildIndex) {
      setState(() => _selectedChildIndex = index);
      _fetchDashboardDataForChild(_children[index]);
    }
  }

  void _onMenuTap(String menu) {
    setState(() => _selectedMenu = menu);
    Navigator.pop(context);
  }

  void _handleLogout() {
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
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic>? get _selectedChild =>
      _children.isNotEmpty ? _children[_selectedChildIndex] : null;

  String get _selectedChildEmail => _selectedChild?['email'] ?? '';

  // ─── Scaffold ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6F0FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3383B3),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          _selectedMenu,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: const Icon(Icons.family_restroom,
                  color: Color(0xFF3383B3), size: 22),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }

  // ─── Drawer ─────────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF224A60),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF3383B3),
                    child: const Icon(Icons.family_restroom,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Parent Portal',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text(
                          widget.username,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _drawerItem('Dashboard', Icons.home_rounded),
                  _drawerItem('My Child', Icons.child_care_rounded),
                  _drawerItem('Grades', Icons.grade_rounded),
                  _drawerItem('Attendance', Icons.assignment_turned_in_rounded),
                  _drawerItem('Notifications', Icons.notifications_rounded),
                  _drawerItem('Announcements', Icons.campaign_rounded),
                  _drawerItem('Intervention Plan', Icons.handshake_rounded),
                  _drawerItem('Settings', Icons.settings_rounded),
                ],
              ),
            ),
            // Logout
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(String title, IconData icon) {
    final isSelected = _selectedMenu == title;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF3383B3) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: isSelected ? Colors.white : Colors.white60, size: 22),
        title: Text(title,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14)),
        onTap: () => _onMenuTap(title),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
      ),
    );
  }

  // ─── Body Router ────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_selectedMenu == 'Settings') {
      return SettingsScreen(username: widget.username);
    }
    if (_selectedMenu == 'Announcements') {
      return AnnouncementManagementScreen(
          username: widget.username, role: 'parent');
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_children.isEmpty) {
      return _buildNoChildView();
    }

    if (_selectedMenu == 'Grades') {
      return _buildGradesScreen();
    }
    if (_selectedMenu == 'Attendance') {
      return _buildAttendanceScreen();
    }
    if (_selectedMenu == 'My Child') {
      return _buildMyChildScreen();
    }
    if (_selectedMenu == 'Notifications') {
      return _buildNotificationsScreen();
    }
    if (_selectedMenu == 'Intervention Plan') {
      return _buildInterventionPlanScreen();
    }

    // Dashboard (default)
    return _buildDashboard();
  }

  // ─── No Child View ───────────────────────────────────────────────────────────

  Widget _buildNoChildView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, size: 90, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text('No Children Found',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF224A60))),
            const SizedBox(height: 10),
            Text(
              'No students are registered under\n${widget.username}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Child Selector (shared widget) ─────────────────────────────────────────

  Widget _buildChildSelector() {
    if (_children.length <= 1) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Child',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF224A60))),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _children.length,
            itemBuilder: (context, index) {
              final child = _children[index];
              final isSelected = index == _selectedChildIndex;
              return GestureDetector(
                onTap: () => _onChildSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 160,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3383B3)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.grey.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : const Color(0xFF3383B3).withOpacity(0.1),
                        child: Icon(Icons.person,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF3383B3),
                            size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child['name'] ?? 'Unknown',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF224A60)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${child['grade_level']} - ${child['section']}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── Dashboard Screen ────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    final child = _selectedChild!;
    final avgStr = _overallAverage > 0
        ? _overallAverage.toStringAsFixed(1)
        : 'N/A';
    final attStr = _hasAttendance
        ? '${_attendancePercentage.toStringAsFixed(0)}%'
        : 'N/A';

    // Determine overall standing color
    Color avgColor = Colors.grey;
    if (_overallAverage >= 90) avgColor = const Color(0xFF1976D2);
    else if (_overallAverage >= 75) avgColor = const Color(0xFF388E3C);
    else if (_overallAverage > 0) avgColor = const Color(0xFFD32F2F);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            'Hello, Parent!',
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF224A60)),
          ),
          const SizedBox(height: 4),
          const Text('SY 2026-2027 | 1st Quarter',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),

          // Child Selector (only when multiple children)
          _buildChildSelector(),

          // Selected Child Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3383B3), Color(0xFF224A60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3383B3).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.person,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child['name'] ?? 'Unknown',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${child['grade_level']} - ${child['section']}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'LRN: ${child['lrn'] ?? 'N/A'}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Academic Overview
          const Text('Academic Overview',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF224A60))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _statCard('Average', avgStr,
                      Icons.emoji_events_rounded, Colors.orange)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard('Attendance', attStr,
                      Icons.check_circle_rounded, Colors.green)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard('Subjects', '${_schedule.length}',
                      Icons.menu_book_rounded, Colors.blue)),
            ],
          ),
          const SizedBox(height: 24),

          // Current Standing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Standing',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF224A60))),
              TextButton(
                onPressed: () => setState(() => _selectedMenu = 'Grades'),
                child: const Text('View All',
                    style: TextStyle(color: Color(0xFF3383B3))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_subjectGrades.isEmpty)
            _emptyCard('No grades available yet.')
          else
            ..._subjectGrades.map((s) => _subjectCard(s)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── My Child Screen ─────────────────────────────────────────────────────────

  Widget _buildMyChildScreen() {
    final child = _selectedChild!;
    final email = child['email'] ?? '';
    final name = child['name'] ?? 'Unknown';
    final gradeLevel = child['grade_level'] ?? '';
    final section = child['section'] ?? '';
    final lrn = child['lrn'] ?? 'N/A';
    final parentEmail = child['parent_email'] ?? 'N/A';
    final address = child['address'] ?? 'N/A';
    final contact = child['contact_number'] ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Switcher if multiple children
          _buildChildSelector(),

          // Profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3383B3), Color(0xFF224A60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3383B3).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 52),
                ),
                const SizedBox(height: 14),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('$gradeLevel - $section',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details
          const Text('Student Information',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF224A60))),
          const SizedBox(height: 12),
          _infoCard([
            _infoRow(Icons.badge_rounded, 'LRN', lrn),
            _infoRow(Icons.email_rounded, 'School Email', email),
            _infoRow(Icons.email_outlined, 'Parent Email', parentEmail),
            _infoRow(Icons.location_on_rounded, 'Address', address),
            _infoRow(Icons.phone_rounded, 'Contact', contact),
          ]),
          const SizedBox(height: 20),

          // Academic Summary
          const Text('Academic Summary',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF224A60))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _statCard(
                      'Average',
                      _overallAverage > 0
                          ? _overallAverage.toStringAsFixed(1)
                          : 'N/A',
                      Icons.emoji_events_rounded,
                      Colors.orange)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard(
                      'Attendance',
                      _hasAttendance
                          ? '${_attendancePercentage.toStringAsFixed(0)}%'
                          : 'N/A',
                      Icons.check_circle_rounded,
                      Colors.green)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _statCard('Subjects', '${_schedule.length}',
                      Icons.menu_book_rounded, Colors.blue)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard(
                      'Status',
                      _overallAverage >= 75
                          ? 'Good'
                          : _overallAverage > 0
                              ? 'At-Risk'
                              : 'N/A',
                      Icons.star_rounded,
                      _overallAverage >= 75 ? Colors.green : Colors.red)),
            ],
          ),
          const SizedBox(height: 24),

          // Subject Standing
          const Text('Subject Standing',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF224A60))),
          const SizedBox(height: 12),
          if (_subjectGrades.isEmpty)
            _emptyCard('No grades available yet.')
          else
            ..._subjectGrades.map((s) => _subjectCard(s)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Intervention Plan Screen ────────────────────────────────────────────────

  Widget _buildInterventionPlanScreen() {
    // Identify at-risk subjects (grade > 0 && grade < 75)
    final atRiskSubjects =
        _subjectGrades.where((s) => s['grade'] > 0 && s['grade'] < 75).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChildSelector(),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3383B3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.handshake_rounded,
                    color: Color(0xFF3383B3), size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Intervention Plan',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF224A60))),
                    Text('Support plan for at-risk subjects',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (atRiskSubjects.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 60),
                  const SizedBox(height: 16),
                  const Text('All Clear!',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  const SizedBox(height: 8),
                  Text(
                    '${_selectedChild?['name'] ?? 'Your child'} is not at risk in any subject.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Alert banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedChild?['name'] ?? 'Your child'} has ${atRiskSubjects.length} subject(s) below passing grade.',
                      style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Per-subject intervention cards
            const Text('Subjects Needing Attention',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF224A60))),
            const SizedBox(height: 10),
            ...atRiskSubjects.map((s) => _interventionCard(s)),
            const SizedBox(height: 20),

            // General guidance
            const Text('General Recommendations',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF224A60))),
            const SizedBox(height: 10),
            _recommendationCard(Icons.home_rounded, Colors.purple,
                'Home Support',
                'Set a daily study schedule and a quiet study area at home. Be involved in reviewing your child\'s notes and assignments.'),
            _recommendationCard(Icons.person_rounded, Colors.orange,
                'Teacher Consultation',
                'Request a one-on-one meeting with the subject teacher to understand your child\'s learning gaps.'),
            _recommendationCard(Icons.group_rounded, Colors.teal,
                'Peer Study Groups',
                'Encourage your child to form or join study groups with classmates to strengthen understanding.'),
            _recommendationCard(Icons.menu_book_rounded, Colors.blue,
                'Additional Reading',
                'Supplement school learning with supplementary materials, review books, or online resources for the subject.'),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _interventionCard(Map<String, dynamic> subject) {
    final grade = (subject['grade'] as double);
    final deficit = 75.0 - grade;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.book_rounded,
                    color: Colors.red, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject['subjectName'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF224A60))),
                    Text('Current Grade: ${grade.toStringAsFixed(1)}',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('-${deficit.toStringAsFixed(1)} pts',
                    style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: grade / 100,
              backgroundColor: Colors.red.withOpacity(0.1),
              color: Colors.red,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current: ${grade.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Text('Target: 75.0%',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Recommended Actions:',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF224A60))),
          const SizedBox(height: 6),
          _actionBullet('Talk to the subject teacher about your child\'s specific weak areas.'),
          _actionBullet('Review missed or low-scoring assessments at home.'),
          _actionBullet('Encourage daily review of notes for this subject.'),
        ],
      ),
    );
  }

  Widget _actionBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(color: Color(0xFF3383B3), fontSize: 14)),
          Expanded(
              child: Text(text,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _recommendationCard(
      IconData icon, Color color, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF224A60))),
                const SizedBox(height: 4),
                Text(body,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Notifications Screen ────────────────────────────────────────────────────

  Widget _buildNotificationsScreen() {
    final List<Map<String, dynamic>> notifications = [];

    for (final s in _subjectGrades) {
      if ((s['grade'] as double) > 0 && (s['grade'] as double) < 75) {
        notifications.add({
          'icon': Icons.warning_rounded,
          'color': Colors.red,
          'title': 'Grade Alert: ${s['subjectName']}',
          'body': '${_selectedChild?['name'] ?? 'Your child'} is at-risk in ${s['subjectName']} with a grade of ${(s['grade'] as double).toStringAsFixed(1)}.',
          'time': 'This quarter',
        });
      }
    }
    if (_hasAttendance && _attendancePercentage < 80) {
      notifications.add({
        'icon': Icons.event_busy_rounded,
        'color': Colors.orange,
        'title': 'Low Attendance',
        'body': '${_selectedChild?['name'] ?? 'Your child'} has an attendance rate of ${_attendancePercentage.toStringAsFixed(0)}%, below the 80% recommendation.',
        'time': 'This quarter',
      });
    }
    if (_overallAverage >= 75) {
      notifications.add({
        'icon': Icons.star_rounded,
        'color': Colors.green,
        'title': 'Good Academic Standing',
        'body': '${_selectedChild?['name'] ?? 'Your child'} has a current average of ${_overallAverage.toStringAsFixed(1)} and is in good academic standing.',
        'time': 'This quarter',
      });
    }
    if (!_hasAttendance) {
      notifications.add({
        'icon': Icons.info_rounded,
        'color': Colors.blue,
        'title': 'No Attendance Records Yet',
        'body': 'Attendance for ${_selectedChild?['name'] ?? 'your child'} has not been recorded yet this quarter.',
        'time': 'This quarter',
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChildSelector(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3383B3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_rounded, color: Color(0xFF3383B3), size: 26),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF224A60))),
                  Text('${notifications.length} alert(s) for ${_selectedChild?['name'] ?? 'your child'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (notifications.isEmpty)
            _emptyCard('No notifications at this time.')
          else
            ...notifications.map((n) {
              final Color color = n['color'] as Color;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.25)),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.07), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(n['icon'] as IconData, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(n['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color))),
                              Text(n['time'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(n['body'], style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Parent-specific Grades Screen ──────────────────────────────────────────

  Widget _buildGradesScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChildSelector(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF3383B3).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.grade_rounded, color: Color(0xFF3383B3), size: 26),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Grades', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF224A60))),
                  Text('${_selectedChild?['name'] ?? ''} · 1st Quarter', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Average Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3383B3), Color(0xFF224A60)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.orange, size: 40),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overall Average', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      _overallAverage > 0 ? _overallAverage.toStringAsFixed(1) : 'N/A',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _overallAverage >= 90 ? '🏅 Excellent' : _overallAverage >= 75 ? '✅ Passing' : _overallAverage > 0 ? '⚠️ Needs Improvement' : 'No grades yet',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          Row(
            children: [
              _legendBadge('Excellent', const Color(0xFF1976D2)),
              const SizedBox(width: 8),
              _legendBadge('Passed', const Color(0xFF388E3C)),
              const SizedBox(width: 8),
              _legendBadge('At-Risk', const Color(0xFFD32F2F)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Subject Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF224A60))),
          const SizedBox(height: 12),
          if (_subjectGrades.isEmpty)
            _emptyCard('No grades recorded yet for this quarter.')
          else
            ..._subjectGrades.map((s) {
              final Color color = s['color'] as Color;
              final double grade = s['grade'] as double;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.2)),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.07), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.book_rounded, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s['subjectName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF224A60))),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(grade > 0 ? grade.toStringAsFixed(1) : 'N/A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(s['status'], style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (grade > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: grade / 100, backgroundColor: color.withOpacity(0.1), color: color, minHeight: 7),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${grade.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                          const Text('Passing: 75.0%', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _legendBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Parent-specific Attendance Screen ──────────────────────────────────────

  Widget _buildAttendanceScreen() {
    return _ParentAttendanceWidget(
      studentEmail: _selectedChildEmail,
      studentName: _selectedChild?['name'] ?? '',
      childSelector: _buildChildSelector(),
    );
  }

  // ─── Reusable Widgets ────────────────────────────────────────────────────────

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF224A60))),
          const SizedBox(height: 3),
          Text(title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _subjectCard(Map<String, dynamic> subject) {
    final Color color = subject['color'] as Color;
    final double grade = subject['grade'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.book_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject['subjectName'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF224A60))),
                const SizedBox(height: 2),
                Text('${subject['schedule']} • ${subject['time']}',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                grade > 0 ? grade.toStringAsFixed(1) : 'N/A',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF224A60)),
              ),
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(subject['status'],
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3383B3)),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF224A60)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(message,
            style: const TextStyle(color: Colors.grey, fontSize: 15)),
      ),
    );
  }
}

// ─── Parent Attendance Widget (separate StatefulWidget for data fetching) ─────

class _ParentAttendanceWidget extends StatefulWidget {
  final String studentEmail;
  final String studentName;
  final Widget childSelector;

  const _ParentAttendanceWidget({
    required this.studentEmail,
    required this.studentName,
    required this.childSelector,
  });

  @override
  State<_ParentAttendanceWidget> createState() => _ParentAttendanceWidgetState();
}

class _ParentAttendanceWidgetState extends State<_ParentAttendanceWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ParentAttendanceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentEmail != widget.studentEmail) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper();
    final records = await db.getStudentAttendance(widget.studentEmail);
    int present = 0, absent = 0, late = 0;
    for (final r in records) {
      final status = r['status'] ?? '';
      if (status == 'Present') present++;
      else if (status == 'Absent') absent++;
      else if (status == 'Late') late++;
    }
    if (mounted) {
      setState(() {
        _records = records;
        _presentCount = present;
        _absentCount = absent;
        _lateCount = late;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final total = _records.length;
    final attendPct = total > 0
        ? ((_presentCount + _lateCount) / total * 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.childSelector,

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3383B3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_turned_in_rounded,
                    color: Color(0xFF3383B3), size: 26),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF224A60))),
                  Text(
                    '${widget.studentName} · 1st Quarter',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3383B3), Color(0xFF224A60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attendance Rate',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  total > 0 ? '${attendPct.toStringAsFixed(0)}%' : 'N/A',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (total > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: attendPct / 100,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      color: attendPct >= 80 ? Colors.greenAccent : Colors.orange,
                      minHeight: 8,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stat Row
          Row(
            children: [
              Expanded(child: _attStat('Present', _presentCount, Colors.green, Icons.check_circle_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _attStat('Late', _lateCount, Colors.orange, Icons.schedule_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _attStat('Absent', _absentCount, Colors.red, Icons.cancel_rounded)),
            ],
          ),
          const SizedBox(height: 24),

          // Records
          const Text('Attendance Records',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF224A60))),
          const SizedBox(height: 12),

          if (_records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Center(
                child: Text('No attendance records found.',
                    style: TextStyle(color: Colors.grey, fontSize: 15)),
              ),
            )
          else
            ..._records.map((r) {
              final status = r['status'] ?? 'Present';
              Color statusColor = Colors.green;
              IconData statusIcon = Icons.check_circle_rounded;
              if (status == 'Absent') {
                statusColor = Colors.red;
                statusIcon = Icons.cancel_rounded;
              } else if (status == 'Late') {
                statusColor = Colors.orange;
                statusIcon = Icons.schedule_rounded;
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.15)),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 5, offset: const Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['class_name'] ?? 'Class',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF224A60)),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(r['date'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(status,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _attStat(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 5, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text('$count',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
