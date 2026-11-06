import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'announcement_management_screen.dart';
import 'student_grades_view_screen.dart';
import 'student_schedule_screen.dart';
import 'student_attendance_view_screen.dart';
import 'shared_profile_screen.dart';

import '../database_helper.dart';
import '../utils/avatar_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/role_theme.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String username; // The student's email/username
  const StudentDashboardScreen({super.key, this.username = 'student'});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  String _selectedMenu = 'Dashboard';
  String _studentName = '';
  String _gradeLevel = '';
  String _sectionName = '';
  String _studentId = '';
  String? _profilePicture;
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

  Future<void> _fetchDashboardData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }
    try {
      final dbHelper = DatabaseHelper();
    
      // Fetch Name & Details
      final student = await dbHelper.getStudentByEmail(widget.username);
      final gradeLevel = student?['grade_level']?.toString() ?? '';
      final sectionName = student?['section']?.toString() ?? '';
      final sid = student?['student_id']?.toString() ?? '';
      const gradingPeriod = '1st Term'; // Assuming first quarter for dashboard view

      _gradeLevel = gradeLevel;
      _sectionName = sectionName;
      _studentId = sid;

      if (student != null && student['name'] != null) {
        _studentName = student['name'];
      } else {
        _studentName = widget.username;
      }

      String? photo = student?['profile_picture']?.toString();
      if (photo == null || photo.trim().isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          photo = prefs.getString('profile_pic_student_${widget.username}') ??
              prefs.getString('profile_pic_student_$_studentId');
        } catch (_) {}
      }
      _profilePicture = photo;

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
        final subjAttendance = attendanceRecords.where((r) {
          final className = r['class_name']?.toString() ?? '';
          return className.contains(subjectCode);
        }).toList();
        
        double classAttendancePct = 100.0;
        if (subjAttendance.isNotEmpty) {
          int subjPresentCount = subjAttendance.where((r) => r['status'] == 'Present' || r['status'] == 'Late').length;
          classAttendancePct = (subjPresentCount / subjAttendance.length) * 100;
        }

        // Filter scores
        final periodAliases = DatabaseHelper.getPeriodAliases(gradingPeriod);
        var subjectScores = scores.where((s) => s['subject_code'] == subjectCode && periodAliases.contains(s['grading_period']?.toString())).toList();
        
        double grade = 0.0;

        if (subjectScores.isNotEmpty) {
          // Fetch Assessment Setup
          final setup = await dbHelper.getAssessmentSetup(
            subjectCode: subjectCode,
            sectionName: sectionName,
            gradeLevel: gradeLevel,
            gradingPeriod: gradingPeriod,
          );
          final transTable = await dbHelper.getTransmutationTable(subjectCode, sectionName);

          if (setup != null) {
            double earned = 0.0;
            double totalWeight = 0.0;
            final wWW = (setup['ww_weight'] as num?)?.toDouble() ?? 30;
            final wPT = (setup['pt_weight'] as num?)?.toDouble() ?? 50;
            final wTE = (setup['te_weight'] as num?)?.toDouble() ?? 20;
            final wAttendance = (setup['attendance_weight'] as num?)?.toDouble() ?? 0;

            double categoryAvg(String cat) {
              int maxItems = 999;
              if (cat.toLowerCase() == 'written works') maxItems = (setup['ww_items'] as num?)?.toInt() ?? 999;
              else if (cat.toLowerCase() == 'performance tasks') maxItems = (setup['pt_items'] as num?)?.toInt() ?? 999;
              else if (cat.toLowerCase() == 'term exams') maxItems = (setup['te_items'] as num?)?.toInt() ?? 999;

              var filtered = subjectScores.where((r) {
                final itemCat = r['category']?.toString() ?? '';
                final itemLabel = r['item_label']?.toString() ?? '';
                if (itemCat != cat) return false;
                int? num = int.tryParse(itemLabel.replaceAll(RegExp(r'[^0-9]'), ''));
                if (num != null && num > maxItems) return false;
                return true;
              }).toList();

              if (filtered.isEmpty) return -1.0;
              double t = 0, m = 0;
              for (var r in filtered) {
                t += (r['score'] as num?)?.toDouble() ?? 0;
                m += (r['total_score'] as num?)?.toDouble() ?? 0;
              }
              if (m == 0) return 0.0;
              return (t / m) * 100;
            }

            final wwAvg = categoryAvg('Written Works');
            if (wwAvg >= 0 && wWW > 0) { earned += wwAvg * (wWW / 100); totalWeight += (wWW / 100); }
            final ptAvg = categoryAvg('Performance Tasks');
            if (ptAvg >= 0 && wPT > 0) { earned += ptAvg * (wPT / 100); totalWeight += (wPT / 100); }
            final teAvg = categoryAvg('Term Exams');
            if (teAvg >= 0 && wTE > 0) { earned += teAvg * (wTE / 100); totalWeight += (wTE / 100); }
            
            if (wAttendance > 0) { earned += classAttendancePct * (wAttendance / 100); totalWeight += (wAttendance / 100); }

            if (totalWeight > 0) {
              double initialGrade = earned / totalWeight;
              grade = dbHelper.transmuteGrade(initialGrade, customTable: transTable);
            } else {
              grade = 0.0;
            }
          } else {
            double total = 0, max = 0;
            for (final r in subjectScores) {
              total += (r['score'] as num?)?.toDouble() ?? 0;
              max += (r['total_score'] as num?)?.toDouble() ?? 0;
            }
            if (max > 0) {
              double initialGrade = (total / max) * 100;
              grade = dbHelper.transmuteGrade(initialGrade, customTable: transTable);
            }
          }

          sumOfAverages += grade;
          validSubjects++;
        }

        String status = 'N/A';
        Color color = Colors.grey;
        if (grade >= 90) {
          status = 'Passed';
          color = const Color(0xFF0284C7);
        } else if (grade >= 75) {
          status = 'Passed';
          color = const Color(0xFF059669);
        } else if (grade > 0) {
          status = 'At-Risk';
          color = const Color(0xFFDC2626);
        }

        IconData getIcon(String sub) {
          String s = sub.toLowerCase();
          if (s.contains('math')) return Icons.calculate_rounded;
          if (s.contains('sci')) return Icons.science_rounded;
          if (s.contains('eng')) return Icons.menu_book_rounded;
          if (s.contains('fil')) return Icons.wb_sunny_rounded;
          return Icons.school_rounded;
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirm Logout',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of your student account?',
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Logout',
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
    final roleTheme = RoleTheme.studentTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
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
        backgroundColor: roleTheme.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: roleTheme.primary,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: roleTheme.appBarGradient),
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 22,
                width: 22,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, _, _) => const Icon(Icons.school, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(fontSize: 17, letterSpacing: 0.2),
                  children: [
                    const TextSpan(text: 'Notify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const TextSpan(text: 'ED', style: TextStyle(color: Color(0xFFBAE3FF), fontWeight: FontWeight.w900)),
                    TextSpan(
                      text: _selectedMenu == 'Dashboard' ? '  •  Student Portal' : '  •  $_selectedMenu',
                      style: const TextStyle(color: Color(0xFFE2F1FC), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                child: AvatarUtils.buildAvatar(
                  photo: _profilePicture,
                  name: _studentName,
                  radius: 18,
                  foregroundColor: roleTheme.primary,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: roleTheme.drawerBackground,
          child: SafeArea(
            child: Column(
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
                              RoleTheme.buildRoleBadge('student', fontSize: 9.5),
                            ],
                          ),
                        ],
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
                        icon: Icons.home_rounded,
                        isSelected: _selectedMenu == 'Dashboard',
                        onTap: () => _onMenuTap('Dashboard', fromDrawer: true),
                      ),
                      _buildMenuItem(
                        title: 'My Grades',
                        icon: Icons.grade_rounded,
                        isSelected: _selectedMenu == 'My Grades',
                        onTap: () => _onMenuTap('My Grades', fromDrawer: true),
                      ),
                      _buildMenuItem(
                        title: 'Class Schedule',
                        icon: Icons.schedule_rounded,
                        isSelected: _selectedMenu == 'Class Schedule',
                        onTap: () => _onMenuTap('Class Schedule', fromDrawer: true),
                      ),
                      _buildMenuItem(
                        title: 'Attendance',
                        icon: Icons.assignment_turned_in_rounded,
                        isSelected: _selectedMenu == 'Attendance',
                        onTap: () => _onMenuTap('Attendance', fromDrawer: true),
                      ),
                      _buildMenuItem(
                        title: 'Announcements',
                        icon: Icons.campaign_rounded,
                        isSelected: _selectedMenu == 'Announcements',
                        onTap: () => _onMenuTap('Announcements', fromDrawer: true),
                      ),
                      _buildMenuItem(
                        title: 'Profile',
                        icon: Icons.person_rounded,
                        isSelected: _selectedMenu == 'Profile',
                        onTap: () => _onMenuTap('Profile', fromDrawer: true),
                      ),
                      _buildMenuItem(
                        title: 'Settings',
                        icon: Icons.settings_rounded,
                        isSelected: _selectedMenu == 'Settings',
                        onTap: () => _onMenuTap('Settings', fromDrawer: true),
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
                      final shouldLogout = await _showLogoutDialog();
                      if (shouldLogout && mounted) {
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
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedMenu == 'Settings') {
      return SettingsScreen(username: widget.username, role: 'student');
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
        color: isSelected ? RoleTheme.studentTheme.drawerSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        dense: true,
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _fetchDashboardData(isRefresh: true),
      color: RoleTheme.studentTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Card (Good Day, Student Name)
            _buildGreetingCard(),
            const SizedBox(height: 24),

            // 2. Academic Overview
            const Text(
              'Academic Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                return isNarrow
                    ? Column(
                        children: [
                          _buildOverviewCard('Overall Average', _overallAverage > 0 ? '${_overallAverage.toStringAsFixed(1)}%' : 'N/A', Icons.emoji_events_rounded, const Color(0xFFD97706)),
                          const SizedBox(height: 10),
                          _buildOverviewCard('Attendance Rate', _attendancePercentage > 0 || _hasAttendance ? '${_attendancePercentage.toStringAsFixed(0)}%' : 'N/A', Icons.check_circle_rounded, const Color(0xFF059669)),
                          const SizedBox(height: 10),
                          _buildOverviewCard('Enrolled Subjects', '${_schedule.length} Subjects', Icons.menu_book_rounded, const Color(0xFF0284C7)),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _buildOverviewCard('Overall Average', _overallAverage > 0 ? '${_overallAverage.toStringAsFixed(1)}%' : 'N/A', Icons.emoji_events_rounded, const Color(0xFFD97706))),
                          const SizedBox(width: 14),
                          Expanded(child: _buildOverviewCard('Attendance Rate', _attendancePercentage > 0 || _hasAttendance ? '${_attendancePercentage.toStringAsFixed(0)}%' : 'N/A', Icons.check_circle_rounded, const Color(0xFF059669))),
                          const SizedBox(width: 14),
                          Expanded(child: _buildOverviewCard('Enrolled Subjects', '${_schedule.length} Subjects', Icons.menu_book_rounded, const Color(0xFF0284C7))),
                        ],
                      );
              },
            ),
            const SizedBox(height: 24),

            // 3. My Subjects
            _buildMySubjectsSection(),
            const SizedBox(height: 24),

            // 4. Today's Schedule
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Class Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (_schedule.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _onMenuTap('Class Schedule'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: const Text('Full Timetable'),
                    style: TextButton.styleFrom(
                      foregroundColor: RoleTheme.studentTheme.primary,
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_schedule.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_today_rounded, size: 32, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 12),
                    const Text('No classes scheduled for today', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 4),
                    const Text('Enjoy your free period or check your full timetable schedule.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ],
                ),
              )
            else
              ..._schedule.map((classData) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: _buildScheduleCard(
                    classData['time'] ?? 'TBA',
                    classData['subject_name'] ?? 'Unknown Subject',
                    classData['room'] ?? 'TBA',
                    isOngoing: false,
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    final name = _studentName.isNotEmpty ? _studentName : widget.username;
    final hasClassInfo = _gradeLevel.isNotEmpty || _sectionName.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: RoleTheme.studentTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: RoleTheme.studentTheme.primary.withValues(alpha: 0.35),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 28),
              ),
            ),
          ),
          Row(
            children: [
              // Student Profile Picture Avatar with glowing ring
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: AvatarUtils.buildAvatar(
                  photo: _profilePicture,
                  name: name,
                  radius: 34,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),

              // Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Tag: Good Day! + SY
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.waving_hand_rounded, color: Color(0xFFFFD54F), size: 12),
                              SizedBox(width: 5),
                              Text(
                                'Good Day!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'SY 2026-2027',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Student Full Name
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Grade & Section
                    if (hasClassInfo) ...[
                      Text(
                        '$_gradeLevel${_gradeLevel.isNotEmpty && _sectionName.isNotEmpty ? ' • ' : ''}$_sectionName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Bottom Badges: LRN & Term
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (_studentId.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'LRN: $_studentId',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '1st Term Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOngoing ? RoleTheme.studentTheme.primary : const Color(0xFFE2E8F0),
          width: isOngoing ? 1.8 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isOngoing
                  ? RoleTheme.studentTheme.primary.withValues(alpha: 0.1)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(height: 3),
                Text(
                  time.split(' - ').join('\n'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOngoing ? RoleTheme.studentTheme.primary : const Color(0xFF1E293B),
                    fontSize: 11.5,
                  ),
                ),
              ],
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      room.toLowerCase().startsWith('room') ? room : 'Room: $room',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isOngoing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: RoleTheme.studentTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Now in Class',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
              'My Enrolled Subjects',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _onMenuTap('My Grades');
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('View All Grades'),
              style: TextButton.styleFrom(
                foregroundColor: RoleTheme.studentTheme.primary,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
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
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMenuTap(String menu, {bool fromDrawer = false}) {
    setState(() {
      _selectedMenu = menu;
    });
    if (fromDrawer) {
      Navigator.pop(context); // Close the drawer
    }
    if (menu == 'Dashboard') {
      _fetchDashboardData(isRefresh: true);
    }
  }
}
