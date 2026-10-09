import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/services/ecr_mapping_engine.dart';
import 'package:academic_system/services/ecr_parser_service.dart';
import 'package:academic_system/models/ecr_mapping_model.dart';
import 'helpers/synthetic_ecr_fixtures.dart';

void main() {
  setUpAll(() {
    SyntheticEcrFixtures.saveAllFixturesToDisk();
  });

  group('Phase 2 Hierarchical Column Mapping: Engine Unit Tests', () {
    final engine = EcrMappingEngine();

    test('Resolves parent blocks WW, PT, QA from stacked headers', () {
      final headers = [
        'LRN',
        'LEARNERS\' NAMES',
        'WRITTEN WORKS (30%) - 1',
        'WRITTEN WORKS (30%) - Total',
        'PERFORMANCE TASKS (50%) - 1',
        'PERFORMANCE TASKS (50%) - Total',
        'QUARTERLY ASSESSMENT (20%) - Exam',
        'Quarterly Grade',
      ];

      final mappings = engine.autoDetectMappings(headers: headers, previewRows: []);

      expect(mappings[2].parentBlock, equals('WW'));
      expect(mappings[3].parentBlock, equals('WW'));
      expect(mappings[4].parentBlock, equals('PT'));
      expect(mappings[5].parentBlock, equals('PT'));
      expect(mappings[6].parentBlock, equals('QA'));
      expect(mappings[7].parentBlock, isNull); // Final grade is outside component blocks
    });

    test('Total inside a component block maps to componentTotal, NEVER to totalGrade', () {
      final headers = [
        'WRITTEN WORKS (30%) - 1',
        'WRITTEN WORKS (30%) - Total',
        'PERFORMANCE TASKS (50%) - Total',
        'Final Grade',
      ];

      final mappings = engine.autoDetectMappings(headers: headers, previewRows: []);

      // Inside WW block
      expect(mappings[1].target, equals(EcrTargetCategory.componentTotal));
      expect(mappings[1].target, isNot(equals(EcrTargetCategory.totalGrade)));
      expect(mappings[1].reasons.any((r) => r.contains('Component total for WW')), isTrue);

      // Inside PT block
      expect(mappings[2].target, equals(EcrTargetCategory.componentTotal));
      expect(mappings[2].target, isNot(equals(EcrTargetCategory.totalGrade)));

      // Outside component block
      expect(mappings[3].target, equals(EcrTargetCategory.totalGrade));
    });

    test('Maps PS and WS columns to calculatedIgnore so they are not saved as raw scores', () {
      final headers = [
        'WRITTEN WORKS (30%) - PS',
        'WRITTEN WORKS (30%) - WS',
        'PERFORMANCE TASKS (50%) - PS',
      ];

      final mappings = engine.autoDetectMappings(headers: headers, previewRows: []);

      expect(mappings[0].target, equals(EcrTargetCategory.calculatedIgnore));
      expect(mappings[1].target, equals(EcrTargetCategory.calculatedIgnore));
      expect(mappings[2].target, equals(EcrTargetCategory.calculatedIgnore));
    });

    test('Position-in-block correctly assigns WW1..WW5 and PT1..PT5', () {
      final headers = [
        'WRITTEN WORKS (30%) - 1',
        'WRITTEN WORKS (30%) - 2',
        'WRITTEN WORKS (30%) - 3',
        'PERFORMANCE TASKS (50%) - 1',
        'PERFORMANCE TASKS (50%) - 2',
      ];

      final mappings = engine.autoDetectMappings(headers: headers, previewRows: []);

      expect(mappings[0].target, equals(EcrTargetCategory.ww1));
      expect(mappings[1].target, equals(EcrTargetCategory.ww2));
      expect(mappings[2].target, equals(EcrTargetCategory.ww3));
      expect(mappings[3].target, equals(EcrTargetCategory.pt1));
      expect(mappings[4].target, equals(EcrTargetCategory.pt2));
    });

    test('Warns when component items exceed standard 10 items instead of silently dropping', () {
      final headers = [
        'WRITTEN WORKS (30%) - 1',
        'WRITTEN WORKS (30%) - 2',
        'WRITTEN WORKS (30%) - 3',
        'WRITTEN WORKS (30%) - 4',
        'WRITTEN WORKS (30%) - 5',
        'WRITTEN WORKS (30%) - 6',
        'WRITTEN WORKS (30%) - 7',
        'WRITTEN WORKS (30%) - 8',
        'WRITTEN WORKS (30%) - 9',
        'WRITTEN WORKS (30%) - 10',
        'WRITTEN WORKS (30%) - 11', // Overflow
      ];

      final mappings = engine.autoDetectMappings(headers: headers, previewRows: []);

      expect(mappings[9].target, equals(EcrTargetCategory.ww10));
      // Column 11 should have overflow warning
      final overflowCol = mappings[10];
      expect(overflowCol.reasons.any((r) => r.contains('exceeds standard 10 items')), isTrue);
      expect(overflowCol.isLowConfidence, isTrue);
    });

    test('Recognizes split name columns (Last Name, First Name, Middle Initial)', () {
      final headers = [
        'LRN',
        'Last Name',
        'First Name',
        'Middle Initial',
      ];

      final mappings = engine.autoDetectMappings(headers: headers, previewRows: []);

      expect(mappings[0].target, equals(EcrTargetCategory.lrn));
      expect(mappings[1].target, equals(EcrTargetCategory.lastName));
      expect(mappings[2].target, equals(EcrTargetCategory.firstName));
      expect(mappings[3].target, equals(EcrTargetCategory.middleInitial));
    });

    test('Data profiling boosts confidence for 12-digit LRN and flags non-numeric scores', () {
      final headers = ['LRN', 'WW1'];
      final previewRows = [
        ['109238471901', 25],
        ['109238471902', 28],
        ['109238471903', 'absent'], // Non-numeric in score column
      ];

      final mappings = engine.autoDetectMappings(headers: headers, previewRows: previewRows);

      expect(mappings[0].confidenceScore, greaterThanOrEqualTo(0.95));
      expect(mappings[0].reasons.any((r) => r.contains('12-digit LRN pattern')), isTrue);

      expect(mappings[1].hasTypeMismatch, isTrue);
      expect(mappings[1].reasons.any((r) => r.contains('Non-numeric')), isTrue);
    });
  });

  group('Phase 2 End-to-End Pipeline: Standard DepEd Fixture', () {
    test('Correctly maps full Standard DepEd ECR fixture with 0 errors', () async {
      final bytes = SyntheticEcrFixtures.createStandardDepedEcr();
      final parser = EcrParserService();
      final parseResult = await parser.parseFile(bytes, 'standard_deped_ecr.xlsx');

      final engine = EcrMappingEngine();
      final mappings = engine.autoDetectMappings(
        headers: parseResult.headers,
        previewRows: parseResult.dataRows.take(10).toList(),
      );

      // Verify LRN mapping
      final lrnCol = mappings.firstWhere((m) => m.originalHeader == 'LRN');
      expect(lrnCol.target, equals(EcrTargetCategory.lrn));

      // Verify Learners' Names mapping
      final nameCol = mappings.firstWhere((m) => m.originalHeader.contains("LEARNERS' NAMES"));
      expect(nameCol.target, equals(EcrTargetCategory.studentName));

      // Verify WW1..WW5
      for (int i = 1; i <= 5; i++) {
        final wwCol = mappings.firstWhere((m) => m.originalHeader == 'WRITTEN WORKS (30%) - $i');
        expect(wwCol.target.label, equals('WW$i'));
      }

      // Verify WW Total is componentTotal, not totalGrade
      final wwTotalCol = mappings.firstWhere((m) => m.originalHeader == 'WRITTEN WORKS (30%) - Total');
      expect(wwTotalCol.target, equals(EcrTargetCategory.componentTotal));

      // Verify WW PS is calculatedIgnore
      final wwPsCol = mappings.firstWhere((m) => m.originalHeader == 'WRITTEN WORKS (30%) - PS');
      expect(wwPsCol.target, equals(EcrTargetCategory.calculatedIgnore));

      // Verify PT1..PT5
      for (int i = 1; i <= 5; i++) {
        final ptCol = mappings.firstWhere((m) => m.originalHeader == 'PERFORMANCE TASKS (50%) - $i');
        expect(ptCol.target.label, equals('PT$i'));
      }

      // Verify PT Total is componentTotal
      final ptTotalCol = mappings.firstWhere((m) => m.originalHeader == 'PERFORMANCE TASKS (50%) - Total');
      expect(ptTotalCol.target, equals(EcrTargetCategory.componentTotal));

      // Verify QA
      final qaCol = mappings.firstWhere((m) => m.originalHeader.contains('QUARTERLY ASSESSMENT'));
      expect(qaCol.target, equals(EcrTargetCategory.qa));

      // Verify Quarterly Grade is totalGrade
      final finalGradeCol = mappings.firstWhere((m) => m.originalHeader.contains('Quarterly Grade'));
      expect(finalGradeCol.target, equals(EcrTargetCategory.totalGrade));
    });
  });
}
