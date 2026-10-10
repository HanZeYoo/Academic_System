import 'package:flutter/material.dart';
import 'parent_notification_screen.dart';
import '../database_helper.dart';

class StudentEvaluationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> student;
  final String subjectName;
  final String gradingPeriod;
  final List<Map<String, dynamic>> scores;
  final Map<String, dynamic>? assessmentSetup;
  final double attendancePct;

  const StudentEvaluationDetailScreen({
    super.key,
    required this.student,
    required this.subjectName,
    required this.gradingPeriod,
    required this.scores,
    this.assessmentSetup,
    this.attendancePct = 0.0,
  });

  double _categoryAvg(String category) {
    final s = scores.where((r) => 
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

  double _computeGrade() {
    if (scores.isEmpty) return 0.0;
    if (assessmentSetup != null) {
      final wWW = (assessmentSetup!['ww_weight'] as num?)?.toDouble() ?? 30;
      final wPT = (assessmentSetup!['pt_weight'] as num?)?.toDouble() ?? 50;
      final wTE = (assessmentSetup!['te_weight'] as num?)?.toDouble() ?? 20;
      final wAttendance = (assessmentSetup!['attendance_weight'] as num?)?.toDouble() ?? 0;

      final wwAvg = _categoryAvg('Written Works');
      final ptAvg = _categoryAvg('Performance Tasks');
      final teAvg = _categoryAvg('Term Exams');

      double totalWeight = 0;
      double earned = 0;

      bool hasWW = scores.any((r) => r['category'].toString().toLowerCase() == 'written works');
      bool hasPT = scores.any((r) => r['category'].toString().toLowerCase() == 'performance tasks');
      bool hasTE = scores.any((r) => r['category'].toString().toLowerCase() == 'term exams');

      if (hasWW) { earned += wwAvg * (wWW / 100); totalWeight += (wWW / 100); }
      if (hasPT) { earned += ptAvg * (wPT / 100); totalWeight += (wPT / 100); }
      if (hasTE) { earned += teAvg * (wTE / 100); totalWeight += (wTE / 100); }
      
      if (wAttendance > 0) {
        earned += attendancePct * (wAttendance / 100);
        totalWeight += (wAttendance / 100);
      }

      if (totalWeight == 0) return 0.0;
      double initialGrade = earned / totalWeight;
      return DatabaseHelper().transmuteGrade(initialGrade);
    }

    double total = 0, max = 0;
    for (final r in scores) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max   += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    if (max == 0) return 0.0;
    double initialGrade = (total / max) * 100;
    return DatabaseHelper().transmuteGrade(initialGrade);
  }

  @override
  Widget build(BuildContext context) {
    final overallGrade = _computeGrade();
    final isPassed = overallGrade >= 75;
    final hasScores = scores.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F52BA),
        elevation: 0,
        title: const Text('Evaluation Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(overallGrade, isPassed, hasScores),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Performance Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  _buildBreakdownCard(),
                  const SizedBox(height: 24),
                  const Text('Academic Snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  _buildAcademicSnapshot(isPassed),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              backgroundColor: const Color(0xFFF1F5F9),
                              appBar: AppBar(
                                backgroundColor: const Color(0xFF0F52BA),
                                elevation: 0,
                                title: const Text('Notify Parent', style: TextStyle(color: Colors.white)),
                                leading: IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              body: ParentNotificationScreen(
                                username: 'admin', 
                                initialStudentId: student['student_id']?.toString(),
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Notify Parents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F52BA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double overallGrade, bool isPassed, bool hasScores) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F52BA),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  student['name']?.toString().isNotEmpty == true ? student['name'].toString()[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['name']?.toString() ?? 'Unknown Student',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LRN: ${student['student_id'] ?? 'N/A'}  •  ${student['grade_level']} - ${student['section']}',
                      style: TextStyle(fontSize: 14, color: Colors.blue.shade100),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: !hasScores
                            ? Colors.grey.withOpacity(0.4)
                            : isPassed
                                ? Colors.greenAccent.withOpacity(0.2)
                                : Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !hasScores ? Colors.grey : isPassed ? Colors.greenAccent : Colors.redAccent,
                        )
                      ),
                      child: Text(
                        !hasScores ? 'No Data' : isPassed ? 'Passed' : 'At-Risk',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: !hasScores ? Colors.white : isPassed ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overall Grade', style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      hasScores ? '${overallGrade.toStringAsFixed(1)}%' : 'N/A',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: !hasScores
                            ? const Color(0xFF1E293B)
                            : isPassed
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(subjectName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F52BA))),
                    const SizedBox(height: 4),
                    Text(gradingPeriod, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _buildProgressRow('Written Works', _categoryAvg('Written Works'), assessmentSetup?['ww_weight'] ?? 30, const Color(0xFF0D6EFD)),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _buildProgressRow('Performance Tasks', _categoryAvg('Performance Tasks'), assessmentSetup?['pt_weight'] ?? 50, const Color(0xFF198754)),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _buildProgressRow('Term Exams', _categoryAvg('Term Exams'), assessmentSetup?['te_weight'] ?? 20, const Color(0xFFDC3545)),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _buildProgressRow('Attendance', attendancePct, assessmentSetup?['attendance_weight'] ?? 0, const Color(0xFF0DCAF0)),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double score, dynamic weight, Color color) {
    final double parsedWeight = (weight as num?)?.toDouble() ?? 0.0;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 2),
              Text('Weight: ${parsedWeight.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: color.withOpacity(0.15),
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 50,
          child: Text(
            score > 0 ? '${score.toStringAsFixed(1)}%' : '--',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: score == 0 ? Colors.grey : color),
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicSnapshot(bool isPassed) {
    final attendanceStr = '${attendancePct.toStringAsFixed(1)}%';
    
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_available, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text('Attendance', style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(attendanceStr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                        color: isPassed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPassed ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        color: isPassed ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Risk Status', style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isPassed ? 'On-Track' : 'At-Risk',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isPassed ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
