import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reports_generation_screen.dart';
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

  // Failure Rates
  List<Map<String, dynamic>> _failureRates = [];

  // Trend Data (Q1, Q2, Q3, Q4)
  List<double> _trendData = [0.0, 0.0, 0.0, 0.0];

  String _selectedPeriod = '1st Quarter';
  static const _periods = [
    '1st Quarter',
    '2nd Quarter',
    '3rd Quarter',
    '4th Quarter',
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
      // Get Total Students
      final studentsData = await db.getStudents();
      _totalStudents = studentsData.length;

      // Get Total Teachers
      final teachersData = await db.getTeachers();
      _totalTeachers = teachersData.length;

      // Get Attendance data
      final attendance = await Supabase.instance.client.from('attendance').select();
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

      // Calculate Failure Rates
      final classes = await db.getSubjectClasses();
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
          double grade = 0.0;
          
          if (setup != null) {
            final wQuiz = (setup['quiz_weight'] as num?)?.toDouble() ?? 20;
            final wAssignment = (setup['assignment_weight'] as num?)?.toDouble() ?? 15;
            final wActivity = (setup['activity_weight'] as num?)?.toDouble() ?? 20;
            final wProject = (setup['project_weight'] as num?)?.toDouble() ?? 15;
            final wExam = (setup['exam_weight'] as num?)?.toDouble() ?? 30;

            final qAvg = _categoryAvg(studentId, 'Quiz', scores);
            final asgAvg = _categoryAvg(studentId, 'Assignment', scores);
            final actAvg = _categoryAvg(studentId, 'Activity', scores);
            final prjAvg = _categoryAvg(studentId, 'Project', scores);
            final exmAvg = _categoryAvg(studentId, 'Exam', scores);

            if (qAvg == 0 && asgAvg == 0 && actAvg == 0 && prjAvg == 0 && exmAvg == 0) {
              if (scores.where((r) => r['student_id'].toString() == studentId).isEmpty) continue;
            }

            grade = (qAvg * (wQuiz / 100)) +
                (asgAvg * (wAssignment / 100)) +
                (actAvg * (wActivity / 100)) +
                (prjAvg * (wProject / 100)) +
                (exmAvg * (wExam / 100));
          } else {
             final stScores = scores.where((r) => r['student_id'].toString() == studentId).toList();
             if (stScores.isNotEmpty) {
                double total = 0, max = 0;
                for (final r in stScores) {
                  total += (r['score'] as num?)?.toDouble() ?? 0;
                  max += (r['total_score'] as num?)?.toDouble() ?? 0;
                }
                if (max > 0) grade = (total / max) * 100;
             } else {
                continue;
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

      _failureRates.clear();
      subjectStats.forEach((subject, stats) {
        if (stats['total']! > 0) {
          _failureRates.add({
            'subject': subject,
            'rate': (stats['failed']! / stats['total']!) * 100
          });
        }
      });
      _failureRates.sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));
      if (_failureRates.length > 5) {
         _failureRates = _failureRates.sublist(0, 5);
      }
      
      // Calculate Trend Data (Q1, Q2, Q3, Q4)
      List<String> quarters = ['1st Quarter', '2nd Quarter', '3rd Quarter', '4th Quarter'];
      _trendData.clear();
      final allScores = await Supabase.instance.client.from('scores').select();
      
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
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

          // Failure Rate by Subject
          _buildFailureRateCard(),
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
                    Text('Quarterly', style: TextStyle(fontSize: 12, color: Colors.black87)),
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
                      color: Colors.black.withOpacity(0.05),
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
                          case 0: text = const Text('Q1', style: style); break;
                          case 1: text = const Text('Q2', style: style); break;
                          case 2: text = const Text('Q3', style: style); break;
                          case 3: text = const Text('Q4', style: style); break;
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
                maxX: 3,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, _trendData[0]),
                      FlSpot(1, _trendData[1]),
                      FlSpot(2, _trendData[2]),
                      FlSpot(3, _trendData[3]),
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
                          const Color(0xFF1664C5).withOpacity(0.3),
                          const Color(0xFF1664C5).withOpacity(0.0),
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

  Widget _buildFailureRateCard() {
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6)
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
              Text(
                'Failure Rate by Subject',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Grading Period',
                style: TextStyle(color: Colors.black45, fontSize: 13),
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
          ..._failureRates.asMap().entries.map((entry) {
             int idx = entry.key;
             Map<String, dynamic> item = entry.value;
             return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildFailureBar(
                  item['subject'],
                  item['rate'] / 100,
                  '${item['rate'].toStringAsFixed(1)}%',
                  const Color(0xFF1664C5),
                  colors[idx % colors.length]
                ),
             );
          }).toList(),
          if (_failureRates.isNotEmpty) const SizedBox(height: 8),
          _buildViewReportButton(),
        ],
      ),
    );
  }

  Widget _buildFailureBar(String subject, double value, String percentageStr, Color barColor, Color percentColor) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            subject,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 32,
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

  Widget _buildViewReportButton() {
    return SizedBox(
      width: double.infinity,
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
    );
  }
}
