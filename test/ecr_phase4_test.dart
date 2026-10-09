import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/services/ecr_validator.dart';
import 'package:academic_system/services/ecr_parser_service.dart';
import 'package:academic_system/services/ecr_mapping_engine.dart';
import 'package:academic_system/models/ecr_mapping_model.dart';
import 'helpers/synthetic_ecr_fixtures.dart';

void main() {
  setUpAll(() {
    SyntheticEcrFixtures.saveAllFixturesToDisk();
  });

  group('Phase 4 Validation: Score > HPS Checks', () {
    final validator = EcrValidator();

    test('Flags warning when student score exceeds detected row HPS', () {
      final mappings = [
        EcrColumnMapping(
          columnIndex: 0,
          originalHeader: 'LRN',
          target: EcrTargetCategory.lrn,
        ),
        EcrColumnMapping(
          columnIndex: 1,
          originalHeader: 'Name',
          target: EcrTargetCategory.studentName,
        ),
        EcrColumnMapping(
          columnIndex: 2,
          originalHeader: 'WW1',
          target: EcrTargetCategory.ww1,
          detectedRowHps: 20.0,
        ),
      ];

      final dataRows = [
        ['109238471901', 'DELA CRUZ, JUAN', 25.0], // Exceeds HPS of 20
        ['109238471902', 'SANTOS, PEDRO', 18.0], // Valid
      ];

      final summary = validator.validateFullDataset(dataRows: dataRows, mappings: mappings);

      expect(summary.errors.length, equals(1));
      final err = summary.errors.first;
      expect(err.isWarning, isTrue);
      expect(err.rowIndex, equals(1));
      expect(err.message, contains('exceeds HPS (20)'));
    });
  });

  group('Phase 4 Validation: In-File Duplicate Detection', () {
    final validator = EcrValidator();

    test('Flags warning when duplicate LRN appears in uploaded file', () {
      final mappings = [
        EcrColumnMapping(
          columnIndex: 0,
          originalHeader: 'LRN',
          target: EcrTargetCategory.lrn,
        ),
        EcrColumnMapping(
          columnIndex: 1,
          originalHeader: 'Name',
          target: EcrTargetCategory.studentName,
        ),
        EcrColumnMapping(
          columnIndex: 2,
          originalHeader: 'WW1',
          target: EcrTargetCategory.ww1,
          customHps: 50.0,
        ),
      ];

      final dataRows = [
        ['109238471901', 'DELA CRUZ, JUAN', 20],
        ['109238471902', 'SANTOS, PEDRO', 22],
        ['109238471901', 'DELA CRUZ, JUAN (DUPLICATE)', 25], // Duplicate LRN
      ];

      final summary = validator.validateFullDataset(dataRows: dataRows, mappings: mappings);

      final dupErr = summary.errors.firstWhere((e) => e.message.contains('Duplicate LRN'));
      expect(dupErr.isWarning, isTrue);
      expect(dupErr.rowIndex, equals(3));
      expect(dupErr.message, contains('already appeared in Row 1'));
    });

    test('Flags warning when duplicate student name appears and LRN is absent', () {
      final mappings = [
        EcrColumnMapping(
          columnIndex: 0,
          originalHeader: 'Name',
          target: EcrTargetCategory.studentName,
        ),
        EcrColumnMapping(
          columnIndex: 1,
          originalHeader: 'WW1',
          target: EcrTargetCategory.ww1,
          customHps: 50.0,
        ),
      ];

      final dataRows = [
        ['DELA CRUZ, JUAN', 20],
        ['Juan Dela Cruz', 22], // Same student with flipped order
      ];

      final summary = validator.validateFullDataset(dataRows: dataRows, mappings: mappings);

      final dupErr = summary.errors.firstWhere((e) => e.message.contains('Duplicate Student Name'));
      expect(dupErr.isWarning, isTrue);
      expect(dupErr.rowIndex, equals(2));
    });
  });

  group('Phase 4 Validation: Component Total Cross-Check', () {
    final validator = EcrValidator();

    test('Flags warning when reported component total does not match computed sum of item scores', () {
      final mappings = [
        EcrColumnMapping(
          columnIndex: 0,
          originalHeader: 'Name',
          target: EcrTargetCategory.studentName,
        ),
        EcrColumnMapping(
          columnIndex: 1,
          originalHeader: 'WW1',
          target: EcrTargetCategory.ww1,
          parentBlock: 'WW',
        ),
        EcrColumnMapping(
          columnIndex: 2,
          originalHeader: 'WW2',
          target: EcrTargetCategory.ww2,
          parentBlock: 'WW',
        ),
        EcrColumnMapping(
          columnIndex: 3,
          originalHeader: 'Total',
          target: EcrTargetCategory.componentTotal,
          parentBlock: 'WW',
        ),
      ];

      final dataRows = [
        ['Student A', 10, 15, 25], // Correct: 10 + 15 = 25
        ['Student B', 10, 15, 30], // Mismatch: 10 + 15 = 25, but sheet reports 30
      ];

      final summary = validator.validateFullDataset(dataRows: dataRows, mappings: mappings);

      expect(summary.errors.length, equals(1));
      final err = summary.errors.first;
      expect(err.isWarning, isTrue);
      expect(err.rowIndex, equals(2));
      expect(err.message, contains('WW computed items sum (25.0) does not match reported total (30.0)'));
    });

    test('Gracefully skips total cross-check when total column contains spreadsheet formula string', () {
      final mappings = [
        EcrColumnMapping(
          columnIndex: 0,
          originalHeader: 'Name',
          target: EcrTargetCategory.studentName,
        ),
        EcrColumnMapping(
          columnIndex: 1,
          originalHeader: 'WW1',
          target: EcrTargetCategory.ww1,
          parentBlock: 'WW',
        ),
        EcrColumnMapping(
          columnIndex: 2,
          originalHeader: 'Total',
          target: EcrTargetCategory.componentTotal,
          parentBlock: 'WW',
        ),
      ];

      final dataRows = [
        ['Student A', 20, '=SUM(B2:B2)'],
      ];

      final summary = validator.validateFullDataset(dataRows: dataRows, mappings: mappings);

      // No false positive error or crash for formula string
      expect(summary.errors.isEmpty, isTrue);
    });
  });

  group('Phase 4 Roster Reconciliation', () {
    final validator = EcrValidator();

    final enrolledRoster = [
      {'student_id': '109238471901', 'name': 'DELA CRUZ, JUAN A.'},
      {'student_id': '109238471902', 'name': 'SANTOS, PEDRO M.'},
      {'student_id': '109238471903', 'name': 'REYES, CARLOS B.'},
      {'student_id': '109238471904', 'name': 'AQUINO, MARIA C.'},
      {'student_id': '109238471905', 'name': 'GARCIA, ANA S.'},
    ];

    test('Reconciles students by 12-digit LRN with 100% match rate', () {
      final mappings = [
        EcrColumnMapping(columnIndex: 0, originalHeader: 'LRN', target: EcrTargetCategory.lrn),
        EcrColumnMapping(columnIndex: 1, originalHeader: 'Name', target: EcrTargetCategory.studentName),
      ];

      final dataRows = [
        ['109238471901', 'DELA CRUZ, JUAN A.'],
        ['109238471902', 'SANTOS, PEDRO M.'],
        ['109238471903', 'REYES, CARLOS B.'],
      ];

      final result = validator.reconcileWithRoster(
        dataRows: dataRows,
        mappings: mappings,
        enrolledStudents: enrolledRoster,
      );

      expect(result.matchedCount, equals(3));
      expect(result.unmatchedCount, equals(0));
      expect(result.matchRate, equals(1.0));
      expect(result.lowMatchWarning, isFalse);
    });

    test('Fuzzy name matching reconciles when LRN is missing or different', () {
      final mappings = [
        EcrColumnMapping(columnIndex: 0, originalHeader: 'Name', target: EcrTargetCategory.studentName),
      ];

      final dataRows = [
        ['Juan A. Dela Cruz'], // Flipped name tokens
        ['Pedro M. Santos'],
      ];

      final result = validator.reconcileWithRoster(
        dataRows: dataRows,
        mappings: mappings,
        enrolledStudents: enrolledRoster,
      );

      expect(result.matchedCount, equals(2));
      expect(result.unmatchedCount, equals(0));
      expect(result.matchRate, equals(1.0));
      expect(result.lowMatchWarning, isFalse);
    });

    test('Triggers lowMatchWarning when roster match rate is below 40%', () {
      final mappings = [
        EcrColumnMapping(columnIndex: 0, originalHeader: 'LRN', target: EcrTargetCategory.lrn),
        EcrColumnMapping(columnIndex: 1, originalHeader: 'Name', target: EcrTargetCategory.studentName),
      ];

      // 1 matched student, 4 foreign/unregistered students = 20% match rate
      final dataRows = [
        ['109238471901', 'DELA CRUZ, JUAN A.'], // Matched
        ['999000111222', 'FOREIGN STUDENT 1'],
        ['999000111223', 'FOREIGN STUDENT 2'],
        ['999000111224', 'FOREIGN STUDENT 3'],
        ['999000111225', 'FOREIGN STUDENT 4'],
      ];

      final result = validator.reconcileWithRoster(
        dataRows: dataRows,
        mappings: mappings,
        enrolledStudents: enrolledRoster,
      );

      expect(result.matchedCount, equals(1));
      expect(result.unmatchedCount, equals(4));
      expect(result.matchRate, equals(0.20));
      expect(result.lowMatchWarning, isTrue); // < 40% triggers critical warning
      expect(result.unmatchedNames.length, equals(4));
    });
  });

  group('Phase 4 End-to-End Pipeline: Standard DepEd Fixture', () {
    test('Standard DepEd ECR validates with 0 errors and reconciles with roster', () async {
      final bytes = SyntheticEcrFixtures.createStandardDepedEcr();
      final parser = EcrParserService();
      final parseResult = await parser.parseFile(bytes, 'standard_deped_ecr.xlsx');

      final engine = EcrMappingEngine();
      final mappings = engine.autoDetectMappings(
        headers: parseResult.headers,
        previewRows: parseResult.dataRows.take(10).toList(),
      );

      final validator = EcrValidator();
      final summary = validator.validateFullDataset(
        dataRows: parseResult.dataRows,
        mappings: mappings,
      );

      expect(summary.hasErrors, isFalse);
      expect(summary.validRows, equals(5));

      final roster = [
        {'student_id': '109238471901', 'name': 'DELA CRUZ, JUAN A.'},
        {'student_id': '109238471902', 'name': 'SANTOS, PEDRO M.'},
        {'student_id': '109238471903', 'name': 'REYES, CARLOS B.'},
        {'student_id': '109238471904', 'name': 'AQUINO, MARIA C.'},
        {'student_id': '109238471905', 'name': 'GARCIA, ANA S.'},
      ];

      final reconciliation = validator.reconcileWithRoster(
        dataRows: parseResult.dataRows,
        mappings: mappings,
        enrolledStudents: roster,
      );

      expect(reconciliation.matchedCount, equals(5));
      expect(reconciliation.unmatchedCount, equals(0));
      expect(reconciliation.matchRate, equals(1.0));
      expect(reconciliation.lowMatchWarning, isFalse);
    });
  });
}
