import 'package:flutter/material.dart';
import 'parent_notification_screen.dart';
import '../database_helper.dart';
import '../utils/avatar_utils.dart';
import '../services/early_warning_service.dart';

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

    final sid = student['student_id']?.toString() ?? '';
    final sname = student['name']?.toString() ?? 'Student';
    final earlyWarning = EarlyWarningService.evaluateScores(
      studentId: sid,
      studentName: sname,
      subjectCode: subjectName,
      gradingPeriod: gradingPeriod,
      studentScores: scores,
    );

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
            _buildHeader(overallGrade, isPassed, hasScores, earlyWarning),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F52BA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.analytics_outlined, size: 20, color: Color(0xFF0F52BA)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Early Warning Performance Analytics',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Academic risk evaluation & performance matrix',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildEarlyWarningSection(earlyWarning),
                  const SizedBox(height: 24),
                  const Text('Performance Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  _buildBreakdownCard(),
                  const SizedBox(height: 24),
                  const Text('Academic Snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  _buildAcademicSnapshot(isPassed, earlyWarning),
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

  Widget _buildHeader(double overallGrade, bool isPassed, bool hasScores, EarlyWarningResult earlyWarning) {
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
              AvatarUtils.buildAvatar(
                photo: student['profile_picture']?.toString(),
                name: student['name']?.toString(),
                radius: 36,
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: !hasScores
                            ? Colors.white.withOpacity(0.15)
                            : earlyWarning.isAtRisk
                                ? const Color(0xFFEF4444).withOpacity(0.25)
                                : const Color(0xFF10B981).withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: !hasScores
                              ? Colors.white38
                              : earlyWarning.isAtRisk
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFF86EFAC),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            !hasScores
                                ? Icons.info_outline
                                : earlyWarning.isAtRisk
                                    ? Icons.warning_amber_rounded
                                    : Icons.verified_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            !hasScores
                                ? 'No Data'
                                : (earlyWarning.isAtRisk ? earlyWarning.shortBadgeText : 'Compliant (On-Track)'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        subjectName,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F52BA)),
                      ),
                      const SizedBox(height: 4),
                      Text(gradingPeriod, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
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

  Widget _buildAcademicSnapshot(bool isPassed, EarlyWarningResult earlyWarning) {
    final attendanceStr = '${attendancePct.toStringAsFixed(1)}%';
    final isAtRisk = earlyWarning.isAtRisk;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        color: const Color(0xFF0F52BA).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_available_outlined, color: Color(0xFF0F52BA), size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text('Attendance', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(attendanceStr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                const Text('Formative engagement', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
              border: Border.all(color: isAtRisk ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
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
                        color: !isAtRisk ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        !isAtRisk ? Icons.verified_outlined : Icons.warning_amber_rounded,
                        color: !isAtRisk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Risk Status', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        !isAtRisk ? 'On-Track' : 'At-Risk',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: !isAtRisk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: !isAtRisk ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: !isAtRisk ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                        ),
                      ),
                      child: Text(
                        !isAtRisk ? 'Normal' : 'Flagged',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: !isAtRisk ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  !isAtRisk ? 'Academic Benchmark Safe' : earlyWarning.shortBadgeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: !isAtRisk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEarlyWarningSection(EarlyWarningResult ew) {
    final isAtRisk = ew.isAtRisk;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAtRisk ? const Color(0xFFFCA5A5).withOpacity(0.8) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          if (isAtRisk)
            BoxShadow(
              color: const Color(0xFFDC2626).withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Executive Status Banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isAtRisk ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAtRisk ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAtRisk ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAtRisk ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    isAtRisk ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                    color: isAtRisk ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAtRisk ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isAtRisk ? 'STATUS: INTERVENTION REQUIRED' : 'STATUS: ACADEMICALLY COMPLIANT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isAtRisk ? const Color(0xFF991B1B) : const Color(0xFF166534),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isAtRisk
                            ? 'At-Risk: ${ew.ruleTriggered}'
                            : 'Satisfactory (Within Safe Thresholds)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isAtRisk ? const Color(0xFF991B1B) : const Color(0xFF14532D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Criteria Subheader ──
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F52BA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ACADEMIC PERFORMANCE MATRIX',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Task Submission Compliance Card ──
          _buildCriterionCard(
            title: 'Task Submission Compliance',
            subtitle: 'Evaluates learner participation, formative turn-in & engagement',
            currentCount: ew.missedCount,
            unitLabel: 'unrecorded / missed assessment(s)',
            thresholdFormula: 'Threshold: Max 2 (Breached at > 2)',
            isTriggered: ew.isRuleATriggered,
            icon: ew.isRuleATriggered ? Icons.assignment_late_outlined : Icons.assignment_turned_in_outlined,
            progressValue: (ew.missedCount / 3.0).clamp(0.0, 1.0),
            safeLabel: '0 - 2 Missed (Safe)',
            breachedLabel: '> 2 (At-Risk)',
          ),

          const SizedBox(height: 12),

          // ── Grade Benchmark Performance Card ──
          _buildCriterionCard(
            title: 'Grade Benchmark Performance',
            subtitle: 'Evaluates score distribution against the 75 passing standard',
            currentCount: ew.subPassingCount,
            unitLabel: 'assessment score(s) transmuted below 75.0',
            thresholdFormula: 'Threshold: Max 2 (Breached at ≥ 3)',
            isTriggered: ew.isRuleBTriggered,
            icon: ew.isRuleBTriggered ? Icons.trending_down_rounded : Icons.trending_up_rounded,
            progressValue: (ew.subPassingCount / 3.0).clamp(0.0, 1.0),
            safeLabel: '0 - 2 Sub-75 (Safe)',
            breachedLabel: '≥ 3 (At-Risk)',
          ),

          const SizedBox(height: 16),

          // ── Pedagogical Action Directive Card (Overflow-Proof) ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isAtRisk ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAtRisk ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: isAtRisk ? const Color(0xFFD97706) : const Color(0xFF0F52BA),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Pedagogical Action Directive',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAtRisk ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Profile: ${ew.riskProfile}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isAtRisk ? const Color(0xFFB45309) : const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAtRisk
                      ? 'Action Directive: Proactive pedagogical intervention required. Initiate parent alignment through the NotifyEd SMS/push notification module and schedule targeted remedial activities before quarterly grade finalization.'
                      : 'Status: Learner demonstrates steady academic pacing and submission diligence. Standard instructional monitoring continues.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: isAtRisk ? const Color(0xFF92400E) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Academic Intelligence Footer Tag ──
          const Center(
            child: Text(
              'NotifyEd Academic Intelligence • Academic Performance Matrix',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriterionCard({
    required String title,
    required String subtitle,
    required int currentCount,
    required String unitLabel,
    required String thresholdFormula,
    required bool isTriggered,
    required IconData icon,
    required double progressValue,
    required String safeLabel,
    required String breachedLabel,
  }) {
    final statusColor = isTriggered ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final statusBg = isTriggered ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final statusBorder = isTriggered ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC);
    final tileBg = isTriggered ? const Color(0xFFFFF7F7) : const Color(0xFFF8FAFC);
    final tileBorder = isTriggered ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0);

    // Color progress bar depending on severity
    Color progressColor;
    if (isTriggered) {
      progressColor = const Color(0xFFDC2626);
    } else if (currentCount == 2) {
      progressColor = const Color(0xFFF59E0B); // Pre-warning verge
    } else if (currentCount > 0) {
      progressColor = const Color(0xFF3B82F6);
    } else {
      progressColor = const Color(0xFFCBD5E1);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isTriggered ? const Color(0xFFFEE2E2) : const Color(0xFFE2E8F0).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isTriggered ? 'Breached' : 'Compliant',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$currentCount',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isTriggered ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  unitLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isTriggered ? const Color(0xFFDC2626) : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            thresholdFormula,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue == 0 ? 0.04 : progressValue,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              color: progressColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  safeLabel,
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                breachedLabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isTriggered ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
