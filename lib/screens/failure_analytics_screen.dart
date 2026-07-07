import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';

class FailureAnalyticsScreen extends StatefulWidget {
  final String username;
  final void Function(String studentId, String message)? onComposeNotification;

  const FailureAnalyticsScreen({super.key, required this.username, this.onComposeNotification});

  @override
  State<FailureAnalyticsScreen> createState() => _FailureAnalyticsScreenState();
}

class _FailureAnalyticsScreenState extends State<FailureAnalyticsScreen> {
  final DatabaseHelper db = DatabaseHelper();
  bool _isLoading = true;
  String _selectedPeriod = '1st Quarter';
  static const _periods = [
    '1st Quarter',
    '2nd Quarter',
    '3rd Quarter',
    '4th Quarter',
  ];

  // Data stores
  List<Map<String, dynamic>> _atRiskStudents = [];
  Map<String, double> _failureRatesBySubject = {};
  int _highRiskCount = 0;
  int _mediumRiskCount = 0;
  int _lowRiskCount = 0;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _atRiskStudents = [];
    _failureRatesBySubject = {};
    _highRiskCount = 0;
    _mediumRiskCount = 0;
    _lowRiskCount = 0;

    List<Map<String, dynamic>> classes = [];

    if (widget.username == 'admin') {
      classes = await db.getSubjectClasses();
    } else {
      final teacher = await db.getTeacherByEmail(widget.username);
      if (!mounted) return;
      if (teacher == null) {
        setState(() => _isLoading = false);
        return;
      }
      classes = await db.getSubjectClassesByTeacher(teacher['name'].toString());
    }

    // subjectName -> {total: int, failed: int}
    Map<String, Map<String, int>> subjectStats = {};

    for (var c in classes) {
      final subjectCode = c['subject_code'].toString();
      final subjectName = c['subject_name'].toString();
      final gradeLevel = c['grade_level'].toString();
      final section = c['section_name'].toString();

      final students = await db.getStudentsBySection(gradeLevel, section);
      if (students.isEmpty) continue;

      final setup = await db.getAssessmentSetup(
        subjectCode: subjectCode,
        sectionName: section,
        gradeLevel: gradeLevel,
        gradingPeriod: _selectedPeriod,
      );

      final scores = await db.getScoresForClass(
        subjectCode: subjectCode,
        sectionName: section,
        gradeLevel: gradeLevel,
        gradingPeriod: _selectedPeriod,
      );

      if (!subjectStats.containsKey(subjectName)) {
        subjectStats[subjectName] = {'total': 0, 'failed': 0};
      }

      for (var s in students) {
        final studentId = s['student_id'].toString();
        final studentName = s['name'].toString();

        final grade = _computeGrade(studentId, scores, setup);

        if (grade > 0) {
          // Only consider if there's an actual grade
          subjectStats[subjectName]!['total'] =
              subjectStats[subjectName]!['total']! + 1;

          String riskLevel = 'Low Risk';
          Color riskColor = const Color(0xFF00A364);
          Color iconBgColor = const Color(0xFFE2F6E7);

          if (grade < 75) {
            riskLevel = 'High Risk';
            riskColor = const Color(0xFFE74C3C);
            iconBgColor = const Color(0xFFFDECEE);
            _highRiskCount++;
            subjectStats[subjectName]!['failed'] =
                subjectStats[subjectName]!['failed']! + 1;
          } else if (grade < 80) {
            riskLevel = 'Medium Risk';
            riskColor = const Color(0xFFE67E22);
            iconBgColor = const Color(0xFFFDF0E1);
            _mediumRiskCount++;
          } else {
            _lowRiskCount++;
          }

          if (grade < 80) {
            final qAvg = _categoryAvg(studentId, 'Quiz', scores);
            final asgAvg = _categoryAvg(studentId, 'Assignment', scores);
            final actAvg = _categoryAvg(studentId, 'Activity', scores);
            final prjAvg = _categoryAvg(studentId, 'Project', scores);
            final exmAvg = _categoryAvg(studentId, 'Exam', scores);

            _atRiskStudents.add({
              'name': studentName,
              'id': studentId,
              'grade': '$gradeLevel - $section',
              'subject': subjectName,
              'average': '${grade.toStringAsFixed(1)}%',
              'riskLevel': riskLevel,
              'riskColor': riskColor,
              'iconBgColor': iconBgColor,
              'rawGrade': grade,
              'breakdown': {
                'Quiz': qAvg.toStringAsFixed(1),
                'Assignment': asgAvg.toStringAsFixed(1),
                'Activity': actAvg.toStringAsFixed(1),
                'Project': prjAvg.toStringAsFixed(1),
                'Exam': exmAvg.toStringAsFixed(1),
              },
            });
          }
        }
      }
    }

    subjectStats.forEach((subject, stats) {
      if (stats['total']! > 0) {
        _failureRatesBySubject[subject] =
            (stats['failed']! / stats['total']!) * 100;
      } else {
        _failureRatesBySubject[subject] = 0.0;
      }
    });

    _atRiskStudents.sort(
      (a, b) => (a['rawGrade'] as double).compareTo(b['rawGrade'] as double),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _showNotifyAllDialog(List<Map<String, dynamic>> students) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Color(0xFFE74C3C)),
            const SizedBox(width: 8),
            const Text('Bulk Notification'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to send generic notifications to ${students.length} at-risk students.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Message Preview:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: const Text(
                'Dear Parent, this is an update regarding your child\'s academic performance. They are currently tagged as "At-Risk" in our latest analytics. Please check their grades for more details.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Actual logic to send notification to all at-risk students
              if (widget.onComposeNotification != null) {
                for (var student in students) {
                  final message = 'Dear Parent, this is an update regarding your child\'s academic performance. They are currently tagged as "At-Risk" in our latest analytics. Please check their grades for more details.';
                  widget.onComposeNotification!(student['id'].toString(), message);
                }
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Notifications sent to ${students.length} parents!',
                  ),
                  backgroundColor: const Color(0xFF198754),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send to All'),
          ),
        ],
      ),
    );
  }

  void _showStudentBreakdownDialog(Map<String, dynamic> student) {
    final breakdown = student['breakdown'] as Map<String, dynamic>;

    String lowestCategory = '';
    double lowestScore = 100.0;
    
    breakdown.forEach((key, value) {
      final score = double.tryParse(value.toString()) ?? 0.0;
      if (score < lowestScore) {
        lowestScore = score;
        lowestCategory = key;
      }
    });

    String pluralCategory = lowestCategory;
    if (lowestCategory == 'Quiz') pluralCategory = 'Quizzes';
    else if (lowestCategory == 'Assignment') pluralCategory = 'Assignments';
    else if (lowestCategory == 'Activity') pluralCategory = 'Activities';
    else if (lowestCategory == 'Project') pluralCategory = 'Projects';
    else if (lowestCategory == 'Exam') pluralCategory = 'Exams';

    String reasonText = lowestCategory.isNotEmpty ? ' primarily due to low scores in $pluralCategory' : '';

    Widget buildBreakdownRow(String title, String percent) {
      final val = double.tryParse(percent) ?? 0.0;
      Color statusColor;
      String statusText;
      if (val < 75) {
        statusColor = const Color(0xFFE74C3C);
        statusText = 'Needs Improvement';
      } else if (val < 80) {
        statusColor = const Color(0xFFE67E22);
        statusText = 'Fair';
      } else {
        statusColor = const Color(0xFF00A364);
        statusText = 'Good';
      }
      if (val == 0) {
        statusText = 'No Data / Missing';
        statusColor = const Color(0xFFE74C3C);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF1664C5)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Performance Breakdown', style: TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${student['name']}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              '${student['subject']} - Total Average: ${student['average']}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            buildBreakdownRow('Quizzes', breakdown['Quiz']),
            buildBreakdownRow('Assignments', breakdown['Assignment']),
            buildBreakdownRow('Activities', breakdown['Activity']),
            buildBreakdownRow('Projects', breakdown['Project']),
            buildBreakdownRow('Exams', breakdown['Exam']),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE74C3C).withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb,
                    color: Color(0xFFE74C3C),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggestion: Student is falling behind$reasonText. Notify the parent for a conference to discuss an intervention plan.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFE74C3C)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showOneTapNotifyDialog(student);
            },
            icon: const Icon(Icons.campaign, size: 16),
            label: const Text('Notify Parent'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1664C5),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showOneTapNotifyDialog(Map<String, dynamic> student) {
    final breakdown = student['breakdown'] as Map<String, dynamic>;
    String lowestCategory = '';
    double lowestScore = 100.0;
    
    breakdown.forEach((key, value) {
      final score = double.tryParse(value.toString()) ?? 0.0;
      if (score < lowestScore) {
        lowestScore = score;
        lowestCategory = key;
      }
    });

    String pluralCategory = lowestCategory;
    if (lowestCategory == 'Quiz') pluralCategory = 'Quizzes';
    else if (lowestCategory == 'Assignment') pluralCategory = 'Assignments';
    else if (lowestCategory == 'Activity') pluralCategory = 'Activities';
    else if (lowestCategory == 'Project') pluralCategory = 'Projects';
    else if (lowestCategory == 'Exam') pluralCategory = 'Exams';

    String reasonText = lowestCategory.isNotEmpty ? ' primarily due to low scores in $pluralCategory' : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF1664C5)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Suggestion')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We detected that ${student['name']} is ${student['riskLevel']} in ${student['subject']} with an average of ${student['average']}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Draft Message:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                'Dear Parent, this is to inform you that ${student['name']} is currently at risk in ${student['subject']} (${student['average']})$reasonText. We suggest a meeting to discuss improvement plans.',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onComposeNotification != null) {
                final message = 'Dear Parent, this is to inform you that ${student['name']} is currently at risk in ${student['subject']} (${student['average']})$reasonText. We suggest a meeting to discuss improvement plans.';
                widget.onComposeNotification!(student['id'].toString(), message);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Notification sent to ${student['name']}\'s parent!',
                    ),
                    backgroundColor: const Color(0xFF198754),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1664C5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Notification'),
          ),
        ],
      ),
    );
  }

  double _computeGrade(
    String studentId,
    List<Map<String, dynamic>> allScores,
    Map<String, dynamic>? setup,
  ) {
    if (setup != null) {
      final wQuiz = (setup['quiz_weight'] as num?)?.toDouble() ?? 20;
      final wAssignment =
          (setup['assignment_weight'] as num?)?.toDouble() ?? 15;
      final wActivity = (setup['activity_weight'] as num?)?.toDouble() ?? 20;
      final wProject = (setup['project_weight'] as num?)?.toDouble() ?? 15;
      final wExam = (setup['exam_weight'] as num?)?.toDouble() ?? 30;

      final qAvg = _categoryAvg(studentId, 'Quiz', allScores);
      final asgAvg = _categoryAvg(studentId, 'Assignment', allScores);
      final actAvg = _categoryAvg(studentId, 'Activity', allScores);
      final prjAvg = _categoryAvg(studentId, 'Project', allScores);
      final exmAvg = _categoryAvg(studentId, 'Exam', allScores);

      if (qAvg == 0 &&
          asgAvg == 0 &&
          actAvg == 0 &&
          prjAvg == 0 &&
          exmAvg == 0) {
        if (allScores
            .where((r) => r['student_id'].toString() == studentId)
            .isEmpty)
          return 0.0;
      }

      return (qAvg * (wQuiz / 100)) +
          (asgAvg * (wAssignment / 100)) +
          (actAvg * (wActivity / 100)) +
          (prjAvg * (wProject / 100)) +
          (exmAvg * (wExam / 100));
    }

    final s = allScores
        .where((r) => r['student_id'].toString() == studentId)
        .toList();
    if (s.isEmpty) return 0.0;
    double total = 0, max = 0;
    for (final r in s) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    if (max == 0) return 0.0;
    return (total / max) * 100;
  }

  double _categoryAvg(
    String studentId,
    String category,
    List<Map<String, dynamic>> allScores,
  ) {
    final s = allScores
        .where(
          (r) =>
              r['student_id'].toString() == studentId &&
              r['category'].toString().toLowerCase() == category.toLowerCase(),
        )
        .toList();
    if (s.isEmpty) return 0.0;
    double total = 0, max = 0;
    for (final r in s) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    if (max == 0) return 0.0;
    return (total / max) * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredStudents = _atRiskStudents.where((s) {
      final name = s['name'].toString().toLowerCase();
      final section = s['grade'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || section.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector & Search
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search, color: Colors.black87),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedPeriod,
                      items: _periods
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                p,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPeriod = val);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Title
          Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const Icon(
                    Icons.bar_chart,
                    color: Color(0xFF1664C5),
                    size: 28,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning,
                      color: Color(0xFF1664C5),
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Failure Analytics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (filteredStudents.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showNotifyAllDialog(filteredStudents),
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text(
                    'Notify All',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE74C3C),
                    backgroundColor: const Color(0xFFFDECEE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.warning_amber_rounded,
                  iconBgColor: const Color(0xFFFDECEE),
                  iconColor: const Color(0xFFE74C3C),
                  title: 'At-Risk Students',
                  value: '${_highRiskCount + _mediumRiskCount}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_down,
                  iconBgColor: const Color(0xFFFDECEE),
                  iconColor: const Color(0xFFE74C3C),
                  title: 'High-Risk Cases',
                  value: '$_highRiskCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                // Chart section
                if (_failureRatesBySubject.isNotEmpty) ...[
                  _buildBarChartSection(),
                  const SizedBox(height: 12),
                ],
                // Risk Overview
                _buildRiskOverview(),
                const SizedBox(height: 12),

                // List of students
                if (filteredStudents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No at-risk students found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...filteredStudents.map((s) => _buildStudentRiskCard(s)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 20,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartSection() {
    final colors = [
      const Color(0xFF0F62D1),
      const Color(0xFF3282EA),
      const Color(0xFF5BA3F5),
      const Color(0xFF86BFFB),
      const Color(0xFFB5DAFE),
    ];

    final subjects = _failureRatesBySubject.keys.take(5).toList();
    final List<BarChartGroupData> barGroups = [];
    
    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final value = _failureRatesBySubject[subject]!;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: colors[i % colors.length],
              width: 24,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Failure Rate by Subject',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.black87,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final subject = subjects[group.x.toInt()];
                      return BarTooltipItem(
                        '$subject\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.yellow,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= subjects.length) {
                          return const SizedBox.shrink();
                        }
                        String shortSubject = subjects[index].length > 8
                            ? '${subjects[index].substring(0, 6)}..'
                            : subjects[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            shortSubject,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == 25 || value == 50 || value == 75 || value == 100) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskOverview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk Overview',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRiskBadge(
                  'High Risk',
                  '$_highRiskCount',
                  const Color(0xFFFDECEE),
                  const Color(0xFFE74C3C),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRiskBadge(
                  'Medium Risk',
                  '$_mediumRiskCount',
                  const Color(0xFFFDF0E1),
                  const Color(0xFFE67E22),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRiskBadge(
                  'Low Risk',
                  '$_lowRiskCount',
                  const Color(0xFFE7F7ED),
                  const Color(0xFF00A364),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge(
    String label,
    String count,
    Color bgColor,
    Color dotColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRiskCard(Map<String, dynamic> student) {
    String name = student['name'];
    String id = student['id'];
    String grade = student['grade'];
    String subject = student['subject'];
    String average = student['average'];
    String riskLevel = student['riskLevel'];
    Color riskColor = student['riskColor'];
    Color iconBgColor = student['iconBgColor'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 20,
            child: Icon(Icons.person, color: riskColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      'LRN: $id',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    Text(
                      grade,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    Text(
                      'Average: $average',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    riskLevel,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.campaign,
                  color: Color(0xFF1664C5),
                  size: 22,
                ),
                tooltip: 'One-Tap Notify',
                onPressed: () => _showOneTapNotifyDialog(student),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(
                  Icons.remove_red_eye_outlined,
                  color: Colors.black45,
                  size: 20,
                ),
                onPressed: () => _showStudentBreakdownDialog(student),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
