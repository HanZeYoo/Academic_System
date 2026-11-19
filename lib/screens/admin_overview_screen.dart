import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reports_generation_screen.dart';
import '../utils/dialog_utils.dart';
import '../widgets/skeleton_loader.dart';
class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final DatabaseHelper db = DatabaseHelper();
  bool _isLoading = true;

  int _totalStudents = 0;
  int _totalTeachers = 0;
  
  // Attendance percentages
  double _presentPercent = 0.0;
  double _latePercent = 0.0;
  double _absentPercent = 0.0;

  // Subject Performance & Mastery Rates
  final List<Map<String, dynamic>> _subjectMasteryRates = [];
  bool _showAllMasteryRates = false;

  // Trend Data (1st Term, 2nd Term, 3rd Term)
  final List<double> _trendData = [0.0, 0.0, 0.0];

  String _selectedPeriod = '1st Term';
  static const _periods = [
    '1st Term',
    '2nd Term',
    '3rd Term',
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch lightweight projected overview datasets concurrently in 1 parallel batch
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('students')
            .select('student_id, grade_level, section, school_year, enrollment_status')
            .eq('is_active', 1),
        Supabase.instance.client
            .from('teachers')
            .select('id')
            .eq('is_active', 1),
        Supabase.instance.client.from('attendance').select('status'),
        Supabase.instance.client
            .from('subjects_classes')
            .select('subject_code, subject_name, grade_level, section_name')
            .eq('is_active', 1),
        Supabase.instance.client
            .from('assessment_setups')
            .select('subject_code, section_name, grade_level, grading_period, ww_weight, pt_weight, te_weight, created_at')
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('scores')
            .select('student_id, subject_code, section_name, grade_level, grading_period, category, score, total_score'),
        db.getActiveSchoolYear(),
      ]);

      final studentsData = List<Map<String, dynamic>>.from(results[0] as List);
      final teachersData = List<Map<String, dynamic>>.from(results[1] as List);
      final attendance = List<Map<String, dynamic>>.from(results[2] as List);
      final classes = List<Map<String, dynamic>>.from(results[3] as List);
      final allSetups = List<Map<String, dynamic>>.from(results[4] as List);
      final allScores = List<Map<String, dynamic>>.from(results[5] as List);
      final activeYear = results[6] as String;

      _totalStudents = studentsData.length;
      _totalTeachers = teachersData.length;

      // Compute Attendance Percentages
      if (attendance.isNotEmpty) {
        int presentCount = 0;
        int lateCount = 0;
        int absentCount = 0;

        for (var record in attendance) {
          final status = record['status'].toString().toLowerCase();
          if (status.contains('present')) {
            presentCount++;
          } else if (status.contains('late')) {
            lateCount++;
          } else if (status.contains('absent')) {
            absentCount++;
          }
        }

        int totalAtt = presentCount + lateCount + absentCount;
        if (totalAtt > 0) {
          _presentPercent = (presentCount / totalAtt) * 100;
          _latePercent = (lateCount / totalAtt) * 100;
          _absentPercent = (absentCount / totalAtt) * 100;
        }
      } else {
        _presentPercent = 0.0;
        _latePercent = 0.0;
        _absentPercent = 0.0;
      }

      // Pre-index enrolled students by (grade_level|section) for active school year
      final Map<String, List<Map<String, dynamic>>> studentsBySection = {};
      for (final s in studentsData) {
        if (s['enrollment_status']?.toString() != 'Enrolled') continue;
        final sy = s['school_year']?.toString();
        if (sy != null && sy.isNotEmpty && sy != activeYear) continue;
        final key = '${s['grade_level']}|${s['section']}';
        studentsBySection.putIfAbsent(key, () => []).add(s);
      }

      // Pre-index setups for _selectedPeriod
      final periodAliases = DatabaseHelper.getPeriodAliases(_selectedPeriod).toSet();
      final Map<String, Map<String, dynamic>> setupByClass = {};
      for (final setup in allSetups) {
        final gp = setup['grading_period']?.toString() ?? '';
        if (!periodAliases.contains(gp)) continue;
        final key = '${setup['subject_code']}|${setup['section_name']}|${setup['grade_level']}';
        setupByClass.putIfAbsent(key, () => setup);
      }

      // Pre-index scores for _selectedPeriod by (subject_code|section_name|grade_level)
      final Map<String, List<Map<String, dynamic>>> scoresByClass = {};
      for (final r in allScores) {
        final gp = r['grading_period']?.toString() ?? '';
        if (!periodAliases.contains(gp)) continue;
        final key = '${r['subject_code']}|${r['section_name']}|${r['grade_level']}';
        scoresByClass.putIfAbsent(key, () => []).add(r);
      }

      // Calculate Subject Mastery Rates in memory
      Map<String, Map<String, int>> subjectStats = {};

      for (var c in classes) {
        final subjectCode = c['subject_code'].toString();
        final subjectName = c['subject_name'].toString();
        final gradeLevel = c['grade_level'].toString();
        final section = c['section_name'].toString();

        final students = studentsBySection['$gradeLevel|$section'] ?? const [];
        if (students.isEmpty) continue;

        final classKey = '$subjectCode|$section|$gradeLevel';
        final setup = setupByClass[classKey];
        final scores = scoresByClass[classKey] ?? const [];

        // Group class scores by student_id
        final Map<String, List<Map<String, dynamic>>> scoresByStudent = {};
        for (final r in scores) {
          final sid = r['student_id']?.toString() ?? '';
          if (sid.isNotEmpty) {
            scoresByStudent.putIfAbsent(sid, () => []).add(r);
          }
        }

        if (!subjectStats.containsKey(subjectName)) {
          subjectStats[subjectName] = {'total': 0, 'failed': 0};
        }

        for (var s in students) {
          final studentId = s['student_id'].toString();
          final stScores = scoresByStudent[studentId] ?? const [];
          if (stScores.isEmpty) continue;

          double grade = 0.0;

          if (setup != null) {
            final wWW = (setup['ww_weight'] as num?)?.toDouble() ?? 30;
            final wPT = (setup['pt_weight'] as num?)?.toDouble() ?? 50;
            final wTE = (setup['te_weight'] as num?)?.toDouble() ?? 20;

            final wwAvg = _categoryAvg(studentId, 'Written Works', stScores);
            final ptAvg = _categoryAvg(studentId, 'Performance Tasks', stScores);
            final teAvg = _categoryAvg(studentId, 'Term Exams', stScores);

            double totalWeight = 0;
            double earned = 0;

            bool hasWW = stScores.any((r) => r['category'].toString().toLowerCase() == 'written works');
            bool hasPT = stScores.any((r) => r['category'].toString().toLowerCase() == 'performance tasks');
            bool hasTE = stScores.any((r) => r['category'].toString().toLowerCase() == 'term exams');

            if (hasWW) { earned += wwAvg * (wWW / 100); totalWeight += (wWW / 100); }
            if (hasPT) { earned += ptAvg * (wPT / 100); totalWeight += (wPT / 100); }
            if (hasTE) { earned += teAvg * (wTE / 100); totalWeight += (wTE / 100); }

            if (totalWeight > 0) {
              double initialGrade = earned / totalWeight;
              grade = db.transmuteGrade(initialGrade);
            }
          } else {
            double total = 0, max = 0;
            for (final r in stScores) {
              total += (r['score'] as num?)?.toDouble() ?? 0;
              max += (r['total_score'] as num?)?.toDouble() ?? 0;
            }
            if (max > 0) {
              double initialGrade = (total / max) * 100;
              grade = db.transmuteGrade(initialGrade);
            }
          }

          if (grade > 0) {
            subjectStats[subjectName]!['total'] = subjectStats[subjectName]!['total']! + 1;
            if (grade < 75) {
              subjectStats[subjectName]!['failed'] = subjectStats[subjectName]!['failed']! + 1;
            }
          }
        }
      }

      _subjectMasteryRates.clear();
      subjectStats.forEach((subject, stats) {
        if (stats['total']! > 0) {
          final total = stats['total']!;
          final passed = total - stats['failed']!;
          _subjectMasteryRates.add({
            'subject': subject,
            'rate': (passed / total) * 100,
            'total': total,
            'passed': passed,
          });
        }
      });
      _subjectMasteryRates.sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));

      // Calculate Trend Data (1st Term, 2nd Term, 3rd Term) from already-fetched allScores
      List<String> quarters = ['1st Term', '2nd Term', '3rd Term'];
      _trendData.clear();

      for (String q in quarters) {
        final scoresQ = allScores.where((r) => r['grading_period'] == q).toList();
        if (scoresQ.isEmpty) {
          _trendData.add(0.0);
        } else {
          double totalScore = 0;
          double totalMax = 0;
          for (var r in scoresQ) {
            totalScore += (r['score'] as num?)?.toDouble() ?? 0;
            totalMax += (r['total_score'] as num?)?.toDouble() ?? 0;
          }
          if (totalMax > 0) {
            _trendData.add((totalScore / totalMax) * 100);
          } else {
            _trendData.add(0.0);
          }
        }
      }

      // If no data in DB, leave arrays empty or zeroes
      // Removed mock fallback values for _trendData and _failureRates

    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted && AestheticDialogs.isNetworkError(e)) {
        AestheticDialogs.showNoInternetSnackBar(context);
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SkeletonPresets.dashboard(
        showBanner: false,
        statCount: 2,
        showChart: true,
        listCount: 3,
        padding: const EdgeInsets.all(16),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: const Color(0xFF1664C5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
          _buildSummaryCard(
            title: 'Total Students',
            value: '$_totalStudents',
            percentage: '', 
            icon: Icons.people,
            iconColor: const Color(0xFF1664C5),
            iconBgColor: const Color(0xFFD6EAFF),
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            title: 'Total Teachers',
            value: '$_totalTeachers',
            percentage: '', 
            icon: Icons.person,
            iconColor: const Color(0xFF00A364),
            iconBgColor: const Color(0xFFD9F4E5),
          ),
          const SizedBox(height: 16),

          // Student Performance Trend Chart
          _buildTrendChartCard(),
          const SizedBox(height: 16),

          // Subject Performance & Mastery Rates
          _buildSubjectMasteryCard(),
          const SizedBox(height: 16),

          // Attendance Overview
          _buildAttendanceOverviewCard(),
        ],
      ),
    ));
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? percentage,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 28,
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (percentage != null && percentage.isNotEmpty)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.arrow_upward, color: Color(0xFF00A364), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        percentage,
                        style: const TextStyle(
                          color: Color(0xFF00A364),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'from last month',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Student Performance Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Text('Per Term', style: TextStyle(fontSize: 12, color: Colors.black87)),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black87),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.black.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.black54, fontSize: 12);
                        Widget text;
                        switch (value.toInt()) {
                          case 0: text = const Text('1st Term', style: style); break;
                          case 1: text = const Text('2nd Term', style: style); break;
                          case 2: text = const Text('3rd Term', style: style); break;
                          default: text = const Text('', style: style); break;
                        }
                        return SideTitleWidget(meta: meta, child: text);
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: _trendData.length > 1 ? (_trendData.length - 1).toDouble() : 2,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: _trendData.isNotEmpty
                        ? [
                            for (int i = 0; i < _trendData.length; i++)
                              FlSpot(i.toDouble(), _trendData[i]),
                          ]
                        : const [
                            FlSpot(0, 0),
                            FlSpot(1, 0),
                            FlSpot(2, 0),
                          ],
                    isCurved: true,
                    color: const Color(0xFF1664C5),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1664C5).withValues(alpha: 0.3),
                          const Color(0xFF1664C5).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Container(width: 16, height: 4, color: const Color(0xFF1664C5)),
              const SizedBox(width: 8),
              const Text('Average Performance (%)', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectMasteryCard() {
    final colors = [
      const Color(0xFF059669),
      const Color(0xFF0284C7),
      const Color(0xFF2563EB),
      const Color(0xFFD97706),
      const Color(0xFF8B5CF6),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Subject Performance & Mastery Rates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.insights_rounded, color: Color(0xFF2563EB), size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                'Learners meeting competency standards (≥75%)',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  isDense: true,
                  items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPeriod = val);
                      _loadDashboardData();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...(_showAllMasteryRates ? _subjectMasteryRates : _subjectMasteryRates.take(5).toList()).asMap().entries.map((entry) {
             int idx = entry.key;
             Map<String, dynamic> item = entry.value;
             final double rate = (item['rate'] as num).toDouble();
             return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildMasteryBar(
                  item['subject'],
                  rate / 100,
                  '${rate.toStringAsFixed(1)}%',
                  colors[idx % colors.length],
                  colors[idx % colors.length],
                ),
             );
          }),
          if (_subjectMasteryRates.isNotEmpty) const SizedBox(height: 8),
          _buildViewMasteryReportButton(),
        ],
      ),
    );
  }

  Widget _buildMasteryBar(String subject, double value, String percentageStr, Color barColor, Color percentColor) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            subject,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.black.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            percentageStr,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: percentColor),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Attendance Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Icon(Icons.info_outline, color: Colors.black38, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'This Month',
            style: TextStyle(color: Colors.black45, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            color: const Color(0xFF10B981), // Present - Green
                            value: _presentPercent,
                            title: '',
                            radius: 16,
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFF59E0B), // Late - Orange
                            value: _latePercent,
                            title: '',
                            radius: 16,
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFEF4444), // Absent - Red
                            value: _absentPercent,
                            title: '',
                            radius: 16,
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_presentPercent.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Present',
                            style: TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildLegendItem(const Color(0xFF10B981), 'Present', '${_presentPercent.toStringAsFixed(1)}%'),
                    const SizedBox(height: 12),
                    _buildLegendItem(const Color(0xFFF59E0B), 'Late', '${_latePercent.toStringAsFixed(1)}%'),
                    const SizedBox(height: 12),
                    _buildLegendItem(const Color(0xFFEF4444), 'Absent', '${_absentPercent.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildViewReportButton(),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String percentage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
        Text(percentage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildViewMasteryReportButton() {
    if (_subjectMasteryRates.length <= 5) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth >= 600;
        return Align(
          alignment: isWeb ? Alignment.centerLeft : Alignment.center,
          child: SizedBox(
            width: isWeb ? 220 : double.infinity,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllMasteryRates = !_showAllMasteryRates;
                });
              },
              icon: Icon(_showAllMasteryRates ? Icons.expand_less : Icons.expand_more, size: 18),
              label: Text(_showAllMasteryRates ? 'Show Less' : 'View All Subjects'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1664C5),
                backgroundColor: const Color(0xFFE6F0FA),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewReportButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth >= 600;
        return Align(
          alignment: isWeb ? Alignment.centerLeft : Alignment.center,
          child: SizedBox(
            width: isWeb ? 220 : double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      backgroundColor: const Color(0xFFF1F5F9), // Match standard app background
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        iconTheme: const IconThemeData(color: Colors.black87),
                      ),
                      body: const ReportsGenerationScreen(username: 'admin'),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.bar_chart, size: 18),
              label: const Text('View Full Report'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1664C5),
                backgroundColor: const Color(0xFFE6F0FA),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


