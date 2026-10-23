import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/services/ecr_parser_service.dart';
import 'helpers/synthetic_ecr_fixtures.dart';

void main() {
  setUpAll(() {
    SyntheticEcrFixtures.saveAllFixturesToDisk();
  });

  group('Phase 1 Pure Helper Units: cleanLrn', () {
    test('Converts numeric 12-digit integers cleanly', () {
      expect(EcrParserService.cleanLrn(109238471901), equals('109238471901'));
      expect(EcrParserService.cleanLrn(619180594664), equals('619180594664'));
    });

    test('Converts numeric double cells (109238471901.0) without scientific notation', () {
      expect(EcrParserService.cleanLrn(109238471901.0), equals('109238471901'));
    });

    test('Strictly rejects text-formatted scientific notation ("1.02345E+11")', () {
      expect(EcrParserService.cleanLrn('1.02345E+11'), isNull);
      expect(EcrParserService.cleanLrn('1.02e11'), isNull);
    });

    test('Rejects invalid length (not exactly 12 digits) without blind padding', () {
      expect(EcrParserService.cleanLrn('12345678901'), isNull); // 11 digits
      expect(EcrParserService.cleanLrn('1234567890123'), isNull); // 13 digits
      expect(EcrParserService.cleanLrn(12345), isNull);
    });

    test('Handles clean text 12-digit string and strips stray spaces or hyphens', () {
      expect(EcrParserService.cleanLrn('109238471901'), equals('109238471901'));
      expect(EcrParserService.cleanLrn('1092-3847-1901'), equals('109238471901'));
    });

    test('Returns null on null or blank', () {
      expect(EcrParserService.cleanLrn(null), isNull);
      expect(EcrParserService.cleanLrn(''), isNull);
      expect(EcrParserService.cleanLrn('   '), isNull);
    });
  });

  group('Phase 1 Pure Helper Units: isStudentRow', () {
    test('Accepts valid student with plausible name and valid LRN', () {
      final isStudent = EcrParserService.isStudentRow(
        name: 'DELA CRUZ, JUAN A.',
        lrn: '109238471901',
        scores: [18, 22, 19],
        hasHighFillLrnColumn: true,
      );
      expect(isStudent, isTrue);
    });

    test('Rejects gender dividers (MALE, FEMALE, BOYS, GIRLS)', () {
      expect(
        EcrParserService.isStudentRow(name: 'MALE', lrn: null, scores: []),
        isFalse,
      );
      expect(
        EcrParserService.isStudentRow(name: 'FEMALE', lrn: null, scores: []),
        isFalse,
      );
    });

    test('Rejects subtotal rows with numeric sums (TOTAL MALE, TOTAL FEMALE, AVERAGE)', () {
      expect(
        EcrParserService.isStudentRow(
          name: 'TOTAL MALE',
          lrn: null,
          scores: [53, 66, 75], // Subtotal numbers
          hasHighFillLrnColumn: true,
        ),
        isFalse,
      );
      expect(
        EcrParserService.isStudentRow(
          name: 'TOTAL FEMALE',
          lrn: null,
          scores: [48, 55],
        ),
        isFalse,
      );
      expect(
        EcrParserService.isStudentRow(
          name: 'AVERAGE',
          lrn: null,
          scores: [88.5],
        ),
        isFalse,
      );
    });

    test('When high-fill LRN column exists, requires valid 12-digit LRN', () {
      // Row with name and scores, but no valid LRN in an active LRN table (e.g. divider or note)
      expect(
        EcrParserService.isStudentRow(
          name: 'REMARKS SECTION',
          lrn: null,
          scores: [20],
          hasHighFillLrnColumn: true,
        ),
        isFalse,
      );
    });

    test('Accepts student in teacher sheet without LRN if name is plausible and has scores', () {
      expect(
        EcrParserService.isStudentRow(
          name: 'Pedro Penduko',
          lrn: null,
          scores: [25, 28],
          hasHighFillLrnColumn: false,
        ),
        isTrue,
      );
    });

    test('Strictly rejects empty template rows (formulas, zeroes, numbers, placeholders)', () {
      // Row where formula unresolved to "='INPUT DATA'!B16" with 0 scores
      expect(
        EcrParserService.isStudentRow(
          name: "='INPUT DATA'!B16",
          lrn: "='INPUT DATA'!A16",
          scores: [0, 0, 0],
          hasHighFillLrnColumn: false,
        ),
        isFalse,
      );

      // Row where formula evaluated to '0' with 0 scores
      expect(
        EcrParserService.isStudentRow(
          name: '0',
          lrn: null,
          scores: [0, 0, 0],
          hasHighFillLrnColumn: false,
        ),
        isFalse,
      );

      // Row where name is pure row number (e.g. '3')
      expect(
        EcrParserService.isStudentRow(
          name: '3',
          lrn: null,
          scores: [0],
          hasHighFillLrnColumn: false,
        ),
        isFalse,
      );

      // Row where name is blank or dash
      expect(
        EcrParserService.isStudentRow(
          name: '',
          lrn: null,
          scores: [25],
        ),
        isFalse,
      );
      expect(
        EcrParserService.isStudentRow(
          name: '-',
          lrn: null,
          scores: [25],
        ),
        isFalse,
      );
    });
  });

  group('Phase 1 Pure Helper Units: isValidStudentName', () {
    test('Validates human student names', () {
      expect(EcrParserService.isValidStudentName('DELA CRUZ, JUAN A.'), isTrue);
      expect(EcrParserService.isValidStudentName('Pedro Penduko'), isTrue);
      expect(EcrParserService.isValidStudentName('Al Santos'), isTrue);
      expect(EcrParserService.isValidStudentName('Li, Bo'), isTrue);
    });

    test('Rejects Excel formulas, sheet references, and error codes', () {
      expect(EcrParserService.isValidStudentName("='INPUT DATA'!B16"), isFalse);
      expect(EcrParserService.isValidStudentName("'INPUT DATA'!B16"), isFalse);
      expect(EcrParserService.isValidStudentName("INPUT DATA!B16"), isFalse);
      expect(EcrParserService.isValidStudentName("=SUM(D14:H14)"), isFalse);
      expect(EcrParserService.isValidStudentName("#REF!"), isFalse);
      expect(EcrParserService.isValidStudentName("#VALUE!"), isFalse);
    });

    test('Rejects numbers, placeholders, single letters, and divider labels', () {
      expect(EcrParserService.isValidStudentName('0'), isFalse);
      expect(EcrParserService.isValidStudentName('0.0'), isFalse);
      expect(EcrParserService.isValidStudentName('1'), isFalse);
      expect(EcrParserService.isValidStudentName('50'), isFalse);
      expect(EcrParserService.isValidStudentName('---'), isFalse);
      expect(EcrParserService.isValidStudentName('N/A'), isFalse);
      expect(EcrParserService.isValidStudentName('A'), isFalse);
      expect(EcrParserService.isValidStudentName('MALE'), isFalse);
      expect(EcrParserService.isValidStudentName('FEMALE'), isFalse);
      expect(EcrParserService.isValidStudentName('TOTAL MALE'), isFalse);
      expect(EcrParserService.isValidStudentName("LEARNERS' NAMES"), isFalse);
    });
  });

  group('Phase 1 Pure Helper Units: detectHpsRow', () {
    test('Extracts per-column max scores from horizontal HPS row', () {
      final grid = [
        ['Class Record', '', ''],
        ['LEARNERS', 'WW1', 'WW2', 'PT1'],
        ['HIGHEST POSSIBLE SCORE', 25, 30, 50],
        ['DELA CRUZ, JUAN', 20, 28, 48],
      ];

      final hpsMap = EcrParserService.detectHpsRow(grid, 1);
      expect(hpsMap[1], equals(25.0));
      expect(hpsMap[2], equals(30.0));
      expect(hpsMap[3], equals(50.0));
    });
  });

  group('Phase 1 Pure Helper Units: detectWeights', () {
    test('Auto-detects Science and Math weights (40% WW, 40% PT, 20% QA)', () {
      final headers = [
        'LRN',
        'LEARNERS',
        'WRITTEN WORKS (40%)',
        'PERFORMANCE TASKS (40%)',
        'QUARTERLY ASSESSMENT (20%)',
      ];
      final weights = EcrParserService.detectWeights([], headers);
      expect(weights.isDetected, isTrue);
      expect(weights.wwWeight, equals(40.0));
      expect(weights.ptWeight, equals(40.0));
      expect(weights.qaWeight, equals(20.0));
    });

    test('Auto-detects MAPEH and TLE weights (20% WW, 60% PT, 20% QA)', () {
      final headers = [
        'LRN',
        'LEARNERS',
        'WRITTEN WORKS (20%)',
        'PERFORMANCE TASKS (60%)',
        'QUARTERLY ASSESSMENT (20%)',
      ];
      final weights = EcrParserService.detectWeights([], headers);
      expect(weights.isDetected, isTrue);
      expect(weights.wwWeight, equals(20.0));
      expect(weights.ptWeight, equals(60.0));
      expect(weights.qaWeight, equals(20.0));
    });

    test('Auto-detects Languages and AP standard DepEd weights (30% WW, 50% PT, 20% QA)', () {
      final headers = [
        'LRN',
        'LEARNERS',
        'WRITTEN WORKS (30%)',
        'PERFORMANCE TASKS (50%)',
        'QUARTERLY ASSESSMENT (20%)',
      ];
      final weights = EcrParserService.detectWeights([], headers);
      expect(weights.isDetected, isTrue);
      expect(weights.wwWeight, equals(30.0));
      expect(weights.ptWeight, equals(50.0));
      expect(weights.qaWeight, equals(20.0));
    });

    test('Detects weights from top metadata rows when headers have simple names', () {
      final grid = [
        ['Class Record', '', '', ''],
        ['Weights: WW 40% | PT 40% | QA 20%', '', '', ''],
        ['LRN', 'Name', 'WW1', 'PT1'],
      ];
      final weights = EcrParserService.detectWeights(grid, ['LRN', 'Name', 'WW1', 'PT1']);
      expect(weights.isDetected, isTrue);
      expect(weights.wwWeight, equals(40.0));
      expect(weights.ptWeight, equals(40.0));
      expect(weights.qaWeight, equals(20.0));
    });

    test('Falls back safely to DepEd standard 30-50-20 when no percentage is specified', () {
      final weights = EcrParserService.detectWeights([], ['LRN', 'Name', 'WW1', 'PT1', 'Exam']);
      expect(weights.isDetected, isFalse);
      expect(weights.wwWeight, equals(30.0));
      expect(weights.ptWeight, equals(50.0));
      expect(weights.qaWeight, equals(20.0));
    });
  });

  group('Phase 1 Pure Helper Units: combineSplitNames', () {
    test('Combines LAST, FIRST, M.I. correctly', () {
      final row = ['109238471901', 'Dela Cruz', 'Juan', 'A', 25];
      final combined = EcrParserService.combineSplitNames(
        row,
        lastNameCol: 1,
        firstNameCol: 2,
        middleInitialCol: 3,
      );
      expect(combined, equals('Dela Cruz, Juan A.'));
    });

    test('Handles missing M.I.', () {
      final row = ['109238471901', 'Santos', 'Pedro', '', 25];
      final combined = EcrParserService.combineSplitNames(
        row,
        lastNameCol: 1,
        firstNameCol: 2,
        middleInitialCol: 3,
      );
      expect(combined, equals('Santos, Pedro'));
    });
  });

  group('Phase 1 Pure Helper Units: sanitizeCellValue', () {
    test('Treats formula error strings (#DIV/0!, #REF!) as null', () {
      expect(EcrParserService.sanitizeCellValue('#DIV/0!'), isNull);
      expect(EcrParserService.sanitizeCellValue('#REF!'), isNull);
      expect(EcrParserService.sanitizeCellValue('#N/A'), isNull);
    });

    test('Preserves numeric values and cleans whitespace strings', () {
      expect(EcrParserService.sanitizeCellValue(45.5), equals(45.5));
      expect(EcrParserService.sanitizeCellValue('  98  '), equals(98.0));
      expect(EcrParserService.sanitizeCellValue(''), isNull);
    });
  });

  group('Phase 1 Service Pipeline: Synthetic Fixtures', () {
    final parser = EcrParserService();

    test('Fixture 1: Standard DepEd ECR extracts exactly 5 students and excludes dividers/subtotals', () async {
      final bytes = SyntheticEcrFixtures.createStandardDepedEcr();
      final result = await parser.parseFile(bytes, 'standard_deped_ecr.xlsx');

      // Exactly 5 students (3 boys + 2 girls)
      expect(result.dataRows.length, equals(5));

      // HPS row detected
      expect(result.hpsRowIndex, isNotNull);
      expect(result.rowHpsMap.isNotEmpty, isTrue);
      // Col 3 is WW1 (HPS 20)
      expect(result.rowHpsMap[3], equals(20.0));

      // Excluded rows include MALE, FEMALE, TOTAL MALE, TOTAL FEMALE, COMBINED TOTAL
      final excludedReasons = result.excludedRows.map((e) => e.rawText).toList();
      expect(excludedReasons, contains('MALE'));
      expect(excludedReasons, contains('FEMALE'));
      expect(excludedReasons, contains('TOTAL MALE'));
      expect(excludedReasons, contains('TOTAL FEMALE'));
      expect(excludedReasons, contains('COMBINED TOTAL'));
    });

    test('Fixture 2: Multi-Sheet Workbook auto-selects 1st Quarter sheet and lists candidates', () async {
      final bytes = SyntheticEcrFixtures.createMultiSheetEcr();

      // Sheets discovery
      final sheets = await parser.getAvailableSheets(bytes, 'multisheet_ecr.xlsx', gradingPeriod: '1st Quarter');
      expect(sheets.length, equals(3));
      expect(sheets.first.sheetName, equals('1st Quarter'));
      expect(sheets.first.isCandidate, isTrue);

      // Parse with grading period
      final result = await parser.parseFile(bytes, 'multisheet_ecr.xlsx', gradingPeriod: '1st Quarter');
      expect(result.sheetName, equals('1st Quarter'));
      expect(result.dataRows.length, equals(1));
    });

    test('Fixture 3: Double LRN (109238471901.0) is converted to clean 12-digit string', () async {
      final bytes = SyntheticEcrFixtures.createSplitNamesAndScientificLrnEcr();
      final result = await parser.parseFile(bytes, 'split_names.xlsx');

      expect(result.dataRows.length, equals(2));
      // First student's LRN cell cleaned
      final lrn = EcrParserService.cleanLrn(result.dataRows[0][0]);
      expect(lrn, equals('109238471901'));
    });

    test('Fixture 4: Flat Teacher Sheet without HPS row parses students cleanly', () async {
      final bytes = SyntheticEcrFixtures.createFlatTeacherSheet();
      final result = await parser.parseFile(bytes, 'flat_teacher_sheet.xlsx');

      expect(result.dataRows.length, equals(1));
      expect(result.dataRows[0][0], equals('Juan Dela Cruz'));
    });

    test('Fixture 5: Dirty Data Sheet rejects text scientific notation LRN and handles #DIV/0!', () async {
      final bytes = SyntheticEcrFixtures.createDirtyDataSheet();
      final result = await parser.parseFile(bytes, 'dirty_data.xlsx');

      // Alpha and Beta are students. Gamma has invalid text scientific notation ("1.02345E+11"), TOTAL is subtotal.
      // So Alpha and Beta pass.
      expect(result.dataRows.length, equals(2));

      // Gamma was excluded with invalid LRN
      final gammaExcluded = result.excludedRows.any((e) => e.rawText == 'Student Gamma' || e.reason.contains('LRN'));
      expect(gammaExcluded, isTrue);

      // TOTAL row was excluded
      final totalExcluded = result.excludedRows.any((e) => e.rawText == 'TOTAL');
      expect(totalExcluded, isTrue);
    });
  });

  group('Phase 1 Service Pipeline: Anonymized Real Fixtures', () {
    final parser = EcrParserService();

    test('Real Fixture: Anonymized DepEd Grade 1 XLSX parses subject sheet with zero student PII leaks', () async {
      final file = File('test/fixtures/anonymized_deped_grade1.xlsx');
      if (!file.existsSync()) return;

      final bytes = file.readAsBytesSync();
      final sheets = await parser.getAvailableSheets(bytes, 'grade1.xlsx');

      expect(sheets.isNotEmpty, isTrue);
      // MATH sheet is available
      final mathCandidate = sheets.any((s) => s.sheetName == 'MATH');
      expect(mathCandidate, isTrue);

      final result = await parser.parseFile(bytes, 'grade1.xlsx', targetSheetName: 'MATH');
      expect(result.sheetName, equals('MATH'));
      expect(result.dataRows.isNotEmpty, isTrue);
      expect(result.hpsRowIndex, isNotNull);

      // Verify that MALE divider row is excluded
      final maleExcluded = result.excludedRows.any((e) => e.rawText == 'MALE');
      expect(maleExcluded, isTrue);
    });

    test('Real Fixture: Anonymized MAPEH Q1 CSV parses successfully', () async {
      final file = File('test/fixtures/anonymized_mapeh_q1.csv');
      if (!file.existsSync()) return;

      final bytes = file.readAsBytesSync();
      final result = await parser.parseFile(bytes, 'mapeh_q1.csv');

      expect(result.dataRows.isNotEmpty, isTrue);
      expect(result.hpsRowIndex, isNotNull);

      // Verify MALE divider is excluded
      final maleExcluded = result.excludedRows.any((e) => e.rawText == 'MALE');
      expect(maleExcluded, isTrue);
    });
  });
}
