import '../services/ecr_validator.dart';
import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../utils/dialog_utils.dart';
import '../utils/avatar_utils.dart';
import 'class_evaluation_report_screen.dart';
import 'student_evaluation_detail_screen.dart';
import '../services/early_warning_service.dart';

class AcademicEvaluationScreen extends StatefulWidget {
  final String username;
  final String role;
  const AcademicEvaluationScreen({super.key, required this.username, required this.role});

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
  bool _showOnlyAtRisk = false;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _allScores = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  Map<String, dynamic>? _assessmentSetup;

  static const _periods = [
    '1st Quarter',
    '2nd Quarter',
    '3rd Quarter',
    '4th Quarter',
    '1st Term',
    '2nd Term',
    '3rd Term',
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
    
    if (widget.role == 'admin') {
      // Admin sees all classes
      final classes = await db.getSubjectClasses();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _selectedClassData = classes.isNotEmpty ? classes.first : null;
      });
      await _loadStudentData();
    } else if (widget.role == 'teacher') {
      // Teacher sees only assigned classes
      final teacher = await db.getTeacherByEmail(widget.username);
      if (teacher == null) { 
        if (mounted) setState(() => _isLoading = false); 
        return; 
      }
      final classes = await db.getSubjectClassesByTeacher(teacher['name'].toString());
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _selectedClassData = classes.isNotEmpty ? classes.first : null;
      });
      await _loadStudentData();
    }
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
    final transTable = await db.getTransmutationTable(subjectCode, section);
    DatabaseHelper.setActiveTransmutationTable(transTable);
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

  bool _isStudentMatch(dynamic scoreSid, String targetSid) {
    final s1 = (scoreSid?.toString() ?? '').replaceAll(RegExp(r'[\s\-]'), '').toLowerCase();
    final s2 = targetSid.replaceAll(RegExp(r'[\s\-]'), '').toLowerCase();
    return s1.isNotEmpty && s1 == s2;
  }

  bool _isStudentOrNameMatch(Map<String, dynamic> row, String targetSid, [String? targetName]) {
    if (_isStudentMatch(row['student_id'], targetSid)) return true;
    if (targetName != null && targetName.isNotEmpty) {
      final n1 = (row['student_name']?.toString() ?? '').toLowerCase().trim();
      final n2 = targetName.toLowerCase().trim();
      if (n1.isNotEmpty && (n1 == n2 || EcrValidator.normalizeFuzzyName(n1) == EcrValidator.normalizeFuzzyName(n2))) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _categoryStats(String studentId, String category, [String? studentName]) {
    final s = _allScores.where((r) => 
      _isStudentOrNameMatch(r, studentId, studentName) && 
      r['category'].toString().toLowerCase() == category.toLowerCase()
    ).toList();

    if (s.isEmpty) return {'earned': 0.0, 'total': 0.0, 'pct': 0.0, 'hasData': false};
    double total = 0, max = 0;
    for (final r in s) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max   += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    double pct = max > 0 ? (total / max) * 100 : 0.0;
    return {'earned': total, 'total': max, 'pct': pct, 'hasData': true};
  }

  bool _studentHasScores(String studentId, [String? studentName]) {
    return _allScores.any((r) => _isStudentOrNameMatch(r, studentId, studentName));
  }

  double _computeGrade(String studentId, [String? studentName]) {
    if (!_studentHasScores(studentId, studentName)) return 0.0;

    final wwStats = _categoryStats(studentId, 'Written Works', studentName);
    final ptStats = _categoryStats(studentId, 'Performance Tasks', studentName);
    final teStats = _categoryStats(studentId, 'Term Exams', studentName);
    final attAvg = _attendancePct(studentId);

    // Require at least one academic assessment category to have data
    final hasAssessmentData = wwStats['hasData'] == true || ptStats['hasData'] == true || teStats['hasData'] == true;
    if (!hasAssessmentData) return 0.0;

    if (_assessmentSetup != null) {
      final wWW = (_assessmentSetup!['ww_weight'] as num?)?.toDouble() ?? 30;
      final wPT = (_assessmentSetup!['pt_weight'] as num?)?.toDouble() ?? 50;
      final wTE = (_assessmentSetup!['te_weight'] as num?)?.toDouble() ?? 20;
      final wAttendance = (_assessmentSetup!['attendance_weight'] as num?)?.toDouble() ?? 0;

      double totalWeight = 0;
      double earned = 0;

      if (wwStats['hasData'] == true) { earned += (wwStats['pct'] as double) * (wWW / 100); totalWeight += (wWW / 100); }
      if (ptStats['hasData'] == true) { earned += (ptStats['pct'] as double) * (wPT / 100); totalWeight += (wPT / 100); }
      if (teStats['hasData'] == true) { earned += (teStats['pct'] as double) * (wTE / 100); totalWeight += (wTE / 100); }
      
      if (wAttendance > 0) {
        earned += attAvg * (wAttendance / 100);
        totalWeight += (wAttendance / 100);
      }

      if (totalWeight == 0) return 0.0;
      double initialGrade = earned / totalWeight;
      return DatabaseHelper().transmuteGrade(initialGrade);
    }

    final s = _allScores.where((r) => _isStudentOrNameMatch(r, studentId, studentName)).toList();
    if (s.isEmpty) return 0.0;
    double total = 0, max = 0;
    for (final r in s) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max   += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    if (max == 0) return 0.0;
    double initialGrade = (total / max) * 100;
    return DatabaseHelper().transmuteGrade(initialGrade);
  }

  double _categoryAvg(String studentId, String category, [String? studentName]) {
    final stats = _categoryStats(studentId, category, studentName);
    return stats['pct'] as double;
  }

  double _classCategoryAvg(String category) {
    final s = _allScores.where((r) => 
      r['category'].toString().toLowerCase() == category.toLowerCase()
    ).toList();

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

    final subjCode = _selectedClassData?['subject_code']?.toString() ?? '';
    final ewResults = EarlyWarningService.evaluateClassScores(
      students: _students,
      allScores: _allScores,
      subjectCode: subjCode,
      gradingPeriod: _selectedPeriod,
    );

    final gradeList = _students.where((s) {
      final sid = s['student_id'].toString();
      final sName = s['name']?.toString();
      final ew = ewResults[sid];
      final isEwAtRisk = ew?.isAtRisk ?? false;
      final g = _computeGrade(sid, sName);
      final hasScores = _studentHasScores(sid, sName);
      final isGradeAtRisk = hasScores && g < 75;

      if (_showOnlyAtRisk) {
        if (!isEwAtRisk && !isGradeAtRisk) return false;
      }
      final q = _searchQuery.toLowerCase();
      return q.isEmpty ||
          s['name'].toString().toLowerCase().contains(q) ||
          s['student_id'].toString().toLowerCase().contains(q);
    }).toList();

    final int totalStudents = _students.length;
    final evaluatedStudents = _students.where((s) {
      final sid = s['student_id'].toString();
      final sName = s['name']?.toString();
      return _studentHasScores(sid, sName);
    }).toList();
    final int totalEvaluated = evaluatedStudents.length;

    final atRisk = evaluatedStudents.where((s) {
      final sid = s['student_id'].toString();
      final sName = s['name']?.toString();
      final ew = ewResults[sid];
      final g = _computeGrade(sid, sName);
      return (ew?.isAtRisk ?? false) || g < 75;
    }).length;

    final passed = evaluatedStudents.where((s) {
      final sid = s['student_id'].toString();
      final sName = s['name']?.toString();
      final g = _computeGrade(sid, sName);
      return g >= 75;
    }).length;

    double classAvg = 0;
    if (totalEvaluated > 0) {
      classAvg = evaluatedStudents.fold(0.0, (sum, s) =>
        sum + _computeGrade(s['student_id'].toString(), s['name']?.toString())
      ) / totalEvaluated;
    }

    final List<Map<String, dynamic>> studentGradesForReport = gradeList.map((s) {
      final sid = s['student_id'].toString();
      final sName = s['name']?.toString();
      final hasScores = _studentHasScores(sid, sName);
      final grade = hasScores ? _computeGrade(sid, sName) : 0.0;
      return {
        'name': s['name'].toString(),
        'id': sid,
        'grade': grade,
        'isPassed': hasScores && grade >= 75,
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh data from database',
                  icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
                  onPressed: _loadStudentData,
                ),
              ],
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
                      trend: totalEvaluated > 0 ? '${(passed / totalEvaluated * 100).toStringAsFixed(0)}%' : '--',
                      trendColor: const Color(0xFF111827),
                      subtitle: totalEvaluated > 0 ? ' of $totalEvaluated evaluated' : 'no scores recorded',
                    ),
                    _buildStatCard(
                      constraints.maxWidth,
                      icon: Icons.warning_amber_rounded,
                      iconBgColor: const Color(0xFFFFEDD5),
                      iconColor: const Color(0xFFF59E0B),
                      title: 'At-Risk',
                      value: '$atRisk',
                      trend: totalEvaluated > 0 ? '${(atRisk / totalEvaluated * 100).toStringAsFixed(0)}%' : '--',
                      trendColor: const Color(0xFF111827),
                      subtitle: totalEvaluated > 0 ? ' of $totalEvaluated evaluated' : 'no scores recorded',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            _buildClassAverageCard(
              classAvg: classAvg,
              wwAvg: _classCategoryAvg('Written Works'),
              ptAvg: _classCategoryAvg('Performance Tasks'),
              teAvg: _classCategoryAvg('Term Exams'),
              attAvg: _classAttendanceAvg(),
            ),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWeb = constraints.maxWidth >= 600;
                return Align(
                  alignment: isWeb ? Alignment.centerLeft : Alignment.center,
                  child: SizedBox(
                    width: isWeb ? 300 : double.infinity,
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
                );
              },
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
                final sName = student['name']?.toString();
                final hasScores = _studentHasScores(sid, sName);
                final grade = hasScores ? _computeGrade(sid, sName) : 0.0;
                final wwStats = _categoryStats(sid, 'Written Works', sName);
                final ptStats = _categoryStats(sid, 'Performance Tasks', sName);
                final teStats = _categoryStats(sid, 'Term Exams', sName);
                final double wwPct = wwStats['pct'] as double;
                final double ptPct = ptStats['pct'] as double;
                final double tePct = teStats['pct'] as double;
                final isPassed = hasScores && grade >= 75;
                final ew = ewResults[sid];
                final isEwAtRisk = hasScores && (ew?.isAtRisk ?? false);
                final atRiskStatus = isEwAtRisk ? ew!.shortBadgeText : 'At-Risk';
                final isFlagged = isEwAtRisk || (hasScores && !isPassed);

                String formatScorePill(Map<String, dynamic> stats) {
                  if (stats['hasData'] != true) return '--';
                  final earned = stats['earned'] as double;
                  final total = stats['total'] as double;
                  final pct = stats['pct'] as double;
                  final earnedStr = earned % 1 == 0 ? earned.toInt().toString() : earned.toStringAsFixed(1);
                  final totalStr = total.toInt().toString();
                  return '$earnedStr/$totalStr (${pct.toStringAsFixed(0)}%)';
                }

                return _buildStudentCard(
                  name: student['name'].toString(),
                  section: student['section'].toString(),
                  id: sid,
                  avatarUrl: student['profile_picture']?.toString() ?? '',
                  overallGrade: hasScores ? '${grade.toStringAsFixed(1)}%' : 'N/A',
                  gradeColor: !hasScores
                      ? Colors.grey
                      : !isFlagged
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFEF4444),
                  status: !hasScores
                      ? 'No Data'
                      : (isFlagged ? atRiskStatus : 'Passed'),
                  statusColor: !hasScores
                      ? Colors.grey
                      : (!isFlagged
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444)),
                  statusBgColor: !hasScores
                      ? Colors.grey.shade100
                      : (!isFlagged
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2)),
                  earlyWarning: ew,
                  wwAvg: formatScorePill(wwStats),
                  ptAvg: formatScorePill(ptStats),
                  teAvg: formatScorePill(teStats),
                  wwColor: wwPct > 0 && wwPct < 75
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF3B82F6),
                  ptColor: ptPct > 0 && ptPct < 75
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  teColor: tePct > 0 && tePct < 75
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFDC3545),
                  onRemarks: widget.role == 'teacher' ? () {
                    _showRemarksDialog(sid, student['name'].toString());
                  } : null,
                  onViewDetails: () {
                    final studentScores = _allScores
                        .where((r) => _isStudentOrNameMatch(r, sid, sName))
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
    required double wwAvg,
    required double ptAvg,
    required double teAvg,
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
                if (classAvg > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: classAvg >= 75 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: classAvg >= 75 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          classAvg >= 75 ? Icons.trending_up : Icons.trending_down,
                          color: classAvg >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          classAvg >= 75 ? 'Passing Standard Met' : 'Needs Academic Attention',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: classAvg >= 75 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_chart_outlined, color: Color(0xFF94A3B8), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'No Scores Recorded',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                        ),
                      ],
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
                    _buildComponentAvg('Written Works', wwAvg > 0 ? '${wwAvg.toStringAsFixed(1)}%' : '--', Icons.assignment_outlined, const Color(0xFF0D6EFD)),
                    _buildComponentAvg('Performance Tasks', ptAvg > 0 ? '${ptAvg.toStringAsFixed(1)}%' : '--', Icons.groups_outlined, const Color(0xFF198754)),
                    _buildComponentAvg('Term Exams', teAvg > 0 ? '${teAvg.toStringAsFixed(1)}%' : '--', Icons.school_outlined, const Color(0xFFDC3545)),
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

  Future<void> _showRemarksDialog(String studentId, String studentName) async {
    if (_selectedClassData == null) return;
    final subjectCode = _selectedClassData!['subject_code'].toString();
    
    final db = DatabaseHelper();
    final existingRemark = await db.getStudentRemark(studentId, subjectCode, _selectedPeriod);
    
    if (!mounted) return;
    final remarkController = TextEditingController(text: existingRemark ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Remarks for $studentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: remarkController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter your remarks here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                await db.saveStudentRemark(studentId, subjectCode, _selectedPeriod, remarkController.text);
                if (mounted) {
                  Navigator.pop(context);
                  AestheticDialogs.showSuccessDialog(
                    context,
                    title: 'Remarks Saved',
                    message: 'Student evaluation remarks saved successfully!',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
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
    required String wwAvg,
    required String ptAvg,
    required String teAvg,
    Color wwColor = const Color(0xFF3B82F6),
    Color ptColor = const Color(0xFF3B82F6),
    Color teColor = const Color(0xFF3B82F6),
    EarlyWarningResult? earlyWarning,
    VoidCallback? onViewDetails,
    VoidCallback? onRemarks,
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
                      AvatarUtils.buildAvatar(
                        photo: avatarUrl,
                        name: name,
                        radius: 20,
                        backgroundColor: const Color(0xFFE0E7FF),
                        foregroundColor: const Color(0xFF4F46E5),
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
                AvatarUtils.buildAvatar(
                  photo: avatarUrl,
                  name: name,
                  radius: 24,
                  backgroundColor: const Color(0xFFE0E7FF),
                  foregroundColor: const Color(0xFF4F46E5),
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
              _buildPill('WW', wwAvg, wwColor),
              _buildPill('PT', ptAvg, ptColor),
              _buildPill('TE', teAvg, teColor),
              if (earlyWarning != null && (earlyWarning.missedCount > 0 || earlyWarning.subPassingCount > 0)) ...[
                _buildPill('Missed', '${earlyWarning.missedCount}', earlyWarning.isRuleATriggered ? const Color(0xFFEF4444) : Colors.grey.shade700),
                _buildPill('Sub-75', '${earlyWarning.subPassingCount}', earlyWarning.isRuleBTriggered ? const Color(0xFFEF4444) : Colors.grey.shade700),
              ],
              _buildOutlinedButton(Icons.visibility_outlined, 'View Details', const Color(0xFF3B82F6), onTap: onViewDetails),
              if (onRemarks != null) _buildOutlinedButton(Icons.chat_bubble_outline, 'Remarks', const Color(0xFF3B82F6), onTap: onRemarks),
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
    final highRisk = _students.where((s) {
      final sid = s['student_id'].toString();
      final sName = s['name']?.toString();
      if (!_studentHasScores(sid, sName)) return false;
      final g = _computeGrade(sid, sName);
      return g < 75;
    }).length;
    final mediumRisk = _students.where((s) {
      final sid = s['student_id'].toString();
      final sName = s['name']?.toString();
      if (!_studentHasScores(sid, sName)) return false;
      final g = _computeGrade(sid, sName);
      return g >= 75 && g <= 80;
    }).length;
    if (highRisk == 0 && mediumRisk == 0) return const SizedBox.shrink();
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
                                text: '${highRisk + mediumRisk}',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: ' students need attention (<= 80%)',
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
                            text: '${highRisk + mediumRisk}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' students need attention (<= 80%)',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showOnlyAtRisk = !_showOnlyAtRisk;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showOnlyAtRisk ? 'Show All Students' : 'View At-Risk Students',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(_showOnlyAtRisk ? Icons.close : Icons.chevron_right,
                              size: 18, color: const Color(0xFF3B82F6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (isSmall) const SizedBox(height: 16),
            if (isSmall)
              InkWell(
                onTap: () {
                  setState(() {
                    _showOnlyAtRisk = !_showOnlyAtRisk;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showOnlyAtRisk ? 'Show All Students' : 'View At-Risk Students',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(_showOnlyAtRisk ? Icons.close : Icons.chevron_right,
                        size: 18, color: const Color(0xFF3B82F6)),
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
                  _buildBreakdownRow(const Color(0xFFEF4444), 'High Risk (Below 75)', '$highRisk'),
                  const SizedBox(height: 8),
                  _buildBreakdownRow(const Color(0xFFF59E0B), 'Medium Risk (75 - 80)', '$mediumRisk'),
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




