import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ClassEvaluationReportScreen extends StatelessWidget {
  final String className;
  final String subjectCode;
  final String gradingPeriod;
  final List<Map<String, dynamic>> studentGrades; 
  // expects keys: 'name', 'id', 'grade' (double), 'isPassed' (bool)

  const ClassEvaluationReportScreen({
    super.key,
    required this.className,
    required this.subjectCode,
    required this.gradingPeriod,
    required this.studentGrades,
  });

  @override
  Widget build(BuildContext context) {
    // Computations
    int totalStudents = studentGrades.length;
    int passed = studentGrades.where((s) => s['isPassed'] == true).length;
    double passingRate = totalStudents > 0 ? (passed / totalStudents) * 100 : 0;
    
    double classAvg = 0;
    double highest = 0;
    double lowest = 100;
    
    if (totalStudents > 0) {
      classAvg = studentGrades.fold(0.0, (sum, s) => sum + (s['grade'] as double)) / totalStudents;
      highest = studentGrades.map((s) => s['grade'] as double).reduce((a, b) => a > b ? a : b);
      lowest = studentGrades.map((s) => s['grade'] as double).reduce((a, b) => a < b ? a : b);
    }

    // Top Performers & Needs Attention
    List<Map<String, dynamic>> sortedStudents = List.from(studentGrades)
      ..sort((a, b) => (b['grade'] as double).compareTo(a['grade'] as double));
      
    List<Map<String, dynamic>> topPerformers = sortedStudents.take(3).toList();
    List<Map<String, dynamic>> needsAttention = sortedStudents.where((s) => (s['grade'] as double) < 75).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F52BA),
        elevation: 0,
        title: const Text('Detailed Evaluation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF0F52BA),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectCode,
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              className,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          gradingPeriod,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 2. Quick Stats Overview
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Class Average', classAvg > 0 ? '${classAvg.toStringAsFixed(1)}%' : '--', Icons.analytics, const Color(0xFF3B82F6))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Passing Rate', '${passingRate.toStringAsFixed(0)}%', Icons.check_circle, const Color(0xFF10B981))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Highest Grade', highest > 0 ? '${highest.toStringAsFixed(1)}%' : '--', Icons.emoji_events, const Color(0xFFF59E0B))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Lowest Grade', lowest < 100 ? '${lowest.toStringAsFixed(1)}%' : '--', Icons.warning_rounded, const Color(0xFFEF4444))),
                    ],
                  ),
                ],
              ),
            ),
            
            // 3. Visual Analytics (Bar Chart)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Grade Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: _buildGradeDistributionChart(studentGrades),
                    ),
                  ],
                ),
              ),
            ),
            
            // 4. Student Highlights
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Class Highlights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildHighlightPanel(
                          title: '🌟 Top Performers',
                          students: topPerformers,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildHighlightPanel(
                          title: '⚠️ Needs Attention',
                          students: needsAttention,
                          color: const Color(0xFFEF4444),
                          emptyMessage: 'No students at risk!',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 5. Detailed Class Roster
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Detailed Roster', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    ),
                    const Divider(height: 1),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedStudents.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final student = sortedStudents[index];
                        final grade = student['grade'] as double;
                        final isPassed = student['isPassed'] as bool;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE2E8F0),
                            child: Text(
                              student['name'].toString().isNotEmpty ? student['name'].toString()[0].toUpperCase() : '?',
                              style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(student['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('LRN: ${student['id']}', style: const TextStyle(fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPassed ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              grade > 0 ? grade.toStringAsFixed(1) : 'N/A',
                              style: TextStyle(
                                color: isPassed ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildHighlightPanel({required String title, required List<Map<String, dynamic>> students, required Color color, String emptyMessage = 'No data'}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 12),
          if (students.isEmpty)
            Text(emptyMessage, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
          else
            ...students.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      s['name'],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    (s['grade'] as double).toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildGradeDistributionChart(List<Map<String, dynamic>> students) {
    int outstanding = 0; // 90-100
    int verySatisfactory = 0; // 85-89
    int satisfactory = 0; // 80-84
    int fair = 0; // 75-79
    int failed = 0; // Below 75

    for (var s in students) {
      double g = s['grade'] as double;
      if (g == 0) continue;
      if (g >= 90) outstanding++;
      else if (g >= 85) verySatisfactory++;
      else if (g >= 80) satisfactory++;
      else if (g >= 75) fair++;
      else failed++;
    }

    double maxY = [outstanding, verySatisfactory, satisfactory, fair, failed]
        .map((e) => e.toDouble())
        .reduce((a, b) => a > b ? a : b);
    if (maxY < 5) maxY = 5;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 10);
                String text;
                switch (value.toInt()) {
                  case 0: text = '90-100'; break;
                  case 1: text = '85-89'; break;
                  case 2: text = '80-84'; break;
                  case 3: text = '75-79'; break;
                  case 4: text = '< 75'; break;
                  default: text = ''; break;
                }
                return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(text, style: style));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeBarData(0, outstanding.toDouble(), const Color(0xFF3B82F6)),
          _makeBarData(1, verySatisfactory.toDouble(), const Color(0xFF10B981)),
          _makeBarData(2, satisfactory.toDouble(), const Color(0xFFF59E0B)),
          _makeBarData(3, fair.toDouble(), const Color(0xFF8B5CF6)),
          _makeBarData(4, failed.toDouble(), const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 22,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 5, // Just for some background track
            color: const Color(0xFFF1F5F9),
          ),
        ),
      ],
    );
  }
}
