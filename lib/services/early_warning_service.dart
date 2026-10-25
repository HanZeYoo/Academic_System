import '../database_helper.dart';

/// Result container for SO1 Multi-Criteria At-Risk Evaluation.
class EarlyWarningResult {
  final String studentId;
  final String studentName;
  final String subjectCode;
  final String gradingPeriod;
  final int missedCount;
  final int subPassingCount;
  final bool isRuleATriggered; // Threshold: > 2 missed assessments
  final bool isRuleBTriggered; // Threshold: >= 3 scores below 75
  final bool isAtRisk;
  final String ruleTriggered; // 'Rule A', 'Rule B', 'Rule A & Rule B', or 'None'
  final String riskProfile; // Target Risk Profile
  final List<String> details;

  EarlyWarningResult({
    required this.studentId,
    required this.studentName,
    required this.subjectCode,
    required this.gradingPeriod,
    required this.missedCount,
    required this.subPassingCount,
    required this.isRuleATriggered,
    required this.isRuleBTriggered,
    required this.isAtRisk,
    required this.ruleTriggered,
    required this.riskProfile,
    required this.details,
  });

  String get statusText => isAtRisk ? 'At-Risk' : 'On-Track';

  String get shortBadgeText {
    if (!isAtRisk) return 'Passed';
    if (isRuleATriggered && isRuleBTriggered) return 'At-Risk (Dual Factors)';
    if (isRuleATriggered) return 'At-Risk (Non-Submission)';
    return 'At-Risk (Sub-Passing)';
  }
}

/// SO1: Rule-Based Multi-Criteria Early Warning Detection Module.
///
/// Implements DepEd Order No. 015, s. 2026 passing standards:
/// - Rule A (Learner Engagement): Flags students with > 2 missed assessments / unrecorded tasks.
/// - Rule B (Academic Performance): Flags students with >= 3 cumulative scores below 75.
class EarlyWarningService {
  static const int thresholdRuleAMissed = 2; // > 2 triggers Rule A
  static const int thresholdRuleBSubPassing = 3; // >= 3 triggers Rule B
  static const double passingGradeThreshold = 75.0; // DepEd passing mark

  /// Evaluates a student given their list of assessment scores in a subject & grading period.
  /// Runs deterministically with O(1) evaluation overhead per student.
  static EarlyWarningResult evaluateScores({
    required String studentId,
    required String studentName,
    required String subjectCode,
    required String gradingPeriod,
    required List<Map<String, dynamic>> studentScores,
  }) {
    int missedCount = 0;
    int subPassingCount = 0;
    final List<String> details = [];

    for (final scoreEntry in studentScores) {
      final scoreVal = (scoreEntry['score'] as num?)?.toDouble() ?? 0.0;
      final totalVal = (scoreEntry['total_score'] as num?)?.toDouble() ?? 0.0;

      if (totalVal <= 0.0) continue;

      // Rule A: Missed assessment / non-submission (score is 0 or unsubmitted)
      if (scoreVal <= 0.0) {
        missedCount++;
      } else {
        // Rule B: Sub-passing assessment (evaluated against passing standard of 75)
        final rawPct = (scoreVal / totalVal) * 100.0;
        final transmuted = DatabaseHelper().transmuteGrade(rawPct);
        if (transmuted < passingGradeThreshold) {
          subPassingCount++;
        }
      }
    }

    final bool isRuleATriggered = missedCount > thresholdRuleAMissed;
    final bool isRuleBTriggered = subPassingCount >= thresholdRuleBSubPassing;
    final bool isAtRisk = isRuleATriggered || isRuleBTriggered;

    String ruleTriggered = 'None';
    String riskProfile = 'On-Track';

    if (isRuleATriggered && isRuleBTriggered) {
      ruleTriggered = 'Non-Submission & Sub-Passing Scores';
      riskProfile = 'Non-participation & chronic academic difficulty';
      details.add('Assessment Submission: $missedCount unrecorded (Threshold: > 2)');
      details.add('Grade Performance: $subPassingCount scores below 75 (Threshold: >= 3)');
    } else if (isRuleATriggered) {
      ruleTriggered = 'Assessment Non-Submission';
      riskProfile = 'Non-participation & disengagement';
      details.add('Assessment Submission: $missedCount unrecorded (Threshold: > 2)');
    } else if (isRuleBTriggered) {
      ruleTriggered = 'Sub-Passing Scores';
      riskProfile = 'Chronic academic difficulty';
      details.add('Grade Performance: $subPassingCount scores below 75 (Threshold: >= 3)');
    } else {
      details.add('Academic indicators within normal range ($missedCount missed, $subPassingCount sub-75).');
    }

    return EarlyWarningResult(
      studentId: studentId,
      studentName: studentName,
      subjectCode: subjectCode,
      gradingPeriod: gradingPeriod,
      missedCount: missedCount,
      subPassingCount: subPassingCount,
      isRuleATriggered: isRuleATriggered,
      isRuleBTriggered: isRuleBTriggered,
      isAtRisk: isAtRisk,
      ruleTriggered: ruleTriggered,
      riskProfile: riskProfile,
      details: details,
    );
  }

  /// Evaluates an entire class using the scores retrieved from the database.
  static Map<String, EarlyWarningResult> evaluateClassScores({
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> allScores,
    required String subjectCode,
    required String gradingPeriod,
  }) {
    final Map<String, EarlyWarningResult> results = {};

    for (final student in students) {
      final sid = student['student_id']?.toString() ?? '';
      final sname = student['name']?.toString() ?? 'Student';
      final studentScores = allScores.where(
        (s) => s['student_id']?.toString() == sid,
      ).toList();

      results[sid] = evaluateScores(
        studentId: sid,
        studentName: sname,
        subjectCode: subjectCode,
        gradingPeriod: gradingPeriod,
        studentScores: studentScores,
      );
    }

    return results;
  }
}
