import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';

/// Screen for analyzing individual child academic performance,
/// competency mastery across assessment categories, learning strengths,
/// growth opportunities, and constructive home-school communication.
class PerformanceAnalyticsScreen extends StatefulWidget {
  final String username;
  final void Function(String studentId, String message)? onComposeNotification;

  const PerformanceAnalyticsScreen({
    super.key,
    required this.username,
    this.onComposeNotification,
  });

  @override
  State<PerformanceAnalyticsScreen> createState() => _PerformanceAnalyticsScreenState();
}

/// Backward-compatibility alias so that existing navigation routes remain unbroken.
typedef FailureAnalyticsScreen = PerformanceAnalyticsScreen;

class _PerformanceAnalyticsScreenState extends State<PerformanceAnalyticsScreen> {
  final DatabaseHelper db = DatabaseHelper();
  bool _isLoading = true;
  String _selectedPeriod = '1st Term';
  static const _periods = [
    '1st Term',
    '2nd Term',
    '3rd Term',
  ];

  // Data stores
  List<Map<String, dynamic>> _allStudents = [];
  Map<String, double> _subjectAverages = {};
  Map<String, double> _subjectMasteryRates = {};
  Map<String, int> _subjectStudentCounts = {};
  Map<String, int> _subjectHonorsCounts = {};

  // Child Performance Tiers (Aligned with DepEd K to 12 Mastery Levels)
  int _outstandingCount = 0; // >= 90% (Outstanding / With Honors)
  int _highProficiencyCount = 0; // 85% - 89.9% (Very Satisfactory)
  int _proficientCount = 0; // 80% - 84.9% (Satisfactory)
  int _developingCount = 0; // 75% - 79.9% (Fairly Satisfactory / Developing)
  int _targetedSupportCount = 0; // < 75% (Foundational Growth / Targeted Support)

  int _touchedIndex = -1;
  String _searchQuery = '';
  // 'All', 'Honors', 'High Proficiency', 'Proficient', 'Developing', 'Targeted Support'
  String _selectedFilter = 'All';
  String _sortBy = 'Highest Performance'; // 'Highest Performance', 'Lowest to Growth', 'Name (A-Z)'

  String _selectedGradeLevel = 'All';
  String _selectedSection = 'All';
  List<String> _availableGradeLevels = ['All'];
  List<String> _availableSections = ['All'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _allStudents = [];
    _subjectAverages = {};
    _subjectMasteryRates = {};
    _subjectStudentCounts = {};
    _subjectHonorsCounts = {};
    _outstandingCount = 0;
    _highProficiencyCount = 0;
    _proficientCount = 0;
    _developingCount = 0;
    _targetedSupportCount = 0;

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

    Set<String> grades = {'All'};
    Set<String> sections = {'All'};
    for (var c in classes) {
      grades.add(c['grade_level'].toString());
      if (_selectedGradeLevel == 'All' || _selectedGradeLevel == c['grade_level'].toString()) {
        sections.add(c['section_name'].toString());
      }
    }

    _availableGradeLevels = grades.toList()..sort();
    _availableSections = sections.toList()..sort();

    if (!_availableGradeLevels.contains(_selectedGradeLevel)) _selectedGradeLevel = 'All';
    if (!_availableSections.contains(_selectedSection)) _selectedSection = 'All';

    var filteredClasses = classes.where((c) {
      if (_selectedGradeLevel != 'All' && c['grade_level'].toString() != _selectedGradeLevel) return false;
      if (_selectedSection != 'All' && c['section_name'].toString() != _selectedSection) return false;
      return true;
    }).toList();

    // subjectName -> {total: int, passed: int, honors: int, gradeSum: double}
    Map<String, Map<String, dynamic>> subjectStats = {};

    for (var c in filteredClasses) {
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

      final attendanceRecords = await db.getAttendanceForClass('$gradeLevel - $section');
      final uniqueDates = attendanceRecords.map((r) => r['date'].toString()).toSet();
      final totalClassDays = uniqueDates.length;

      if (!subjectStats.containsKey(subjectName)) {
        subjectStats[subjectName] = {'total': 0, 'passed': 0, 'honors': 0, 'gradeSum': 0.0};
      }

      for (var s in students) {
        final studentId = s['student_id'].toString();
        final studentName = s['name'].toString();

        double attendancePct = 0.0;
        if (totalClassDays > 0) {
          final studentAtt = attendanceRecords.where((r) => r['student_id'].toString() == studentId).toList();
          double points = 0.0;
          for (final record in studentAtt) {
            final status = record['status']?.toString() ?? '';
            if (status == 'Present' || status == 'Excused') {
              points += 1.0;
            } else if (status == 'Late') {
              points += 0.5;
            }
          }
          attendancePct = (points / totalClassDays) * 100;
        }

        final grade = _computeGrade(studentId, scores, setup, attendancePct);

        if (grade > 0) {
          subjectStats[subjectName]!['total'] = (subjectStats[subjectName]!['total'] as int) + 1;
          subjectStats[subjectName]!['gradeSum'] = (subjectStats[subjectName]!['gradeSum'] as double) + grade;

          if (grade >= 75) {
            subjectStats[subjectName]!['passed'] = (subjectStats[subjectName]!['passed'] as int) + 1;
          }
          if (grade >= 90) {
            subjectStats[subjectName]!['honors'] = (subjectStats[subjectName]!['honors'] as int) + 1;
          }

          // Evaluate Child Academic Performance & Learning Mastery
          String tierKey;
          String tierLabel;
          String badgeTitle;
          Color tierColor;
          Color tierBgColor;
          IconData tierIcon;
          String tierSummary;

          if (grade >= 90) {
            tierKey = 'Honors';
            tierLabel = 'Outstanding';
            badgeTitle = 'Honors Roll';
            tierColor = const Color(0xFF059669); // Emerald
            tierBgColor = const Color(0xFFECFDF5);
            tierIcon = Icons.military_tech_rounded;
            tierSummary = 'Advanced Mastery & Critical Thinking';
            _outstandingCount++;
          } else if (grade >= 85) {
            tierKey = 'High Proficiency';
            tierLabel = 'Very Satisfactory';
            badgeTitle = 'High Proficiency';
            tierColor = const Color(0xFF0284C7); // Sky / Steel Blue
            tierBgColor = const Color(0xFFF0F9FF);
            tierIcon = Icons.verified_rounded;
            tierSummary = 'Exceeds Core Competencies';
            _highProficiencyCount++;
          } else if (grade >= 80) {
            tierKey = 'Proficient';
            tierLabel = 'Satisfactory';
            badgeTitle = 'Proficient';
            tierColor = const Color(0xFF2563EB); // Royal Blue
            tierBgColor = const Color(0xFFEFF6FF);
            tierIcon = Icons.check_circle_rounded;
            tierSummary = 'Meets Grade-Level Competencies';
            _proficientCount++;
          } else if (grade >= 75) {
            tierKey = 'Developing';
            tierLabel = 'Developing Competency';
            badgeTitle = 'Developing';
            tierColor = const Color(0xFFD97706); // Warm Amber
            tierBgColor = const Color(0xFFFFFBEB);
            tierIcon = Icons.trending_up_rounded;
            tierSummary = 'Approaching Full Proficiency';
            _developingCount++;
          } else {
            tierKey = 'Targeted Support';
            tierLabel = 'Foundational Growth';
            badgeTitle = 'Targeted Support';
            tierColor = const Color(0xFFE11D48); // Rose
            tierBgColor = const Color(0xFFFFF1F2);
            tierIcon = Icons.psychology_rounded;
            tierSummary = 'Personalized Mentorship Recommended';
            _targetedSupportCount++;
          }

          final wwAvg = _categoryAvg(studentId, 'Written Works', scores, setup);
          final ptAvg = _categoryAvg(studentId, 'Performance Tasks', scores, setup);
          final teAvg = _categoryAvg(studentId, 'Term Exams', scores, setup);
          final attendanceStats = await db.getStudentAttendanceStats(studentId, setup?['school_year']);

          // Determine Child's Top Competency & Growth Opportunity
          final breakdownMap = {
            'Written Works': wwAvg,
            'Performance Tasks': ptAvg,
            'Term Exams': teAvg,
          };

          String strongestArea = 'Performance Tasks';
          double highestScore = -1.0;
          String growthArea = 'Written Works';
          double lowestScore = 101.0;

          breakdownMap.forEach((category, val) {
            if (val > highestScore) {
              highestScore = val;
              strongestArea = category;
            }
            if (val < lowestScore) {
              lowestScore = val;
              growthArea = category;
            }
          });

          // Generate child-centered constructive growth recommendation
          String pedagogicalGuidance;
          if (grade >= 90) {
            pedagogicalGuidance =
                'Child demonstrates exceptional mastery across all indicators, led by $strongestArea (${highestScore.toStringAsFixed(1)}%). Recommend challenging with creative extension projects and peer mentorship roles.';
          } else if (grade >= 85) {
            pedagogicalGuidance =
                'Child shows high proficiency and strong engagement in $strongestArea (${highestScore.toStringAsFixed(1)}%). Focused practice in $growthArea (${lowestScore.toStringAsFixed(1)}%) will elevate them to the Honors Roll.';
          } else if (grade >= 80) {
            pedagogicalGuidance =
                'Child consistently meets curriculum standards. Encourage independent study habits in $growthArea (${lowestScore.toStringAsFixed(1)}%) to build even higher confidence.';
          } else if (grade >= 75) {
            pedagogicalGuidance =
                'Child is making steady progress, excelling best in $strongestArea (${highestScore.toStringAsFixed(1)}%). Dedicated reinforcement and guided practice in $growthArea (${lowestScore.toStringAsFixed(1)}%) are recommended.';
          } else {
            pedagogicalGuidance =
                'Child shows foundational promise in $strongestArea (${highestScore.toStringAsFixed(1)}%). Recommend partnering with parents on a personalized 15-minute daily study plan focused on $growthArea (${lowestScore.toStringAsFixed(1)}%).';
          }

          _allStudents.add({
            'name': studentName,
            'id': studentId,
            'grade': '$gradeLevel - $section',
            'gradeLevel': gradeLevel,
            'section': section,
            'subject': subjectName,
            'average': '${grade.toStringAsFixed(1)}%',
            'rawGrade': grade,
            'tierKey': tierKey,
            'tierLabel': tierLabel,
            'badgeTitle': badgeTitle,
            'tierColor': tierColor,
            'tierBgColor': tierBgColor,
            'tierIcon': tierIcon,
            'tierSummary': tierSummary,
            'strongestArea': strongestArea,
            'highestScore': highestScore,
            'growthArea': growthArea,
            'lowestScore': lowestScore,
            'pedagogicalGuidance': pedagogicalGuidance,
            'attendancePct': attendancePct,
            'attendanceStats': attendanceStats,
            'breakdown': {
              'Written Works': wwAvg.toStringAsFixed(1),
              'Performance Tasks': ptAvg.toStringAsFixed(1),
              'Term Exams': teAvg.toStringAsFixed(1),
            },
          });
        }
      }
    }

    subjectStats.forEach((subject, stats) {
      final total = stats['total'] as int;
      final gradeSum = stats['gradeSum'] as double;
      final passed = stats['passed'] as int;
      final honors = stats['honors'] as int;

      _subjectStudentCounts[subject] = total;
      _subjectHonorsCounts[subject] = honors;
      if (total > 0) {
        _subjectAverages[subject] = gradeSum / total;
        _subjectMasteryRates[subject] = (passed / total) * 100;
      } else {
        _subjectAverages[subject] = 0.0;
        _subjectMasteryRates[subject] = 0.0;
      }
    });

    _applySorting();

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _applySorting() {
    if (_sortBy == 'Highest Performance') {
      _allStudents.sort((a, b) => (b['rawGrade'] as double).compareTo(a['rawGrade'] as double));
    } else if (_sortBy == 'Lowest to Growth') {
      _allStudents.sort((a, b) => (a['rawGrade'] as double).compareTo(b['rawGrade'] as double));
    } else if (_sortBy == 'Name (A-Z)') {
      _allStudents.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    }
  }

  double _computeGrade(
    String studentId,
    List<Map<String, dynamic>> allScores,
    Map<String, dynamic>? setup,
    double attendancePct,
  ) {
    if (setup != null) {
      final wWW = (setup['ww_weight'] as num?)?.toDouble() ?? 30;
      final wPT = (setup['pt_weight'] as num?)?.toDouble() ?? 50;
      final wTE = (setup['te_weight'] as num?)?.toDouble() ?? 20;
      final wAttendance = (setup['attendance_weight'] as num?)?.toDouble() ?? 0;

      final wwAvg = _categoryAvg(studentId, 'Written Works', allScores, setup);
      final ptAvg = _categoryAvg(studentId, 'Performance Tasks', allScores, setup);
      final teAvg = _categoryAvg(studentId, 'Term Exams', allScores, setup);

      if (wwAvg == 0 && ptAvg == 0 && teAvg == 0) {
        if (allScores.where((r) => r['student_id'].toString() == studentId).isEmpty) {
          return 0.0;
        }
      }

      double totalWeight = 0;
      double earned = 0;

      bool hasWW = allScores.any((r) => r['student_id'].toString() == studentId && r['category'].toString().toLowerCase() == 'written works');
      bool hasPT = allScores.any((r) => r['student_id'].toString() == studentId && r['category'].toString().toLowerCase() == 'performance tasks');
      bool hasTE = allScores.any((r) => r['student_id'].toString() == studentId && r['category'].toString().toLowerCase() == 'term exams');

      if (hasWW) {
        earned += wwAvg * (wWW / 100);
        totalWeight += (wWW / 100);
      }
      if (hasPT) {
        earned += ptAvg * (wPT / 100);
        totalWeight += (wPT / 100);
      }
      if (hasTE) {
        earned += teAvg * (wTE / 100);
        totalWeight += (wTE / 100);
      }

      if (wAttendance > 0) {
        earned += attendancePct * (wAttendance / 100);
        totalWeight += (wAttendance / 100);
      }

      if (totalWeight == 0) return 0.0;
      double initialGrade = earned / totalWeight;
      return DatabaseHelper().transmuteGrade(initialGrade);
    }

    final s = allScores.where((r) => r['student_id'].toString() == studentId).toList();
    if (s.isEmpty) return 0.0;
    double total = 0, max = 0;
    for (final r in s) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    if (max == 0) return 0.0;
    double initialGrade = (total / max) * 100;
    return DatabaseHelper().transmuteGrade(initialGrade);
  }

  double _categoryAvg(
    String studentId,
    String category,
    List<Map<String, dynamic>> allScores,
    Map<String, dynamic>? setup,
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

  // Positive and constructive parent communication dialog
  void _showBulkNotificationDialog(List<Map<String, dynamic>> students, String type) {
    final bool isHonors = type == 'Honors';
    final String titleText = isHonors ? 'Send Honors Commendations' : 'Send Collaborative Progress Plans';
    final String defaultMessage = isHonors
        ? 'Dear Parent, congratulations! We are proud to share that your child has achieved Outstanding academic performance and earned Honors standing in our latest evaluation. Thank you for your inspiring support!'
        : 'Dear Parent, greetings! This is a supportive academic progress update regarding your child. They are demonstrating valuable potential, and we would love to collaborate with you on a guided practice routine to help them reach full competency.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isHonors ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHonors ? Icons.emoji_events_rounded : Icons.handshake_rounded,
                color: isHonors ? const Color(0xFF059669) : const Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titleText,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dispatches personalized communication to the parents of ${students.length} learner(s) in this category.',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
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
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                defaultMessage,
                style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onComposeNotification != null) {
                for (var student in students) {
                  widget.onComposeNotification!(student['id'].toString(), defaultMessage);
                }
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Academic messages dispatched to ${students.length} parent(s)!'),
                  backgroundColor: const Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Dispatch Messages'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isHonors ? const Color(0xFF059669) : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // Child-centered detailed performance breakdown dialog
  void _showStudentPerformanceProfileDialog(Map<String, dynamic> student) {
    final breakdown = student['breakdown'] as Map<String, dynamic>;
    final String tierLabel = student['tierLabel'];
    final Color tierColor = student['tierColor'];
    final Color tierBgColor = student['tierBgColor'];
    final IconData tierIcon = student['tierIcon'];
    final String strongestArea = student['strongestArea'];
    final double highestScore = student['highestScore'];
    final String growthArea = student['growthArea'];
    final double lowestScore = student['lowestScore'];
    final String pedagogicalGuidance = student['pedagogicalGuidance'];

    Widget buildCompetencyMeter(String title, String percent) {
      final val = double.tryParse(percent) ?? 0.0;
      Color meterColor;
      String statusText;
      if (val >= 90) {
        meterColor = const Color(0xFF059669);
        statusText = 'Outstanding';
      } else if (val >= 85) {
        meterColor = const Color(0xFF0284C7);
        statusText = 'Very Satisfactory';
      } else if (val >= 80) {
        meterColor = const Color(0xFF2563EB);
        statusText = 'Satisfactory';
      } else if (val >= 75) {
        meterColor = const Color(0xFFD97706);
        statusText = 'Developing';
      } else {
        meterColor = const Color(0xFFE11D48);
        statusText = 'Support Needed';
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: meterColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: meterColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: meterColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (val / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(meterColor),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tierBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(tierIcon, color: tierColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Child Performance Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    'Academic Mastery & Growth Analysis',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Child Banner Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tierBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tierColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: tierColor,
                        radius: 22,
                        child: Text(
                          student['name'].toString().isNotEmpty ? student['name'][0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${student['name']}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              '${student['grade']} • ${student['subject']} (LRN: ${student['id']})',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${student['average']}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tierColor),
                          ),
                          Text(
                            tierLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tierColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Competency Components Breakdown
                const Text(
                  'Academic Competency Meters',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 10),
                buildCompetencyMeter('Written Works (Knowledge & Concepts)', breakdown['Written Works'] ?? '0.0'),
                buildCompetencyMeter('Performance Tasks (Practical Projects)', breakdown['Performance Tasks'] ?? '0.0'),
                buildCompetencyMeter('Term Exams (Summative Assessment)', breakdown['Term Exams'] ?? '0.0'),

                // Attendance Integration
                if (student['attendanceStats'] != null) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: const [
                            Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Class Attendance & Presence',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${student['attendanceStats']['percentage']} Attendance',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recorded ${student['attendanceStats']['present']} present days of ${student['attendanceStats']['total']} total instructional days.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],

                const SizedBox(height: 14),

                // Child's Identified Strengths & Focus Areas
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.star_rounded, color: Color(0xFF059669), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Top Strength',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$strongestArea (${highestScore.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.trending_up_rounded, color: Color(0xFF2563EB), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Growth Focus',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$growthArea (${lowestScore.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Constructive Pedagogical Recommendation
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Child-Centered Pedagogical Guidance',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pedagogicalGuidance,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showPersonalizedParentDialog(student);
            },
            icon: const Icon(Icons.mail_outline_rounded, size: 16),
            label: const Text('Send Parent Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPersonalizedParentDialog(Map<String, dynamic> student) {
    final grade = student['rawGrade'] as double;
    final String strongestArea = student['strongestArea'];
    final String growthArea = student['growthArea'];

    String draftMessage;
    if (grade >= 90) {
      draftMessage =
          'Dear Parent, we are delighted to commend ${student['name']} for exceptional academic excellence in ${student['subject']} with an Outstanding average of ${student['average']}. They particularly excelled in $strongestArea. Congratulations!';
    } else if (grade >= 80) {
      draftMessage =
          'Dear Parent, this is an encouraging update regarding ${student['name']}\'s performance in ${student['subject']}. They are maintaining a commendable standing of ${student['average']}, demonstrating strong potential in $strongestArea. We encourage continuous practice in $growthArea.';
    } else {
      draftMessage =
          'Dear Parent, greetings! We are sharing an academic progress update for ${student['name']} in ${student['subject']} (Current standing: ${student['average']}). They show great engagement in $strongestArea, and we recommend partnering on supportive home review in $growthArea.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.forward_to_inbox_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Expanded(child: Text('Personalized Parent Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic update for ${student['name']} (${student['subject']} • ${student['average']}):',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                draftMessage,
                style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onComposeNotification != null) {
                widget.onComposeNotification!(student['id'].toString(), draftMessage);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Performance update dispatched to ${student['name']}\'s parent!'),
                  backgroundColor: const Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter students by search and active category tab
    final filteredStudents = _allStudents.where((s) {
      final name = s['name'].toString().toLowerCase();
      final section = s['grade'].toString().toLowerCase();
      final subject = s['subject'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesQuery = name.contains(query) || section.contains(query) || subject.contains(query);
      if (!matchesQuery) return false;

      if (_selectedFilter == 'Honors') return (s['rawGrade'] as double) >= 90;
      if (_selectedFilter == 'High Proficiency') return (s['rawGrade'] as double) >= 85 && (s['rawGrade'] as double) < 90;
      if (_selectedFilter == 'Proficient') return (s['rawGrade'] as double) >= 80 && (s['rawGrade'] as double) < 85;
      if (_selectedFilter == 'Developing') return (s['rawGrade'] as double) >= 75 && (s['rawGrade'] as double) < 80;
      if (_selectedFilter == 'Targeted Support') return (s['rawGrade'] as double) < 75;
      return true; // 'All'
    }).toList();

    // Summary calculations
    final classAverage = _allStudents.isNotEmpty
        ? _allStudents.map((s) => s['rawGrade'] as double).reduce((a, b) => a + b) / _allStudents.length
        : 0.0;
    final standardsMasteryRate = _allStudents.isNotEmpty
        ? (_allStudents.where((s) => (s['rawGrade'] as double) >= 75).length / _allStudents.length) * 100
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                    hintText: 'Search student, LRN, class, or subject...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                    border: Border.all(color: Colors.black12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedPeriod,
                      items: _periods
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
          const SizedBox(height: 10),

          // Grade & Section Filters
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedGradeLevel,
                      hint: const Text('Grade Level', style: TextStyle(fontSize: 12)),
                      items: _availableGradeLevels
                          .map((g) => DropdownMenuItem(value: g, child: Text(g == 'All' ? 'All Grades' : g, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedGradeLevel = val);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSection,
                      hint: const Text('Section', style: TextStyle(fontSize: 12)),
                      items: _availableSections
                          .map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Sections' : s, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSection = val);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Header Title and Constructive Action Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final actionButtons = [
                if (_outstandingCount > 0)
                  TextButton.icon(
                    onPressed: () {
                      final honorsList = _allStudents.where((s) => (s['rawGrade'] as double) >= 90).toList();
                      _showBulkNotificationDialog(honorsList, 'Honors');
                    },
                    icon: const Icon(Icons.emoji_events_rounded, size: 15),
                    label: Text(
                      'Commend Honors ($_outstandingCount)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      backgroundColor: const Color(0xFFECFDF5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                if (_targetedSupportCount > 0)
                  TextButton.icon(
                    onPressed: () {
                      final supportList = _allStudents.where((s) => (s['rawGrade'] as double) < 75).toList();
                      _showBulkNotificationDialog(supportList, 'Support');
                    },
                    icon: const Icon(Icons.handshake_rounded, size: 15),
                    label: Text(
                      'Growth Plans ($_targetedSupportCount)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFFEFF6FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ];

              final titleSection = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Child Performance Analytics',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Academic mastery, strengths & growth mentorship',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    if (actionButtons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: actionButtons,
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleSection),
                  if (actionButtons.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: actionButtons,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Scrollable Content
          Expanded(
            child: ListView(
              children: [
                // 4 Child Performance Overview Stat Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 720;
                    final cardWidth = isDesktop ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildStatCard(
                          icon: Icons.school_rounded,
                          iconBgColor: const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF2563EB),
                          title: 'Class Mastery Average',
                          value: _allStudents.isEmpty ? '0.0%' : '${classAverage.toStringAsFixed(1)}%',
                          subtitle: 'Overall Child Performance',
                          width: cardWidth,
                        ),
                        _buildStatCard(
                          icon: Icons.task_alt_rounded,
                          iconBgColor: const Color(0xFFECFDF5),
                          iconColor: const Color(0xFF059669),
                          title: 'Standards Mastery Rate',
                          value: _allStudents.isEmpty ? '0.0%' : '${standardsMasteryRate.toStringAsFixed(1)}%',
                          subtitle: 'Met Competencies (≥75%)',
                          width: cardWidth,
                        ),
                        _buildStatCard(
                          icon: Icons.military_tech_rounded,
                          iconBgColor: const Color(0xFFFFFBEB),
                          iconColor: const Color(0xFFD97706),
                          title: 'Academic Honors Roll',
                          value: '$_outstandingCount Learners',
                          subtitle: 'Outstanding Mastery (≥90%)',
                          width: cardWidth,
                        ),
                        _buildStatCard(
                          icon: Icons.psychology_rounded,
                          iconBgColor: const Color(0xFFF0FDF4),
                          iconColor: const Color(0xFF0D9488),
                          title: 'Personalized Mentorship',
                          value: '$_targetedSupportCount Learners',
                          subtitle: 'Targeted Guidance (<75%)',
                          width: cardWidth,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Subject Performance Bar Chart
                if (_subjectAverages.isNotEmpty) ...[
                  _buildSubjectPerformanceChart(),
                  const SizedBox(height: 16),
                ],

                // Child Performance Tier Distribution
                _buildPerformanceDistribution(),
                const SizedBox(height: 16),

                // Student Performance Roster Header and Sorting Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Child Performance Roster',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        isDense: true,
                        icon: const Icon(Icons.sort_rounded, size: 18),
                        items: ['Highest Performance', 'Lowest to Growth', 'Name (A-Z)']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _sortBy = val;
                              _applySorting();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Filter Chips for Student Roster
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', _allStudents.length),
                      const SizedBox(width: 8),
                      _buildFilterChip('Honors', _outstandingCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('High Proficiency', _highProficiencyCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('Proficient', _proficientCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('Developing', _developingCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('Targeted Support', _targetedSupportCount),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // List of Children
                if (filteredStudents.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No learners found matching "$_searchQuery".'
                              : 'No learners found in this performance tier.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredStudents.map((s) => _buildStudentPerformanceCard(s)),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    bool isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(
        '$label ($count)',
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = label);
        }
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF2563EB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF2563EB) : Colors.black12,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: iconBgColor,
                radius: 16,
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: iconColor, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPerformanceChart() {
    var subjects = _subjectAverages.keys.toList();
    subjects.sort((a, b) => _subjectAverages[b]!.compareTo(_subjectAverages[a]!));

    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final avg = _subjectAverages[subject]!;

      Color barColor;
      if (avg >= 90) {
        barColor = const Color(0xFF059669); // Honors Emerald
      } else if (avg >= 85) {
        barColor = const Color(0xFF0284C7); // High Proficiency Sky
      } else if (avg >= 80) {
        barColor = const Color(0xFF2563EB); // Proficient Blue
      } else if (avg >= 75) {
        barColor = const Color(0xFFD97706); // Developing Amber
      } else {
        barColor = const Color(0xFFE11D48); // Targeted Support Rose
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          showingTooltipIndicators: _touchedIndex == i ? [0] : [],
          barRods: [
            BarChartRodData(
              toY: avg,
              color: barColor,
              width: 22,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text(
                'Subject Performance & Child Mastery',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Avg Grade', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Container(
                    width: 12,
                    height: 2,
                    color: const Color(0xFF059669),
                  ),
                  const SizedBox(width: 4),
                  const Text('Standards Benchmark (75%)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 180,
              width: subjects.length > 4 ? subjects.length * 80.0 : MediaQuery.of(context).size.width - 64,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  minY: 0,
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 75,
                        color: const Color(0xFF059669).withValues(alpha: 0.6),
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                      ),
                      HorizontalLine(
                        y: 90,
                        color: const Color(0xFFD97706).withValues(alpha: 0.4),
                        strokeWidth: 1.2,
                        dashArray: [3, 3],
                      ),
                    ],
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    handleBuiltInTouches: false,
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (event is FlTapUpEvent || event is FlTapCancelEvent || event is FlLongPressEnd) {
                        setState(() => _touchedIndex = -1);
                        return;
                      }
                      if (barTouchResponse != null && barTouchResponse.spot != null) {
                        setState(() {
                          _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                        });
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (group) => const Color(0xFF1E293B),
                      tooltipPadding: const EdgeInsets.all(8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final subject = subjects[group.x.toInt()];
                        final mastery = _subjectMasteryRates[subject]?.toStringAsFixed(1) ?? '0.0';
                        final count = _subjectStudentCounts[subject] ?? 0;
                        final honors = _subjectHonorsCounts[subject] ?? 0;
                        return BarTooltipItem(
                          '$subject\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          children: [
                            TextSpan(
                              text: 'Avg Performance: ${rod.toY.toStringAsFixed(1)}%\n',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: 'Standards Mastery: $mastery% ($count learners)\n',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                            TextSpan(
                              text: 'Honors Achieved: $honors learners',
                              style: const TextStyle(color: Color(0xFF34D399), fontSize: 10),
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
                          String shortSubject = subjects[index].length > 9
                              ? '${subjects[index].substring(0, 7)}..'
                              : subjects[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              shortSubject,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
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
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
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
                        color: Colors.grey.withValues(alpha: 0.15),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceDistribution() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Child Performance Mastery Tiers',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Tap tier to filter roster',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTierPill(
                  'Honors (≥90)',
                  '$_outstandingCount',
                  const Color(0xFFECFDF5),
                  const Color(0xFF059669),
                  () => setState(() => _selectedFilter = 'Honors'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTierPill(
                  'High Prof. (85-89)',
                  '$_highProficiencyCount',
                  const Color(0xFFF0F9FF),
                  const Color(0xFF0284C7),
                  () => setState(() => _selectedFilter = 'High Proficiency'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTierPill(
                  'Proficient (80-84)',
                  '$_proficientCount',
                  const Color(0xFFEFF6FF),
                  const Color(0xFF2563EB),
                  () => setState(() => _selectedFilter = 'Proficient'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTierPill(
                  'Developing (75-79)',
                  '$_developingCount',
                  const Color(0xFFFFFBEB),
                  const Color(0xFFD97706),
                  () => setState(() => _selectedFilter = 'Developing'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTierPill(
                  'Targeted Support (<75)',
                  '$_targetedSupportCount',
                  const Color(0xFFFFF1F2),
                  const Color(0xFFE11D48),
                  () => setState(() => _selectedFilter = 'Targeted Support'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierPill(String label, String count, Color bgColor, Color dotColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: dotColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              count,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: dotColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentPerformanceCard(Map<String, dynamic> student) {
    String name = student['name'];
    String id = student['id'];
    String grade = student['grade'];
    String subject = student['subject'];
    String average = student['average'];
    String badgeTitle = student['badgeTitle'];
    Color tierColor = student['tierColor'];
    Color tierBgColor = student['tierBgColor'];
    final breakdown = student['breakdown'] as Map<String, dynamic>;
    final String strongestArea = student['strongestArea'];
    final double highestScore = student['highestScore'];
    final String growthArea = student['growthArea'];
    final double lowestScore = student['lowestScore'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: tierBgColor,
                radius: 18,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: tierColor, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: tierBgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tierColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            '$average • $badgeTitle',
                            style: TextStyle(
                              color: tierColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$grade • $subject (LRN: $id)',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF2563EB), size: 18),
                    tooltip: 'View Performance Profile',
                    onPressed: () => _showStudentPerformanceProfileDialog(student),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  IconButton(
                    icon: Icon(
                      (student['rawGrade'] as double) >= 90 ? Icons.emoji_events_rounded : Icons.mail_outline_rounded,
                      color: (student['rawGrade'] as double) >= 90 ? const Color(0xFF059669) : const Color(0xFF2563EB),
                      size: 18,
                    ),
                    tooltip: 'Send Parent Message',
                    onPressed: () => _showPersonalizedParentDialog(student),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Scores pill summary & child strength/growth indicators
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMiniBadge('WW: ${breakdown['Written Works']}%'),
              _buildMiniBadge('PT: ${breakdown['Performance Tasks']}%'),
              _buildMiniBadge('TE: ${breakdown['Term Exams']}%'),
              // Child strength indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '★ Top: $strongestArea (${highestScore.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                ),
              ),
              // Child growth indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '🌱 Focus: $growthArea (${lowestScore.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
      ),
    );
  }
}
