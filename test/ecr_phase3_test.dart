import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/services/ecr_mapping_engine.dart';
import 'package:academic_system/services/ecr_parser_service.dart';
import 'helpers/synthetic_ecr_fixtures.dart';

void main() {
  setUpAll(() {
    SyntheticEcrFixtures.saveAllFixturesToDisk();
  });

  group('Phase 3 Unified Scorer & Profiling Signals', () {
    final engine = EcrMappingEngine();

    test('Threshold constants: autoApplyThreshold is 0.85 and reviewThreshold is 0.60', () {
      expect(EcrMappingEngine.autoApplyThreshold, equals(0.85));
      expect(EcrMappingEngine.reviewThreshold, equals(0.60));
    });

    test('Exact header match yields >= 0.85 confidence (Auto-apply tier)', () {
      final headers = ['Learner Reference Number (LRN)', "Learner's Name", 'Quarterly Assessment'];
      final mappings = engine.autoDetectMappings(headers: headers, previewRows: []);

      expect(mappings[0].confidenceScore, greaterThanOrEqualTo(0.85));
      expect(mappings[0].isLowConfidence, isFalse);
      expect(mappings[1].confidenceScore, greaterThanOrEqualTo(0.85));
      expect(mappings[1].isLowConfidence, isFalse);
    });

    test('Data profiling boosts confidence for 12-digit LRN cell data', () {
      final headers = ['Ref No.'];
      final rowsWithoutLrn = [
        ['ABC123'],
        ['XYZ456'],
      ];
      final rowsWithLrn = [
        ['109238471901'],
        ['109238471902'],
      ];

      final mappingsWithout = engine.autoDetectMappings(headers: headers, previewRows: rowsWithoutLrn);
      final mappingsWith = engine.autoDetectMappings(headers: headers, previewRows: rowsWithLrn);

      expect(mappingsWith[0].confidenceScore, greaterThan(mappingsWithout[0].confidenceScore));
      expect(mappingsWith[0].reasons.any((r) => r.contains('12-digit LRN pattern')), isTrue);
    });

    test('Data profiling penalizes confidence and flags type mismatch for non-numeric scores', () {
      final headers = ['WRITTEN WORKS - 1'];
      final invalidRows = [
        ['NOT_A_SCORE'],
        ['INVALID'],
      ];

      final mappings = engine.autoDetectMappings(headers: headers, previewRows: invalidRows);

      expect(mappings[0].hasTypeMismatch, isTrue);
      expect(mappings[0].confidenceScore, lessThan(0.85));
      expect(mappings[0].reasons.any((r) => r.contains('Non-numeric values found')), isTrue);
    });

    test('Spreadsheet formula columns are recognized as formula references and not penalized as type mismatches', () {
      final headers = ['WRITTEN WORKS - Total'];
      final formulaRows = [
        ['=SUM(D11:H11)'],
        ['=SUM(D12:H12)'],
      ];

      final mappings = engine.autoDetectMappings(headers: headers, previewRows: formulaRows);

      expect(mappings[0].hasTypeMismatch, isFalse);
      expect(mappings[0].reasons.any((r) => r.contains('spreadsheet formula references')), isTrue);
    });

    test('Every column mapping provides human-readable explainability reasons', () {
      final headers = ['LRN', 'Name', 'WRITTEN WORKS - 1', 'PERFORMANCE TASKS - Total'];
      final mappings = engine.autoDetectMappings(headers: headers, previewRows: []);

      for (final m in mappings) {
        expect(m.reasons, isNotEmpty, reason: 'Column ${m.originalHeader} must have explanatory reasons');
      }
    });
  });

  group('Phase 3 Dry-Run Excluded Row Tracking & Inspection', () {
    final parser = EcrParserService();

    test('Excludes gender dividers with explicit reasons and accurate row index', () async {
      final bytes = SyntheticEcrFixtures.createStandardDepedEcr();
      final result = await parser.parseFile(bytes, 'standard_deped_ecr.xlsx');

      final maleRow = result.excludedRows.firstWhere((e) => e.rawText == 'MALE');
      expect(maleRow.reason, equals('Section Divider (MALE)'));
      expect(maleRow.rowIndex, greaterThan(0));

      final femaleRow = result.excludedRows.firstWhere((e) => e.rawText == 'FEMALE');
      expect(femaleRow.reason, equals('Section Divider (FEMALE)'));
      expect(femaleRow.rowIndex, greaterThan(maleRow.rowIndex));
    });

    test('Excludes summary subtotal rows (TOTAL MALE, TOTAL FEMALE) with explicit reasons', () async {
      final bytes = SyntheticEcrFixtures.createStandardDepedEcr();
      final result = await parser.parseFile(bytes, 'standard_deped_ecr.xlsx');

      final totalMale = result.excludedRows.firstWhere((e) => e.rawText == 'TOTAL MALE');
      expect(totalMale.reason, contains('Summary Subtotal Row'));

      final totalFemale = result.excludedRows.firstWhere((e) => e.rawText == 'TOTAL FEMALE');
      expect(totalFemale.reason, contains('Summary Subtotal Row'));
    });

    test('Excluded rows are segregated from dataRows so zero subtotal rows are scored', () async {
      final bytes = SyntheticEcrFixtures.createStandardDepedEcr();
      final result = await parser.parseFile(bytes, 'standard_deped_ecr.xlsx');

      // The fixture has 3 male and 2 female students = 5 students
      expect(result.dataRows.length, equals(5));

      // No dataRow contains MALE, FEMALE, or TOTAL
      for (final row in result.dataRows) {
        for (final cell in row) {
          final s = cell.toString().toUpperCase().trim();
          expect(s, isNot(equals('MALE')));
          expect(s, isNot(equals('FEMALE')));
          expect(s, isNot(startsWith('TOTAL MALE')));
        }
      }
    });
  });
}
