import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'class_evaluation_report_screen.dart';
import 'student_evaluation_detail_screen.dart';

class AcademicEvaluationScreen extends StatefulWidget {
  const AcademicEvaluationScreen({super.key});

  @override
  State<AcademicEvaluationScreen> createState() =>
      _AcademicEvaluationScreenState();
}

class _AcademicEvaluationScreenState
    extends State<AcademicEvaluationScreen> {
  // ---------- state ----------
  bool _isLoading = true;
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClassData;
  String _selectedPeriod = '1st Quarter';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _allScores = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  Map<String, dynamic>? _assessmentSetup;

  static const _periods = [
    '1st Quarter',
    '2nd Quarter',
    '3rd Quarter',
    '4th Quarter'
  ];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    final db = DatabaseHelper();
    // Admin sees all classes
    final classes = await db.getSubjectClasses();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _selectedClassData = classes.isNotEmpty ? classes.first : null;
    });
    await _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    if (_selectedClassData == null) {
      setState(() { _students = []; _allScores = []; _isLoading = false; });
      return;
    }
    setState(() => _isLoading = true);
    final db = DatabaseHelper();
    final grade = _selectedClassData!['grade_level'].toString();
    final section = _selectedClassData!['section_name'].toString();
    final subjectCode = _selectedClassData!['subject_code'].toString();

    final students = await db.getStudentsBySection(grade, section);
    final scores = await db.getScoresForClass(
      subjectCode: subjectCode,
      sectionName: section,
      gradeLevel: grade,
      gradingPeriod: _selectedPeriod,
    );
    final setup = await db.getAssessmentSetup(
      subjectCode: subjectCode,
      sectionName: section,
      gradeLevel: grade,
      gradingPeriod: _selectedPeriod,
    );
    final attendance = await db.getAttendanceForClass('$grade - $section');

    setState(() {
      _students = students;
      _allScores = scores;
      _assessmentSetup = setup;
      _attendanceRecords = attendance;
      _isLoading = false;
    });
  }

  int get _totalClassDays {
    final uniqueDates = _attendanceRecords.map((r) => r['date'].toString()).toSet();
    return uniqueDates.length;
  }

  double _attendancePct(String studentId) {
    final studentAtt = _attendanceRecords.where((r) => r['student_id'].toString() == studentId).toList();
    final totalDays = _totalClassDays;
    if (totalDays == 0) return 0.0;
    
    double points = 0.0;
    for (final record in studentAtt) {
      final status = record['status']?.toString() ?? '';
      if (status == 'Present' || status == 'Excused') {
        points += 1.0;
      } else if (status == 'Late') {
        points += 0.5;
      }
    }
    return (points / totalDays) * 100;
  }

  double _computeGrade(String studentId) {
    if (_assessmentSetup != null) {
      final wQuiz = (_assessmentSetup!['quiz_weight'] as num?)?.toDouble() ?? 20;
      final wAssignment = (_assessmentSetup!['assignment_weight'] as num?)?.toDouble() ?? 15;
      final wActivity = (_assessmentSetup!['activity_weight'] as num?)?.toDouble() ?? 20;
      final wProject = (_assessmentSetup!['project_weight'] as num?)?.toDouble() ?? 15;
      final wExam = (_assessmentSetup!['exam_weight'] as num?)?.toDouble() ?? 30;
      final wAttendance = (_assessmentSetup!['attendance_weight'] as num?)?.toDouble() ?? 0;

      final qAvg = _categoryAvg(studentId, 'Quiz');
      final asgAvg = _categoryAvg(studentId, 'Assignment');
      final actAvg = _categoryAvg(studentId, 'Activity');
      final prjAvg = _categoryAvg(studentId, 'Project');
      final exmAvg = _categoryAvg(studentId, 'Exam');
      final attAvg = _attendancePct(studentId);

      return (qAvg * (wQuiz / 100)) +
             (asgAvg * (wAssignment / 100)) +
             (actAvg * (wActivity / 100)) +
             (prjAvg * (wProject / 100)) +
             (exmAvg * (wExam / 100)) +
             (attAvg * (wAttendance / 100));
    }

    final s = _allScores.where((r) => r['student_id'].toString() == studentId).toList();
    if (s.isEmpty) return 0.0;
    double total = 0, max = 0;
    for (final r in s) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max   += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    if (max == 0) return 0.0;
    return (total / max) * 100;
  }

  double _categoryAvg(String studentId, String category) {
    final s = _allScores.where((r) =>
      r['student_id'].toString() == studentId &&
      r['category'].toString().toLowerCase() == category.toLowerCase()).toList();
    if (s.isEmpty) return 0.0;
    double total = 0, max = 0;
    for (final r in s) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max   += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    if (max == 0) return 0.0;
    return (total / max) * 100;
  }

  double _classCategoryAvg(String category) {
    final s = _allScores.where((r) => r['category'].toString().toLowerCase() == category.toLowerCase()).toList();
    if (s.isEmpty) return 0.0;
    double total = 0, max = 0;
    for (final r in s) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max   += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    if (max == 0) return 0.0;
    return (total / max) * 100;
  }

  double _classAttendanceAvg() {
    if (_students.isEmpty) return 0.0;
    double total = 0.0;
    for (final s in _students) {
      total += _attendancePct(s['student_id'].toString());
    }
    return total / _students.length;
  }

  String get _classLabel {
    if (_selectedClassData == null) return 'No class';
    return '${_selectedClassData!["grade_level"]} - ${_selectedClassData!["section_name"]} (${_selectedClassData!["subject_name"]})';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_classes.isEmpty) {
      return const Center(
        child: Text('No classes found in the system.',
            style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    final gradeList = _students.where((s) {
      final q = _searchQuery.toLowerCase();
      return q.isEmpty ||
          s['name'].toString().toLowerCase().contains(q) ||
          s['student_id'].toString().toLowerCase().contains(q);
    }).toList();

    final int totalStudents = _students.length;
    final passed = _students.where((s) => _computeGrade(s['student_id'].toString()) >= 75).length;
    final atRisk = _students.where((s) {
      final g = _computeGrade(s['student_id'].toString());
      return g > 0 && g < 75;
    }).length;
    double classAvg = 0;
    if (totalStudents > 0) {
      classAvg = _students.fold(0.0, (sum, s) => sum + _computeGrade(s['student_id'].toString())) / totalStudents;
    }

    final List<Map<String, dynamic>> studentGradesForReport = gradeList.map((s) {
      final grade = _computeGrade(s['student_id'].toString());
      return {
        'name': s['name'].toString(),
        'id': s['student_id'].toString(),
        'grade': grade,
        'isPassed': grade >= 75,
      };
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 24),

            const Text(
              'Academic Evaluation',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2B4C),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'View overall student performance across all classes',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blueGrey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildDropdownCard(
                  icon: Icons.class_,
                  iconColor: const Color(0xFF3B82F6),
                  label: 'Class',
                  value: _classLabel,
                  items: _classes.map((c) =>
                    '${c["grade_level"]} - ${c["section_name"]} (${c["subject_name"]})'
                  ).toList(),
                  onChanged: (val) {
                    final match = _classes.firstWhere((c) =>
                      '${c["grade_level"]} - ${c["section_name"]} (${c["subject_name"]})' == val,
                      orElse: () => _classes.first);
                    setState(() => _selectedClassData = match);
                    _loadStudentData();
                  },
                ),
                _buildDropdownCard(
                  icon: Icons.calendar_today,
                  iconColor: const Color(0xFF3B82F6),
                  label: 'Grading Period',
                  value: _selectedPeriod,
                  items: _periods.toList(),
                  onChanged: (val) {
                    setState(() => _selectedPeriod = val!);
                    _loadStudentData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard(
                      constraints.maxWidth,
                      icon: Icons.people,
                      iconBgColor: const Color(0xFFE0E7FF),
                      iconColor: const Color(0xFF4F46E5),
                      title: 'Total Students',
                      value: '$totalStudents',
                      trend: '',
                      trendColor: const Color(0xFF10B981),
                      subtitle: 'enrolled',
                    ),
                    _buildStatCard(
                      constraints.maxWidth,
                      icon: Icons.check_circle,
                      iconBgColor: const Color(0xFFD1FAE5),
                      iconColor: const Color(0xFF10B981),
                      title: 'Passed',
                      value: '$passed',
                      trend: totalStudents > 0 ? '${(passed / totalStudents * 100).toStringAsFixed(0)}%' : '0%',
                      trendColor: const Color(0xFF111827),
                      subtitle: ' of class',
                    ),
                    _buildStatCard(
                      constraints.maxWidth,
                      icon: Icons.warning_amber_rounded,
                      iconBgColor: const Color(0xFFFFEDD5),
                      iconColor: const Color(0xFFF59E0B),
                      title: 'At-Risk',
                      value: '$atRisk',
                      trend: totalStudents > 0 ? '${(atRisk / totalStudents * 100).toStringAsFixed(0)}%' : '0%',
                      trendColor: const Color(0xFF111827),
                      subtitle: ' of class',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            _buildClassAverageCard(
              classAvg: classAvg,
              quizAvg: _classCategoryAvg('Quiz'),
              asgAvg: _classCategoryAvg('Assignment'),
              actAvg: _classCategoryAvg('Activity'),
              prjAvg: _classCategoryAvg('Project'),
              examAvg: _classCategoryAvg('Exam'),
              attAvg: _classAttendanceAvg(),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClassEvaluationReportScreen(
                        className: '${_selectedClassData!["grade_level"]} - ${_selectedClassData!["section_name"]}',
                        subjectCode: _selectedClassData!["subject_name"]?.toString() ?? 'Subject',
                        gradingPeriod: _selectedPeriod,
                        studentGrades: studentGradesForReport,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('View Detailed Class Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F52BA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Student Evaluation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
                Text(
                  '${gradeList.length} student${gradeList.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (gradeList.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No students found. Enroll students or encode scores first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              )
            else
              ...gradeList.map((student) {
                final sid = student['student_id'].toString();
                final grade = _computeGrade(sid);
                final quizPct = _categoryAvg(sid, 'Quiz');
                final examPct = _categoryAvg(sid, 'Exam');
                final isPassed = grade >= 75;
                final hasScores = grade > 0;
                return _buildStudentCard(
                  name: student['name'].toString(),
                  section: student['section'].toString(),
                  id: sid,
                  avatarUrl: '',
                  overallGrade: hasScores ? '${grade.toStringAsFixed(1)}%' : 'N/A',
                  gradeColor: !hasScores
                      ? Colors.grey
                      : isPassed
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFEF4444),
                  status: !hasScores ? 'No Data' : isPassed ? 'Passed' : 'At-Risk',
                  statusColor: !hasScores
                      ? Colors.grey
                      : isPassed
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                  statusBgColor: !hasScores
                      ? Colors.grey.shade100
                      : isPassed
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2),
                  quizAvg: quizPct > 0 ? '${quizPct.toStringAsFixed(0)}%' : '--',
                  examAvg: examPct > 0 ? '${examPct.toStringAsFixed(0)}%' : '--',
                  quizColor: quizPct > 0 && quizPct < 75
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF3B82F6),
                  examColor: examPct > 0 && examPct < 75
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF3B82F6),
                  onViewDetails: () {
                    final studentScores = _allScores
                        .where((r) => r['student_id'].toString() == sid)
                        .toList();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentEvaluationDetailScreen(
                          student: student,
                          subjectName: _selectedClassData?["subject_name"]?.toString() ?? 'Subject',
                          gradingPeriod: _selectedPeriod,
                          scores: studentScores,
                          assessmentSetup: _assessmentSetup,
                          attendancePct: _attendancePct(sid),
                        ),
                      ),
                    );
                  },
                );
              }),

            const SizedBox(height: 16),

            _buildAttentionCard(atRisk: atRisk, totalStudents: totalStudents),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search students by name or ID...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDropdownCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    items: items
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    double maxWidth, {
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
    required String trend,
    required Color trendColor,
    required String subtitle,
  }) {
    double cardWidth = (maxWidth - 32) / 3;
    if (maxWidth < 800 && maxWidth > 500) {
      cardWidth = (maxWidth - 16) / 2;
    } else if (maxWidth <= 500) {
      cardWidth = maxWidth;
    }

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconBgColor,
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: title == 'At-Risk'
                        ? const Color(0xFFF59E0B)
                        : (title == 'Passed'
                            ? const Color(0xFF10B981)
                            : const Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11, fontFamily: 'Roboto'),
                    children: [
                      TextSpan(
                        text: trend,
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: subtitle,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassAverageCard({
    required double classAvg,
    required double quizAvg,
    required double asgAvg,
    required double actAvg,
    required double prjAvg,
    required double examAvg,
    required double attAvg,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 16,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Class Average',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2B4C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      classAvg > 0 ? '${classAvg.toStringAsFixed(1)}%' : 'N/A',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Current Grading Period',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(
                  height: 80,
                  width: 150,
                  child: CustomPaint(
                    painter: _MockChartPainter(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildComponentAvg('Quizzes', quizAvg > 0 ? '${quizAvg.toStringAsFixed(1)}%' : '--', Icons.help_outline, const Color(0xFF3B82F6)),
                    _buildComponentAvg('Assignments', asgAvg > 0 ? '${asgAvg.toStringAsFixed(1)}%' : '--', Icons.description_outlined, const Color(0xFF10B981)),
                    _buildComponentAvg('Activities', actAvg > 0 ? '${actAvg.toStringAsFixed(1)}%' : '--', Icons.star_border, const Color(0xFFF59E0B)),
                    _buildComponentAvg('Project', prjAvg > 0 ? '${prjAvg.toStringAsFixed(1)}%' : '--', Icons.folder_outlined, const Color(0xFF8B5CF6)),
                    _buildComponentAvg('Exam', examAvg > 0 ? '${examAvg.toStringAsFixed(1)}%' : '--', Icons.assignment_outlined, const Color(0xFFF97316)),
                    _buildComponentAvg('Attendance', attAvg > 0 ? '${attAvg.toStringAsFixed(1)}%' : '--', Icons.assignment_turned_in, const Color(0xFF0DCAF0)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentAvg(String title, String score, IconData icon, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          score,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Icon(icon, color: color, size: 20),
      ],
    );
  }

  Widget _buildStudentCard({
    required String name,
    required String section,
    required String id,
    required String avatarUrl,
    required String overallGrade,
    required Color gradeColor,
    required String status,
    required Color statusColor,
    required Color statusBgColor,
    required String quizAvg,
    required String examAvg,
    Color quizColor = const Color(0xFF3B82F6),
    Color examColor = const Color(0xFF3B82F6),
    VoidCallback? onViewDetails,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            bool isSmall = constraints.maxWidth < 500;
            if (isSmall) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE0E7FF),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2B4C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$section  •  LRN: $id',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overall Grade',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            overallGrade,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: gradeColor,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE0E7FF),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2B4C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$section  •  LRN: $id',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Overall Grade',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overallGrade,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: gradeColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            );
          }),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildPill('Quiz Avg.', quizAvg, quizColor),
              _buildPill('Exam Avg.', examAvg, examColor),
              _buildOutlinedButton(Icons.visibility_outlined, 'View Details', const Color(0xFF3B82F6), onTap: onViewDetails),
              _buildOutlinedButton(Icons.chat_bubble_outline, 'Remarks', const Color(0xFF3B82F6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlinedButton(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionCard({required int atRisk, required int totalStudents}) {
    final below60 = _students.where((s) => _computeGrade(s['student_id'].toString()) > 0 && _computeGrade(s['student_id'].toString()) < 60).length;
    final between60and75 = _students.where((s) {
      final g = _computeGrade(s['student_id'].toString());
      return g >= 60 && g < 75;
    }).length;
    if (atRisk == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        bool isSmall = constraints.maxWidth < 600;
        return Flex(
          direction: isSmall ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: isSmall ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (!isSmall) ...[
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B), size: 28),
              ),
              const SizedBox(width: 16),
            ],
            if (isSmall)
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Students Needing Attention',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2B4C),
                          ),
                        ),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, fontFamily: 'Roboto'),
                            children: [
                              TextSpan(
                                text: '$atRisk',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: ' students below 75%',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (!isSmall)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Students Needing Attention',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2B4C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, fontFamily: 'Roboto'),
                        children: [
                          TextSpan(
                            text: '$atRisk',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' students are performing below 75%',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {},
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View At-Risk Students',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 18, color: Color(0xFF3B82F6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (isSmall) const SizedBox(height: 16),
            if (isSmall)
              InkWell(
                onTap: () {},
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View At-Risk Students',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 18, color: Color(0xFF3B82F6)),
                  ],
                ),
              ),
            if (isSmall) const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBreakdownRow(const Color(0xFFEF4444), 'Below 60%', '$below60'),
                  const SizedBox(height: 8),
                  _buildBreakdownRow(const Color(0xFFF59E0B), '60% – 74%', '$between60and75'),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (!isSmall)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.people, color: Color(0xFFF59E0B), size: 24),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildBreakdownRow(Color color, String label, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(width: 16),
        Text(
          count,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A2B4C),
          ),
        ),
      ],
    );
  }
}

class _MockChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
        size.width * 0.2, size.height * 0.8, size.width * 0.4, size.height * 0.6);
    path.quadraticBezierTo(
        size.width * 0.6, size.height * 0.4, size.width * 0.8, size.height * 0.3);
    path.quadraticBezierTo(
        size.width * 0.9, size.height * 0.25, size.width, size.height * 0.1);

    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width, size.height * 0.1), 4, dotPaint);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.2),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
