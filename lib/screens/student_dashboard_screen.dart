import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'announcement_management_screen.dart';
import 'student_grades_view_screen.dart';
import 'student_schedule_screen.dart';
import 'student_attendance_view_screen.dart';
import 'shared_profile_screen.dart';

import '../database_helper.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String username; // The student's email/username
  const StudentDashboardScreen({super.key, this.username = 'student'});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  String _selectedMenu = 'Dashboard';
  String _studentName = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _schedule = [];
  List<Map<String, dynamic>> _subjectGrades = [];
  double _overallAverage = 0.0;
  double _attendancePercentage = 0.0;
  bool _hasAttendance = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final dbHelper = DatabaseHelper();
    
    // Fetch Name & Details
    final student = await dbHelper.getStudentByEmail(widget.username);
    final gradeLevel = student?['grade_level'] ?? '';
    final sectionName = student?['section'] ?? '';
    const gradingPeriod = '1st Quarter'; // Assuming first quarter for dashboard view

    if (student != null && student['name'] != null) {
      _studentName = student['name'];
    } else {
      _studentName = widget.username;
    }

    // Fetch Schedule
    _schedule = await dbHelper.getStudentSchedule(widget.username);

    // Fetch Attendance
    final attendanceRecords = await dbHelper.getStudentAttendance(widget.username);
    _hasAttendance = attendanceRecords.isNotEmpty;
    if (_hasAttendance) {
      // Treat 'Present' and 'Late' as attending the class.
      int presentCount = attendanceRecords.where((r) => r['status'] == 'Present' || r['status'] == 'Late').length;
      _attendancePercentage = (presentCount / attendanceRecords.length) * 100;
    } else {
      _attendancePercentage = 0.0;
    }

    // Fetch Scores
    final scores = await dbHelper.getStudentAllScores(widget.username);

    _subjectGrades.clear();
    double sumOfAverages = 0.0;
    int validSubjects = 0;

    // Get unique subjects from schedule
    Map<String, Map<String, dynamic>> uniqueSubjects = {};
    for (var s in _schedule) {
      String code = s['subject_code'] ?? 'Unknown';
      uniqueSubjects[code] = s;
    }

    for (var subjectData in uniqueSubjects.values) {
      String subjectName = subjectData['subject_name'] ?? 'Unknown';
      String subjectCode = subjectData['subject_code'] ?? 'Unknown';

      // Subject-specific attendance
      // In this system, attendance is taken per section, not per subject.
      // Therefore, the subject's attendance percentage is the overall student attendance.
      // If there are no attendance records yet, we assume 100% so grades aren't penalized prematurely.
      double classAttendancePct = _hasAttendance ? _attendancePercentage : 100.0;

      // Filter scores
      var subjectScores = scores.where((s) => s['subject_code'] == subjectCode && s['grading_period'] == gradingPeriod).toList();
      
      double grade = 0.0;

      if (subjectScores.isNotEmpty) {
        // Fetch Assessment Setup
        final setup = await dbHelper.getAssessmentSetup(
          subjectCode: subjectCode,
          sectionName: sectionName,
          gradeLevel: gradeLevel,
          gradingPeriod: gradingPeriod,
        );

        double categoryAvg(String category) {
          final catScores = subjectScores.where((r) => r['category'].toString().toLowerCase() == category.toLowerCase()).toList();
          if (catScores.isEmpty) return 0.0;
          double total = 0, max = 0;
          for (final r in catScores) {
            total += (r['score'] as num?)?.toDouble() ?? 0;
            max   += (r['total_score'] as num?)?.toDouble() ?? 0;
          }
          if (max == 0) return 0.0;
          return (total / max) * 100;
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
            max   += (r['total_score'] as num?)?.toDouble() ?? 0;
          }
          if (max > 0) grade = (total / max) * 100;
        }

        sumOfAverages += grade;
        validSubjects++;
      }
      
      String status = 'N/A';
      Color color = Colors.grey;
      if (grade >= 90) {
        status = 'Passed';
        color = Colors.blue;
      } else if (grade >= 75) {
        status = 'Passed';
        color = Colors.green;
      } else if (grade > 0) {
        status = 'At-Risk';
        color = Colors.red;
      }

      IconData getIcon(String sub) {
        String s = sub.toLowerCase();
        if (s.contains('math')) return Icons.calculate;
        if (s.contains('sci')) return Icons.science;
        if (s.contains('eng')) return Icons.menu_book;
        if (s.contains('fil')) return Icons.wb_sunny;
        return Icons.class_;
      }

      _subjectGrades.add({
        'subject': subjectName,
        'grade': grade > 0 ? '${grade.toStringAsFixed(0)}%' : 'N/A',
        'status': status,
        'color': color,
        'icon': getIcon(subjectName),
      });
    }

    if (validSubjects > 0) {
      _overallAverage = sumOfAverages / validSubjects;
    } else {
      _overallAverage = 0.0;
    }

    if (mounted) {
      setState(() {
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
    if (_selectedMenu == 'Profile') {
      return SharedProfileScreen(username: widget.username, role: UserRole.student);
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

    if (_selectedMenu == 'Dashboard') {
      return _buildDashboardContent();
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

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Section
          Text(
            'Good Day, ${_studentName.isNotEmpty ? _studentName : widget.username}!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF224A60),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'SY 2026-2027 | 1st Quarter',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // 2. Academic Overview
          const Text(
            'Academic Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF224A60),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildOverviewCard('Average', _overallAverage > 0 ? _overallAverage.toStringAsFixed(1) : 'N/A', Icons.emoji_events, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildOverviewCard('Attendance', _attendancePercentage > 0 || _hasAttendance ? '${_attendancePercentage.toStringAsFixed(0)}%' : 'N/A', Icons.check_circle, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildOverviewCard('Subjects', '${_schedule.length}', Icons.menu_book, Colors.blue)),
            ],
          ),
          const SizedBox(height: 24),

          // 3. My Subjects
          _buildMySubjectsSection(),
          const SizedBox(height: 24),

          // 4. Today's Schedule
          const Text(
            'Today\'s Schedule',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF224A60),
            ),
          ),
          const SizedBox(height: 12),
          if (_schedule.isEmpty)
            const Text('No classes scheduled.', style: TextStyle(color: Colors.grey))
          else
            ..._schedule.map((classData) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildScheduleCard(
                  classData['time'] ?? 'TBA',
                  classData['subject_name'] ?? 'Unknown Subject',
                  classData['room'] ?? 'TBA',
                  isOngoing: false,
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF224A60),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(String time, String subject, String room, {bool isOngoing = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isOngoing ? Border.all(color: const Color(0xFF3383B3), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOngoing ? const Color(0xFF3383B3).withOpacity(0.1) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time.split(' - ').join('\n'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOngoing ? const Color(0xFF3383B3) : Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF224A60),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      room,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isOngoing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3383B3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Now',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMySubjectsSection() {
    if (_subjectGrades.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Subjects',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF224A60),
              ),
            ),
            TextButton(
              onPressed: () {
                _onMenuTap('My Grades'); // Route to grades/subjects screen
              },
              child: const Text('View All', style: TextStyle(color: Color(0xFF3383B3))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _subjectGrades.map((subjectData) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: _buildSubjectCard(
                  subjectData['subject'],
                  subjectData['grade'],
                  subjectData['status'],
                  subjectData['icon'],
                  subjectData['color'],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(String subject, String grade, String status, IconData icon, Color color) {
    return Container(
      width: 120, // fixed width for uniform look
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            grade,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
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
