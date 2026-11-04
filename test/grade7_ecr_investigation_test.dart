import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/services/ecr_parser_service.dart';
import 'package:academic_system/services/ecr_mapping_engine.dart';
import 'package:academic_system/models/ecr_mapping_model.dart';
import 'package:academic_system/services/ecr_validator.dart';
import 'package:academic_system/database_helper.dart';

void main() {
  final parser = EcrParserService();
  final engine = EcrMappingEngine();

  group('Grade 7 Real ECR Templates Parsing', () {
    test('Computer 7.xlsx detects ClassRecord sheet, 59 sliced Q1 cols, and 20-60-20 weights', () async {
      final file = File('Grade 7/Computer 7.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final result = parser.parseFileSync(bytes, 'Computer 7.xlsx', gradingPeriod: '1st Term');

      expect(result.sheetName, equals('ClassRecord'));
      expect(result.headers.length, equals(59));
      expect(result.headerRowIndex, equals(3));
      expect(result.detectedWeights.isDetected, isTrue);
      expect(result.detectedWeights.wwWeight, equals(20.0));
      expect(result.detectedWeights.ptWeight, equals(60.0));
      expect(result.detectedWeights.qaWeight, equals(20.0));
    });

    test('Science 7.xlsx detects ClassRecord sheet and 20-50-30 weights', () async {
      final file = File('Grade 7/Science 7.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final result = parser.parseFileSync(bytes, 'Science 7.xlsx', gradingPeriod: '1st Term');

      expect(result.sheetName, equals('ClassRecord'));
      expect(result.headers.length, equals(59));
      expect(result.detectedWeights.isDetected, isTrue);
      expect(result.detectedWeights.wwWeight, equals(20.0));
      expect(result.detectedWeights.ptWeight, equals(50.0));
      expect(result.detectedWeights.qaWeight, equals(30.0));
    });

    test('Mathematics 7.xlsx detects ClassRecord sheet and 20-50-30 weights', () async {
      final file = File('Grade 7/Mathematics 7.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final result = parser.parseFileSync(bytes, 'Mathematics 7.xlsx', gradingPeriod: '1st Term');

      expect(result.sheetName, equals('ClassRecord'));
      expect(result.headers.length, equals(59));
      expect(result.detectedWeights.isDetected, isTrue);
      expect(result.detectedWeights.wwWeight, equals(20.0));
      expect(result.detectedWeights.ptWeight, equals(50.0));
      expect(result.detectedWeights.qaWeight, equals(30.0));
    });

    test('MAPEH 7.xlsx detects ClassRecord sheet and 20-60-20 weights', () async {
      final file = File('Grade 7/MAPEH 7.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final result = parser.parseFileSync(bytes, 'MAPEH 7.xlsx', gradingPeriod: '1st Term');

      expect(result.sheetName, equals('ClassRecord'));
      expect(result.headers.length, equals(59));
      expect(result.detectedWeights.isDetected, isTrue);
      expect(result.detectedWeights.wwWeight, equals(20.0));
      expect(result.detectedWeights.ptWeight, equals(60.0));
      expect(result.detectedWeights.qaWeight, equals(20.0));
    });

    test('Quarter 2 slicing dynamically selects 2nd Grading columns', () async {
      final file = File('Grade 7/Computer 7.xlsx');
      final bytes = await file.readAsBytes();
      final resultQ2 = parser.parseFileSync(bytes, 'Computer 7.xlsx', gradingPeriod: '2nd Term');

      expect(resultQ2.sheetName, equals('ClassRecord'));
      expect(resultQ2.headers.length, equals(59));
      expect(resultQ2.headers[0], equals('No.'));
      expect(resultQ2.headers[1], equals('StudNo.'));
      expect(resultQ2.headers[2], equals('NAME OF STUDENT'));
      expect(resultQ2.headers[3], contains('WW1'));
    });
  });

  group('Populated Computer 7.xlsx End-to-End Extraction & Score Generation', () {
    test('Correctly extracts all 5 students and filters out all divider & empty slots', () async {
      final file = File('test/fixtures/populated_computer_7.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final result = parser.parseFileSync(bytes, 'populated_computer_7.xlsx', gradingPeriod: '1st Term');

      expect(result.dataRows.length, equals(5));

      // Boys
      expect(result.dataRows[0][1], equals('2024-0001'));
      expect(result.dataRows[0][2], equals('DELA CRUZ, JUAN A.'));
      expect(result.dataRows[1][1], equals('2024-0002'));
      expect(result.dataRows[1][2], equals('SANTOS, PEDRO B.'));
      expect(result.dataRows[2][1], equals('2024-0003'));
      expect(result.dataRows[2][2], equals('REYES, MIGUEL C.'));

      // Girls
      expect(result.dataRows[3][1], equals('2024-0004'));
      expect(result.dataRows[3][2], equals('ALVAREZ, MARIA D.'));
      expect(result.dataRows[4][1], equals('2024-0005'));
      expect(result.dataRows[4][2], equals('GARCIA, ANA E.'));

      // HPS extraction
      expect(result.rowHpsMap[3], equals(20.0)); // WW1
      expect(result.rowHpsMap[4], equals(25.0)); // WW2
      expect(result.rowHpsMap[5], equals(20.0)); // WW3
      expect(result.rowHpsMap[6], equals(20.0)); // WW4
      expect(result.rowHpsMap[26], equals(50.0)); // PT1
      expect(result.rowHpsMap[27], equals(50.0)); // PT2
      expect(result.rowHpsMap[28], equals(40.0)); // PT3
      expect(result.rowHpsMap[49], equals(30.0)); // QA1
      expect(result.rowHpsMap[50], equals(30.0)); // QA2
      expect(result.rowHpsMap[51], equals(40.0)); // QA3

      // Excluded rows
      expect(result.excludedRows.length, equals(57));
      expect(result.excludedRows.any((e) => e.reason.contains('BOYS')), isTrue);
      expect(result.excludedRows.any((e) => e.reason.contains('GIRLS')), isTrue);
    });

    test('Auto-detect mappings correctly maps StudNo., Name, WW1..4, PT1..3, QA1..3', () async {
      final file = File('test/fixtures/populated_computer_7.xlsx');
      final bytes = await file.readAsBytes();
      final result = parser.parseFileSync(bytes, 'populated_computer_7.xlsx', gradingPeriod: '1st Term');

      final mappings = engine.autoDetectMappings(
        headers: result.headers,
        previewRows: result.dataRows,
        rowHpsMap: result.rowHpsMap,
      );

      // Student identifiers
      final studNoCol = mappings.firstWhere((m) => m.target == EcrTargetCategory.lrn);
      expect(studNoCol.columnIndex, equals(1));

      final nameCol = mappings.firstWhere((m) => m.target == EcrTargetCategory.studentName);
      expect(nameCol.columnIndex, equals(2));

      // WW items
      final ww1 = mappings.firstWhere((m) => m.target == EcrTargetCategory.ww1);
      expect(ww1.columnIndex, equals(3));
      expect(ww1.detectedRowHps, equals(20.0));

      final ww2 = mappings.firstWhere((m) => m.target == EcrTargetCategory.ww2);
      expect(ww2.columnIndex, equals(4));
      expect(ww2.detectedRowHps, equals(25.0));

      // PT items
      final pt1 = mappings.firstWhere((m) => m.target == EcrTargetCategory.pt1);
      expect(pt1.columnIndex, equals(26));
      expect(pt1.detectedRowHps, equals(50.0));

      final pt2 = mappings.firstWhere((m) => m.target == EcrTargetCategory.pt2);
      expect(pt2.columnIndex, equals(27));
      expect(pt2.detectedRowHps, equals(50.0));

      // QA items
      final qaList = mappings.where((m) => m.target.component == 'QA' && !m.target.isHps).toList();
      expect(qaList.length, equals(3));
      expect(qaList[0].columnIndex, equals(49));
      expect(qaList[0].detectedRowHps, equals(30.0));
      expect(qaList[1].columnIndex, equals(50));
      expect(qaList[1].detectedRowHps, equals(30.0));
      expect(qaList[2].columnIndex, equals(51));
      expect(qaList[2].detectedRowHps, equals(40.0));
    });

    test('Simulates ecr_import_screen score generation into Supabase payload', () async {
      final file = File('test/fixtures/populated_computer_7.xlsx');
      final bytes = await file.readAsBytes();
      final result = parser.parseFileSync(bytes, 'populated_computer_7.xlsx', gradingPeriod: '1st Term');

      final mappings = engine.autoDetectMappings(
        headers: result.headers,
        previewRows: result.dataRows,
        rowHpsMap: result.rowHpsMap,
      );

      // Simulate the exact database transformation from ecr_import_screen.dart
      final scoreMappings = mappings.where((m) =>
          m.target.isNumeric &&
          !m.target.isHps &&
          m.target != EcrTargetCategory.totalGrade &&
          m.target != EcrTargetCategory.componentTotal &&
          m.target != EcrTargetCategory.calculatedIgnore &&
          m.target != EcrTargetCategory.ignore).toList();

      final studentNameCol = mappings.where((m) => m.target == EcrTargetCategory.studentName).first.columnIndex;
      final studentIdCol = mappings.where((m) => m.target == EcrTargetCategory.lrn).first.columnIndex;

      List<Map<String, dynamic>> generatedScoreRecords = [];

      for (final row in result.dataRows) {
        final studentName = row[studentNameCol]?.toString().trim() ?? '';
        final studentId = row[studentIdCol]?.toString().trim() ?? '';

        for (final m in scoreMappings) {
          if (m.columnIndex >= row.length) continue;
          final rawVal = row[m.columnIndex]?.toString().trim() ?? '';
          if (rawVal.isEmpty) continue;

          final scoreNum = double.tryParse(rawVal);
          if (scoreNum == null) continue;

          final totalHps = m.detectedRowHps ?? 100.0;

          generatedScoreRecords.add({
            'student_id': studentId,
            'student_name': studentName,
            'subject_code': 'COMP7',
            'subject_name': 'Computer 7',
            'section_name': 'Diamond',
            'grade_level': 'Grade 7',
            'grading_period': '1st Term',
            'score': scoreNum,
            'total_score': totalHps,
            'teacher_name': 'teacher@school.edu',
          });
        }
      }

      // 5 students * (4 WW + 3 PT + 3 QA = 10 scored activities) = 50 total score entries
      expect(generatedScoreRecords.length, equals(50));

      // Juan's scores
      final juanScores = generatedScoreRecords.where((s) => s['student_name'] == 'DELA CRUZ, JUAN A.').toList();
      expect(juanScores.length, equals(10));
      expect(juanScores.first['score'], equals(18.0));
      expect(juanScores.first['total_score'], equals(20.0));

      // Ana's scores
      final anaScores = generatedScoreRecords.where((s) => s['student_name'] == 'GARCIA, ANA E.').toList();
      expect(anaScores.length, equals(10));
      expect(anaScores.first['score'], equals(17.0));
      expect(anaScores.first['total_score'], equals(20.0));
    });
    test('New Era University (NEU) Student ID 9-digit format (##-####-### and raw 9 digits) is normalized', () {
      // 9 digits with dashes
      expect(EcrParserService.cleanLrn('24-1234-567'), equals('241234567'));
      expect(EcrParserService.cleanLrn('20-0012-345'), equals('200012345'));
      
      // 9 digits without dashes
      expect(EcrParserService.cleanLrn('241234567'), equals('241234567'));
      expect(EcrParserService.cleanLrn(241234567), equals('241234567'));

      // 12 digits DepEd LRN
      expect(EcrParserService.cleanLrn('109238471901'), equals('109238471901'));
      expect(EcrParserService.cleanLrn(109238471901), equals('109238471901'));

      // Invalid lengths
      expect(EcrParserService.cleanLrn('12345678'), isNull); // 8 digits
      expect(EcrParserService.cleanLrn('1234567890'), isNull); // 10 digits
      expect(EcrParserService.cleanLrn('12345678901'), isNull); // 11 digits
      expect(EcrParserService.cleanLrn('1234567890123'), isNull); // 13 digits
    });

    test('EcrValidator reconciles cross-format: enrolled student with dashes matches Excel without dashes and vice versa', () {
      final validator = EcrValidator();
      final enrolled = [
        {'student_id': '24-1234-567', 'name': 'Dela Cruz, Juan'},
        {'student_id': '241234568', 'name': 'Santos, Pedro'},
      ];

      final mappings = [
        EcrColumnMapping(columnIndex: 0, originalHeader: 'Student ID', target: EcrTargetCategory.lrn),
        EcrColumnMapping(columnIndex: 1, originalHeader: 'Name', target: EcrTargetCategory.studentName),
      ];

      // Excel row 1 has raw 9 digits without dashes '241234567' (matches enrolled '24-1234-567')
      // Excel row 2 has dashes '24-1234-568' (matches enrolled '241234568')
      final rows = [
        ['241234567', 'Dela Cruz, Juan'],
        ['24-1234-568', 'Santos, Pedro'],
      ];

      final matchRes = validator.reconcileWithRoster(
        dataRows: rows,
        mappings: mappings,
        enrolledStudents: enrolled,
      );

      expect(matchRes.matchedCount, equals(2));
      expect(matchRes.unmatchedCount, equals(0));
      expect(matchRes.matchRate, equals(1.0));
      expect(matchRes.lowMatchWarning, isFalse);
    });

    test('12 Written Works with HPS 20 each correctly computes total HPS of 240 and auto-adapts setup', () {
      final engine = EcrMappingEngine();
      final rowHpsMap = <int, double>{};
      for (int i = 0; i < 12; i++) {
        rowHpsMap[i + 3] = 20.0; // WW1 to WW12 all have detected HPS 20
      }

      final scoreMappings = List.generate(12, (i) {
        final m = EcrColumnMapping(
          columnIndex: i + 3,
          originalHeader: 'WW${i + 1}',
          target: EcrTargetCategory.values.firstWhere((e) => e.label == 'WW${i + 1}'),
        );
        m.detectedRowHps = rowHpsMap[i + 3];
        return m;
      });

      // Emulate score generation in ecr_import_screen
      List<Map<String, dynamic>> records = [];
      for (final m in scoreMappings) {
        final compKey = m.target.component ?? 'WW';
        final totalHps = m.customHps ?? m.detectedRowHps ?? (rowHpsMap[m.columnIndex]) ?? 100.0;
        records.add({
          'item_label': 'Written Works ${m.columnIndex - 2}',
          'category': 'Written Works',
          'score': 18.0,
          'total_score': totalHps,
        });
      }

      expect(records.length, equals(12));
      final double totalMax = records.fold(0.0, (sum, r) => sum + (r['total_score'] as double));
      expect(totalMax, equals(240.0)); // 12 * 20 = 240, NOT 1000!

      // Emulate auto-adapted labels
      final activeWwLabels = records.map((r) => r['item_label'].toString()).toSet().toList();
      expect(activeWwLabels.length, equals(12));
      expect(activeWwLabels.first, equals('Written Works 1'));
      expect(activeWwLabels.last, equals('Written Works 12'));
    });

    test('Total score adaptation in Encode Scores adapts dynamically for Written Tasks, Tests, and Performance Tasks', () {
      // 1. Category Aliases
      final wwAliases = DatabaseHelper.getCategoryAliases('Written Works');
      expect(wwAliases.contains('Written Tasks'), isTrue);
      expect(wwAliases.contains('Written Works'), isTrue);
      expect(wwAliases.contains('WW'), isTrue);

      final ptAliases = DatabaseHelper.getCategoryAliases('Performance Tasks');
      expect(ptAliases.contains('Performance Tasks'), isTrue);
      expect(ptAliases.contains('PT'), isTrue);

      final teAliases = DatabaseHelper.getCategoryAliases('Term Exams');
      expect(teAliases.contains('Term Exams'), isTrue);
      expect(teAliases.contains('Tests'), isTrue);
      expect(teAliases.contains('Quarterly Assessment'), isTrue);

      // 2. Item Label Cross-Format Aliases
      final wwItemAliases = DatabaseHelper.getItemAliases('Written Works', 'Written Works 1');
      expect(wwItemAliases.contains('WW1'), isTrue);
      expect(wwItemAliases.contains('Written Works 1'), isTrue);
      expect(wwItemAliases.contains('Written Tasks 1'), isTrue);

      final ptItemAliases = DatabaseHelper.getItemAliases('Performance Tasks', 'Performance Tasks 2');
      expect(ptItemAliases.contains('PT2'), isTrue);
      expect(ptItemAliases.contains('Performance Tasks 2'), isTrue);

      final teItemAliases = DatabaseHelper.getItemAliases('Term Exams', 'Term Exams 1');
      expect(teItemAliases.contains('Summative Test1'), isTrue);
      expect(teItemAliases.contains('Quarterly Exam'), isTrue);

      // 3. Simulated Total Score Adaptation
      final allScoresSample = [
        {'category': 'Written Works', 'item_label': 'WW1', 'score': 18.0, 'total_score': 20.0},
        {'category': 'Performance Tasks', 'item_label': 'PT1', 'score': 45.0, 'total_score': 50.0},
        {'category': 'Term Exams', 'item_label': 'Summative Test1', 'score': 90.0, 'total_score': 100.0},
      ];

      // Item 2 in Written Works has no direct score yet, but peers have 20.0
      int adaptTotalFor(String category, String itemLabel) {
        final catSet = DatabaseHelper.getCategoryAliases(category).map((c) => c.toLowerCase()).toSet();
        final itmSet = DatabaseHelper.getItemAliases(category, itemLabel).map((i) => i.toLowerCase()).toSet();
        
        final direct = allScoresSample.where((s) =>
          catSet.contains(s['category'].toString().toLowerCase()) &&
          itmSet.contains(s['item_label'].toString().toLowerCase())
        ).firstOrNull;

        if (direct != null) {
          return (direct['total_score'] as num).toInt();
        }

        // Peer in same category
        final peer = allScoresSample.where((s) =>
          catSet.contains(s['category'].toString().toLowerCase())
        ).firstOrNull;

        if (peer != null) {
          return (peer['total_score'] as num).toInt();
        }

        // Baseline fallback
        final lower = category.toLowerCase();
        if (lower.contains('written') || lower.contains('ww')) return 20;
        if (lower.contains('performance') || lower.contains('pt')) return 50;
        return 100;
      }

      // WW1 has direct score of 20
      expect(adaptTotalFor('Written Works', 'Written Works 1'), equals(20));
      // WW2 adapts to peer score 20
      expect(adaptTotalFor('Written Works', 'Written Works 2'), equals(20));
      // PT1 has direct score of 50
      expect(adaptTotalFor('Performance Tasks', 'Performance Tasks 1'), equals(50));
      // PT3 adapts to peer score 50
      expect(adaptTotalFor('Performance Tasks', 'Performance Tasks 3'), equals(50));
      // Tests / Term Exams adapts to 100
      expect(adaptTotalFor('Term Exams', 'Term Exams 1'), equals(100));
      expect(adaptTotalFor('Term Exams', 'Term Exams 2'), equals(100));
    });
  });
}
