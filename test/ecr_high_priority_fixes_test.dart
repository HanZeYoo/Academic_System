import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academic_system/database_helper.dart';
import 'package:academic_system/models/ecr_mapping_model.dart';
import 'package:academic_system/models/ecr_transmutation_model.dart';
import 'package:academic_system/services/ecr_parser_service.dart';
import 'package:academic_system/services/ecr_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DatabaseHelper.clearTransmutationCache();
  });

  group('High-Priority ECR Data Safety & Logic Fixes', () {
    test('EcrTransmutationTable.fromJson sorts unsorted brackets and lookup returns accurate grades', () {
      final decoded = EcrTransmutationTable.fromJson({
        'sheetName': 'Transmutation',
        'description': 'Unsorted Scale',
        'passingRawScore': 70.0,
        'isDetected': true,
        'brackets': {
          '99.49': 100,
          '70.0': 75,
          '0.0': 60,
          '80.0': 87,
          '50.0': 71,
        },
      });

      expect(decoded.brackets.keys.toList(), equals([0.0, 50.0, 70.0, 80.0, 99.49]));
      expect(decoded.lookup(0.0), equals(60));
      expect(decoded.lookup(49.9), equals(60));
      expect(decoded.lookup(55.0), equals(71));
      expect(decoded.lookup(70.0), equals(75));
      expect(decoded.lookup(85.0), equals(87));
      expect(decoded.lookup(99.5), equals(100));

      // Also verify lookup handles manually constructed unsorted brackets directly
      final manualUnsorted = EcrTransmutationTable(
        isDetected: true,
        brackets: {
          80.0: 87,
          0.0: 60,
          70.0: 75,
        },
      );
      expect(manualUnsorted.lookup(75.0), equals(75));
      expect(manualUnsorted.lookup(50.0), equals(60));
      expect(manualUnsorted.lookup(90.0), equals(87));
    });

    test('Transmutation table does not leak across unrelated subjects', () async {
      final db = DatabaseHelper();

      final compTable = EcrTransmutationTable(
        sheetName: 'Transmutation',
        description: 'Base-60',
        passingRawScore: 60.0,
        brackets: {0.0: 60, 60.0: 75, 100.0: 100},
        isDetected: true,
      );

      await db.saveTransmutationTable('COMP7', 'Sapphire', compTable);
      DatabaseHelper.setActiveTransmutationTable(compTable);

      // Same subject (and subject-level fallback) returns compTable
      expect(await db.getTransmutationTable('COMP7', 'Sapphire'), isNotNull);
      expect(await db.getTransmutationTable('COMP7', 'OtherSection'), isNotNull);

      // Unrelated subject must NOT inherit COMP7's or _activeTransmutationTable's scale
      expect(await db.getTransmutationTable('MATH7', 'Sapphire'), isNull);
      expect(db.getCachedTransmutationTable('MATH7', 'Sapphire'), isNull);
    });

    test('buildScoreCompositeKey isolates scores by schoolYear', () {
      final key2025 = DatabaseHelper.buildScoreCompositeKey(
        studentId: '24-1234-567',
        subjectCode: 'MATH7',
        category: 'Written Works',
        itemLabel: 'Quiz 1',
        gradingPeriod: '1st Quarter',
        schoolYear: '2025-2026',
      );
      final key2026 = DatabaseHelper.buildScoreCompositeKey(
        studentId: '241234567',
        subjectCode: 'math7',
        category: 'Written Works',
        itemLabel: 'Quiz  1',
        gradingPeriod: 'Q1',
        schoolYear: '2026-2027',
      );

      expect(key2025, isNot(equals(key2026)));
      expect(key2025.endsWith('|2025-2026'), isTrue);
      expect(key2026.endsWith('|2026-2027'), isTrue);
    });

    test('EcrValidator flags duplicate unique column mappings as fatal errors while allowing multi-slot targets', () {
      final validator = EcrValidator();

      // Duplicate WW1 and colliding QA / QA1
      final duplicateMappings = [
        EcrColumnMapping(columnIndex: 0, originalHeader: 'Name', target: EcrTargetCategory.studentName),
        EcrColumnMapping(columnIndex: 1, originalHeader: 'Quiz 1', target: EcrTargetCategory.ww1),
        EcrColumnMapping(columnIndex: 2, originalHeader: 'Quiz 1 Copy', target: EcrTargetCategory.ww1),
        EcrColumnMapping(columnIndex: 3, originalHeader: 'Exam', target: EcrTargetCategory.qa),
        EcrColumnMapping(columnIndex: 4, originalHeader: 'Exam 2', target: EcrTargetCategory.qa1),
      ];

      final dupSummary = validator.validateFullDataset(
        dataRows: [
          ['Dela Cruz, Juan', 18, 19, 40, 42],
        ],
        mappings: duplicateMappings,
      );

      expect(dupSummary.hasErrors, isTrue);
      expect(dupSummary.errors.where((e) => !e.isWarning && e.message.contains('Duplicate Mapping')).length, equals(2));

      // Multiple ignore, calculatedIgnore, and componentTotal columns must still be valid
      final validMappings = [
        EcrColumnMapping(columnIndex: 0, originalHeader: 'Name', target: EcrTargetCategory.studentName),
        EcrColumnMapping(columnIndex: 1, originalHeader: 'WW1', target: EcrTargetCategory.ww1),
        EcrColumnMapping(columnIndex: 2, originalHeader: 'WW Total', target: EcrTargetCategory.componentTotal, parentBlock: 'WW'),
        EcrColumnMapping(columnIndex: 3, originalHeader: 'WW PS', target: EcrTargetCategory.calculatedIgnore),
        EcrColumnMapping(columnIndex: 4, originalHeader: 'PT1', target: EcrTargetCategory.pt1),
        EcrColumnMapping(columnIndex: 5, originalHeader: 'PT Total', target: EcrTargetCategory.componentTotal, parentBlock: 'PT'),
        EcrColumnMapping(columnIndex: 6, originalHeader: 'PT WS', target: EcrTargetCategory.calculatedIgnore),
        EcrColumnMapping(columnIndex: 7, originalHeader: 'Gender', target: EcrTargetCategory.ignore),
        EcrColumnMapping(columnIndex: 8, originalHeader: 'Unused', target: EcrTargetCategory.ignore),
      ];

      final validSummary = validator.validateFullDataset(
        dataRows: [
          ['Dela Cruz, Juan', 18, 18, 90, 45, 45, 45, 'Male', ''],
        ],
        mappings: validMappings,
      );

      expect(validSummary.hasErrors, isFalse);
    });

    test('getAvailableSheets sorts candidate sheets descending by matchScore', () async {
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'INSTRUCTIONS');
      excel['INSTRUCTIONS'].cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          TextCellValue('Guidelines');

      for (final tabName in ['1st Quarter', '2nd Quarter']) {
        final s = excel[tabName];
        for (int r = 0; r < 6; r++) {
          for (int c = 0; c < 4; c++) {
            s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).value =
                TextCellValue('$tabName-$r-$c');
          }
        }
      }

      final bytes = Uint8List.fromList(excel.save()!);
      final parser = EcrParserService();

      final sheetsQ2 = await parser.getAvailableSheets(
        bytes,
        'quarters.xlsx',
        gradingPeriod: '2nd Quarter',
      );

      expect(sheetsQ2.length, equals(3));
      expect(sheetsQ2.first.sheetName, equals('2nd Quarter'));
      expect(sheetsQ2.first.matchScore, equals(1.0));
      expect(sheetsQ2[1].sheetName, equals('1st Quarter'));
      expect(sheetsQ2[1].matchScore, equals(0.5));
      expect(sheetsQ2.last.isCandidate, isFalse);
    });
  });
}
