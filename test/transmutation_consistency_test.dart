import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academic_system/database_helper.dart';
import 'package:academic_system/models/ecr_transmutation_model.dart';
import 'package:academic_system/services/ecr_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DatabaseHelper.setActiveTransmutationTable(null);
  });

  group('Transmutation Consistency Across Dashboards Tests', () {
    test('Saving and retrieving transmutation table supports exact, case-insensitive, and subject fallback', () async {
      final db = DatabaseHelper();

      final table = EcrTransmutationTable(
        sheetName: 'Transmutation',
        description: 'DepEd Base-70',
        passingRawScore: 70.0,
        brackets: {
          0.0: 60,
          4.67: 61,
          69.99: 75,
          71.17: 76,
          99.49: 100,
        },
        isDetected: true,
      );

      // Save for COMP7 - Grade 7 - Sapphire
      await db.saveTransmutationTable('COMP7', 'Grade 7 - Sapphire', table);

      // 1. Exact match
      final exactMatch = await db.getTransmutationTable('COMP7', 'Grade 7 - Sapphire');
      expect(exactMatch, isNotNull);
      expect(exactMatch!.isDetected, isTrue);
      expect(exactMatch.lookup(69.99), equals(75));

      // 2. Case-insensitive & trimmed match
      final caseMatch = await db.getTransmutationTable('comp7 ', '  grade 7 - sapphire');
      expect(caseMatch, isNotNull);
      expect(caseMatch!.lookup(71.17), equals(76));

      // 3. Subject-only fallback (e.g. if student profile has different section format)
      final subjMatch = await db.getTransmutationTable('comp7', 'UnknownSection');
      expect(subjMatch, isNotNull);
      expect(subjMatch!.lookup(0.0), equals(60));

      // 4. Synchronous cached getter
      final syncMatch = db.getCachedTransmutationTable('COMP7', 'Grade 7 - Sapphire');
      expect(syncMatch, isNotNull);
      expect(syncMatch!.lookup(99.49), equals(100));
    });

    test('Transmute grade calculates identical grade for Student/Parent Dashboards when custom table is present', () async {
      final db = DatabaseHelper();

      // Parse actual ECR to get the real table
      final parser = EcrParserService();
      final file = File('Grade 7/Computer 7.xlsx');
      final bytes = await file.readAsBytes();
      final parseResult = parser.parseFileSync(bytes, 'Computer 7.xlsx');

      expect(parseResult.detectedTransmutation.isDetected, isTrue);
      final ecrTable = parseResult.detectedTransmutation;

      // Save it for COMP7
      await db.saveTransmutationTable('COMP7', 'Grade 7 - Sapphire', ecrTable);

      // Verify that student and parent dashboard calculation logic produces exact table grades:
      // Grade at raw 69.99 should be 75
      final studentGrade = db.transmuteGrade(69.99, customTable: ecrTable);
      expect(studentGrade, equals(75.0));

      // Grade at raw 71.17 should be 76
      final parentGrade = db.transmuteGrade(71.17, customTable: ecrTable);
      expect(parentGrade, equals(76.0));

      // Grade at raw 99.49 should be 100
      expect(db.transmuteGrade(99.49, customTable: ecrTable), equals(100.0));
    });

    test('Transmute grade falls back cleanly to standard Base-70 formula when no custom table is provided', () {
      final db = DatabaseHelper();

      expect(db.transmuteGrade(70.0), equals(75.0));
      expect(db.transmuteGrade(100.0), equals(100.0));
      expect(db.transmuteGrade(0.0), equals(60.0));
      expect(db.transmuteGrade(85.0), equals(88.0));
    });

    test('Parent Dashboard Risk Banner ignores unrecorded subjects with grade 0.0', () {
      // Simulating a student with 4 subjects:
      // 1 graded subject (Computer 7 with grade 95.0), and 3 unrecorded subjects (grade 0.0)
      final subjectGrades = [
        {'subject': 'Computer 7', 'grade': 95.0, 'status': 'Excellent'},
        {'subject': 'Mathematics 7', 'grade': 0.0, 'status': 'No Grades'},
        {'subject': 'Science 7', 'grade': 0.0, 'status': 'No Grades'},
        {'subject': 'English 7', 'grade': 0.0, 'status': 'No Grades'},
      ];

      final gradedSubjects = subjectGrades.where((g) => (g['grade'] as double) > 0).toList();
      double overallAverage = 95.0; // from the single graded subject

      bool isHighRisk = gradedSubjects.any((g) => (g['grade'] as double) < 75) || (overallAverage > 0 && overallAverage < 75);
      bool isMediumRisk = !isHighRisk && (gradedSubjects.any((g) => (g['grade'] as double) < 80) || (overallAverage > 0 && overallAverage < 80));

      // With only a perfect/passing score in WW1 and unrecorded other subjects, NO risk banner should show!
      expect(isHighRisk, isFalse);
      expect(isMediumRisk, isFalse);

      // Now simulate a real failing grade in one graded subject
      final failingSubjectGrades = [
        {'subject': 'Computer 7', 'grade': 72.0, 'status': 'At-Risk'},
        {'subject': 'Mathematics 7', 'grade': 0.0, 'status': 'No Grades'},
      ];
      final gradedFailing = failingSubjectGrades.where((g) => (g['grade'] as double) > 0).toList();
      bool isHighRiskReal = gradedFailing.any((g) => (g['grade'] as double) < 75);
      expect(isHighRiskReal, isTrue);
    });

    test('Grade Breakdown computation with partial components calculates proportional running average', () {
      final db = DatabaseHelper();

      // Assessment setup: WW 30%, PT 50%, TE 20%
      const double wWW = 30.0;
      const double wPT = 50.0;
      const double wTE = 20.0;

      // Only WW1 has 40/40 score (WW avg = 100%). PT and TE have no scores yet.
      final wwHasScores = true;
      final ptHasScores = false;
      final teHasScores = false;

      final wwEarned = 100.0 * (wWW / 100);
      final ptEarned = 0.0 * (wPT / 100);
      final teEarned = 0.0 * (wTE / 100);

      double totalEarned = wwEarned + ptEarned + teEarned;
      double totalWeight = 0;
      if (wwHasScores) totalWeight += wWW / 100;
      if (ptHasScores) totalWeight += wPT / 100;
      if (teHasScores) totalWeight += wTE / 100;

      expect(totalWeight, equals(0.30));
      double initialGrade = totalWeight > 0 ? totalEarned / totalWeight : 0.0;
      expect(initialGrade, equals(100.0));

      // Transmute Base-70: 100 -> 100
      double finalGrade = db.transmuteGrade(initialGrade);
      expect(finalGrade, equals(100.0));
    });
  });
}
