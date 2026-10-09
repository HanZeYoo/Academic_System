import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';

class SyntheticEcrFixtures {
  static final Directory fixturesDir = Directory('test/fixtures');

  static void ensureFixturesDirectory() {
    if (!fixturesDir.existsSync()) {
      fixturesDir.createSync(recursive: true);
    }
  }

  /// 1. Standard DepEd ECR Layout
  static Uint8List createStandardDepedEcr() {
    final excel = Excel.createExcel();
    final sheetName = 'Q1';
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    // Row 0-6: Metadata
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Class Record');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('(Pursuant to Deped Order 8 series of 2015)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('FIRST QUARTER');

    // Row 7: Parent Headers (Merged)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 7)).value = TextCellValue('LRN');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 7)).value = TextCellValue("LEARNERS' NAMES");

    // Merge WW (Cols 3 to 10)
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 7),
      CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 7),
      customValue: TextCellValue('WRITTEN WORKS (30%)'),
    );

    // Merge PT (Cols 11 to 18)
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 7),
      CellIndex.indexByColumnRow(columnIndex: 18, rowIndex: 7),
      customValue: TextCellValue('PERFORMANCE TASKS (50%)'),
    );

    // QA (Cols 19 to 20)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: 7)).value = TextCellValue('QUARTERLY ASSESSMENT (20%)');

    // Row 8: Sub-Headers (Activity Numbers and Calculated Columns)
    // WW items 1..5, Total, PS, WS
    for (int i = 1; i <= 5; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + i, rowIndex: 8)).value = TextCellValue('$i');
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 8)).value = TextCellValue('Total');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 8)).value = TextCellValue('PS');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 8)).value = TextCellValue('WS');

    // PT items 1..5, Total, PS, WS
    for (int i = 1; i <= 5; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10 + i, rowIndex: 8)).value = TextCellValue('$i');
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: 8)).value = TextCellValue('Total');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: 8)).value = TextCellValue('PS');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 18, rowIndex: 8)).value = TextCellValue('WS');

    // QA
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: 8)).value = TextCellValue('1');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 20, rowIndex: 8)).value = TextCellValue('Quarterly Grade');

    // Row 9: Horizontal HPS Row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 9)).value = TextCellValue('HIGHEST POSSIBLE SCORE');
    // WW HPS: 20, 25, 20, 25, 30 -> Total 120
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 9)).value = IntCellValue(20);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 9)).value = IntCellValue(25);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 9)).value = IntCellValue(20);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 9)).value = IntCellValue(25);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 9)).value = IntCellValue(30);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 9)).value = IntCellValue(120);

    // PT HPS: 50, 50, 50, 50, 50 -> Total 250
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 9)).value = IntCellValue(50);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 9)).value = IntCellValue(50);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 9)).value = IntCellValue(50);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: 9)).value = IntCellValue(50);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: 9)).value = IntCellValue(50);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: 9)).value = IntCellValue(250);

    // QA HPS: 50
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: 9)).value = IntCellValue(50);

    // Row 10: Section Divider MALE
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 10)).value = TextCellValue('MALE');

    // Row 11-13: Male Students
    final maleStudents = [
      {'lrn': 109238471901, 'name': 'DELA CRUZ, JUAN A.', 'ww': [18, 22, 19, 20, 28], 'pt': [45, 48, 47, 46, 49], 'qa': 44},
      {'lrn': 109238471902, 'name': 'SANTOS, PEDRO M.', 'ww': [15, 20, 18, 22, 25], 'pt': [40, 42, 45, 44, 48], 'qa': 40},
      {'lrn': 109238471903, 'name': 'REYES, CARLOS B.', 'ww': [20, 24, 20, 25, 30], 'pt': [50, 49, 50, 48, 50], 'qa': 48},
    ];

    int curRow = 11;
    for (final s in maleStudents) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: curRow)).value = IntCellValue(curRow - 10);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: curRow)).value = IntCellValue(s['lrn'] as int);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: curRow)).value = TextCellValue(s['name'] as String);

      final wwList = s['ww'] as List<int>;
      for (int i = 0; i < wwList.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3 + i, rowIndex: curRow)).value = IntCellValue(wwList[i]);
      }
      final ptList = s['pt'] as List<int>;
      for (int i = 0; i < ptList.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11 + i, rowIndex: curRow)).value = IntCellValue(ptList[i]);
      }
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: curRow)).value = IntCellValue(s['qa'] as int);
      curRow++;
    }

    // Row 14: Subtotal Row TOTAL MALE with numeric sums
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: curRow)).value = TextCellValue('TOTAL MALE');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: curRow)).value = IntCellValue(53); // Sum of WW1
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: curRow)).value = IntCellValue(66); // Sum of WW2
    curRow++;

    // Row 15: Section Divider FEMALE
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: curRow)).value = TextCellValue('FEMALE');
    curRow++;

    // Row 16-17: Female Students
    final femaleStudents = [
      {'lrn': 109238471904, 'name': 'GARCIA, MARIA L.', 'ww': [19, 23, 19, 24, 29], 'pt': [48, 49, 48, 47, 50], 'qa': 46},
      {'lrn': 109238471905, 'name': 'RAMOS, ANA P.', 'ww': [17, 21, 18, 23, 27], 'pt': [44, 45, 46, 45, 48], 'qa': 42},
    ];

    for (final s in femaleStudents) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: curRow)).value = IntCellValue(curRow - 15);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: curRow)).value = IntCellValue(s['lrn'] as int);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: curRow)).value = TextCellValue(s['name'] as String);

      final wwList = s['ww'] as List<int>;
      for (int i = 0; i < wwList.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3 + i, rowIndex: curRow)).value = IntCellValue(wwList[i]);
      }
      final ptList = s['pt'] as List<int>;
      for (int i = 0; i < ptList.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11 + i, rowIndex: curRow)).value = IntCellValue(ptList[i]);
      }
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: curRow)).value = IntCellValue(s['qa'] as int);
      curRow++;
    }

    // Row 18: Summary TOTAL FEMALE
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: curRow)).value = TextCellValue('TOTAL FEMALE');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: curRow)).value = IntCellValue(36);
    curRow++;

    // Row 19: COMBINED TOTAL
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: curRow)).value = TextCellValue('COMBINED TOTAL');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: curRow)).value = IntCellValue(89);

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  /// 2. Multi-Sheet ECR Workbook
  static Uint8List createMultiSheetEcr() {
    final excel = Excel.createExcel();
    // Tab 1: INPUT DATA (empty scores)
    final inputSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(inputSheet, 'INPUT DATA');
    final s1 = excel['INPUT DATA'];
    s1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Input Data Sheet for E-Class Record');
    s1.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('SCHOOL NAME: Mabini Elementary');

    // Tab 2: 1st Quarter (Scores)
    final s2 = excel['1st Quarter'];
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('FIRST QUARTER');
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('LRN');
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = TextCellValue("Learner's Name");
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).value = TextCellValue('Quiz 1');
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value = TextCellValue('Quiz 2');
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 2)).value = TextCellValue('Activity 1');
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 2)).value = TextCellValue('Exam');

    // HPS row
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = TextCellValue('HIGHEST POSSIBLE SCORE');
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3)).value = IntCellValue(30);
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 3)).value = IntCellValue(30);
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3)).value = IntCellValue(50);
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 3)).value = IntCellValue(50);

    // Students
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value = IntCellValue(109238471901);
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value = TextCellValue('Dela Cruz, Juan');
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 4)).value = IntCellValue(28);
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 4)).value = IntCellValue(29);
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 4)).value = IntCellValue(48);
    s2.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 4)).value = IntCellValue(45);

    // Tab 3: INSTRUCTIONS
    final s3 = excel['INSTRUCTIONS'];
    s3.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Guidelines on grading');

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  /// 3. Split Names and Scientific-Notation LRN
  static Uint8List createSplitNamesAndScientificLrnEcr() {
    final excel = Excel.createExcel();
    final sheetName = 'GradeSheet';
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('LRN');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('Last Name');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = TextCellValue('First Name');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value = TextCellValue('M.I.');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value = TextCellValue('Quiz 1');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0)).value = TextCellValue('Quiz 2');

    // Row 1: Student 1 (LRN as double 109238471901.0)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = DoubleCellValue(109238471901.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('Dela Cruz');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = TextCellValue('Juan');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = TextCellValue('A');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value = IntCellValue(25);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value = IntCellValue(28);

    // Row 2: Student 2
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = DoubleCellValue(109238471902.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = TextCellValue('Santos');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).value = TextCellValue('Pedro');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value = TextCellValue('M');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 2)).value = IntCellValue(22);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 2)).value = IntCellValue(24);

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  /// 4. Flat Teacher Sheet (no merged cells, no HPS row)
  static Uint8List createFlatTeacherSheet() {
    final excel = Excel.createExcel();
    final sheetName = 'MathScores';
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Student Name');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('LRN');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = TextCellValue('WW1');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value = TextCellValue('WW2');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value = TextCellValue('PT1');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0)).value = TextCellValue('QA');

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('Juan Dela Cruz');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('109238471901');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = IntCellValue(25);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = IntCellValue(28);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value = IntCellValue(48);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value = IntCellValue(42);

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  /// 5. Dirty Data Sheet (score > HPS, #DIV/0!, text scientific notation LRN)
  static Uint8List createDirtyDataSheet() {
    final excel = Excel.createExcel();
    final sheetName = 'DirtyData';
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('LRN');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('Learner');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = TextCellValue('WW1');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value = TextCellValue('WW2');

    // HPS row: WW1 HPS is 25, WW2 HPS is 25
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('HPS');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = IntCellValue(25);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = IntCellValue(25);

    // Row 2: Valid student
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('109238471901');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = TextCellValue('Student Alpha');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).value = IntCellValue(20);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value = IntCellValue(22);

    // Row 3: Score exceeds HPS (WW1 is 30 > 25)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = TextCellValue('109238471902');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = TextCellValue('Student Beta');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3)).value = IntCellValue(30);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 3)).value = IntCellValue(20);

    // Row 4: Text-formatted scientific notation LRN ("1.02345E+11" -> must be rejected)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value = TextCellValue('1.02345E+11');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value = TextCellValue('Student Gamma');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 4)).value = IntCellValue(18);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 4)).value = TextCellValue('#DIV/0!');

    // Row 5: Subtotal row TOTAL with numeric sums
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5)).value = TextCellValue('TOTAL');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 5)).value = IntCellValue(68);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 5)).value = IntCellValue(62);

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  /// Saves all synthetic fixtures to disk
  static void saveAllFixturesToDisk() {
    ensureFixturesDirectory();
    File('test/fixtures/standard_deped_ecr.xlsx').writeAsBytesSync(createStandardDepedEcr());
    File('test/fixtures/multisheet_ecr.xlsx').writeAsBytesSync(createMultiSheetEcr());
    File('test/fixtures/split_names_and_scientific_lrn.xlsx').writeAsBytesSync(createSplitNamesAndScientificLrnEcr());
    File('test/fixtures/flat_teacher_sheet.xlsx').writeAsBytesSync(createFlatTeacherSheet());
    File('test/fixtures/dirty_data_ecr.xlsx').writeAsBytesSync(createDirtyDataSheet());
  }
}
