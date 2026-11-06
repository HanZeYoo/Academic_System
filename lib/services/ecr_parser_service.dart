import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../models/ecr_mapping_model.dart';
import '../models/ecr_transmutation_model.dart';

class EcrParseParams {
  final Uint8List bytes;
  final String filename;
  final String? targetSheetName;
  final String? gradingPeriod;

  const EcrParseParams({
    required this.bytes,
    required this.filename,
    this.targetSheetName,
    this.gradingPeriod,
  });
}

class EcrWeightPercentages {
  final double wwWeight;
  final double ptWeight;
  final double qaWeight;
  final bool isDetected;

  const EcrWeightPercentages({
    required this.wwWeight,
    required this.ptWeight,
    required this.qaWeight,
    this.isDetected = false,
  });

  @override
  String toString() => 'WW: ${wwWeight.toInt()}% | PT: ${ptWeight.toInt()}% | QA: ${qaWeight.toInt()}%';
}

class EcrParseResult {
  final String filename;
  final String sheetName;
  final List<String> headers;
  final List<List<dynamic>> rawGrid;
  final int headerRowIndex;
  final bool isStackedHeader;
  final List<List<dynamic>> dataRows;
  final List<int> originalRowIndices; // 1-indexed row numbers in source sheet
  final int? hpsRowIndex;
  final Map<int, double> rowHpsMap; // colIndex -> HPS extracted from HPS row
  final List<EcrExcludedRow> excludedRows;
  final List<EcrSheetSummary> availableSheets;
  final EcrWeightPercentages detectedWeights;
  final EcrTransmutationTable detectedTransmutation;

  EcrParseResult({
    required this.filename,
    required this.sheetName,
    required this.headers,
    required this.rawGrid,
    required this.headerRowIndex,
    required this.isStackedHeader,
    required this.dataRows,
    required this.originalRowIndices,
    this.hpsRowIndex,
    required this.rowHpsMap,
    required this.excludedRows,
    required this.availableSheets,
    this.detectedWeights = const EcrWeightPercentages(
      wwWeight: 30.0,
      ptWeight: 50.0,
      qaWeight: 20.0,
      isDetected: false,
    ),
    this.detectedTransmutation = const EcrTransmutationTable(
      description: 'DepEd Base-70',
      passingRawScore: 70.0,
      isDetected: false,
    ),
  });
}

class EcrParserService {
  /// Keywords used to evaluate candidate header row density
  static const List<String> headerKeywords = [
    'name',
    'student',
    'learner',
    'learners',
    'lrn',
    'ww',
    'written',
    'quiz',
    'pt',
    'performance',
    'task',
    'output',
    'qa',
    'quarterly',
    'assessment',
    'exam',
    'hps',
    'highest',
    'total',
    'grade',
    'score',
  ];

  static const List<String> nonCandidateSheetKeywords = [
    'input data',
    'data input',
    'do not delete',
    'guidelines',
    'instruction',
    'instructions',
    'transmutation',
    'settings',
    'config',
    'deportment',
    'report of grades',
    'official report',
    'summary of grades',
  ];

  // ── PURE HELPER METHODS ──────────────────────────────────────────────────

  /// Normalizes and strictly validates a 12-digit DepEd LRN.
  /// - Only numeric Excel cells or clean integer strings are converted.
  /// - Text-formatted scientific notation (e.g. "1.023E+11") is rejected as invalid.
  /// - Never blindly padLeft; must be exactly 12 numeric digits.
  static String? cleanLrn(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      if (raw.isNaN || raw.isInfinite) return null;
      // Convert to integer string without scientific notation
      final str = raw.toInt().toString();
      if (RegExp(r'^\d{12}$').hasMatch(str) || RegExp(r'^\d{9}$').hasMatch(str)) {
        return str;
      }
      return null;
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    // Reject text-formatted scientific notation (contains e or E)
    if (RegExp(r'[eE]').hasMatch(text)) {
      return null;
    }

    // Strip internal spaces/dashes if any
    final sanitized = text.replaceAll(RegExp(r'[\s\-]'), '');
    if (RegExp(r'^\d{12}$').hasMatch(sanitized) || RegExp(r'^\d{9}$').hasMatch(sanitized)) {
      return sanitized;
    }

    return null;
  }

  /// Sanitizes cell values handling FormulaCellValue, errors (#DIV/0!, #REF!), and blanks.
  static dynamic sanitizeCellValue(dynamic cellValue) {
    if (cellValue == null) return null;

    if (cellValue is FormulaCellValue) {
      final formula = cellValue.formula.trim();
      if (formula.startsWith('#')) return null; // Formula error code
      return formula;
    }

    final str = cellValue.toString().trim();
    if (str.isEmpty) return null;

    // Error strings from spreadsheets
    if (str == '#DIV/0!' ||
        str == '#REF!' ||
        str == '#N/A' ||
        str == '#VALUE!' ||
        str == '#NAME?' ||
        str == '#NUM!') {
      return null;
    }

    // Numbers
    if (cellValue is num) return cellValue;
    final parsed = double.tryParse(str);
    if (parsed != null) return parsed;

    return str;
  }

  /// Tests whether a given row represents an actual student vs a divider, subtotal, or empty template row.
  /// - Student name must be a plausible human name (not a formula, number, or placeholder).
  /// - If an LRN column exists with high fill rate, a valid 12-digit LRN is required.
  /// - Keyword blacklist (MALE, FEMALE, TOTAL, etc.) is checked.
  /// - Subtotal rows with numeric sums and empty template slots are rejected.
  static bool isStudentRow({
    required String name,
    required String? lrn,
    required List<dynamic> scores,
    bool hasHighFillLrnColumn = false,
  }) {
    final trimmedName = name.trim();

    // 1. Divider, summary blacklist, and valid student name check
    if (trimmedName.isEmpty) return false;
    if (!isValidStudentName(trimmedName)) return false;

    // 2. High-fill LRN enforcement
    if (hasHighFillLrnColumn) {
      final validLrn = cleanLrn(lrn);
      if (validLrn == null) {
        // Name-only row under an active LRN column is treated as a divider or subtotal
        return false;
      }
    }

    // 3. Evidence check: must have either valid LRN, student ID, or at least one numeric score
    final hasValidLrn = cleanLrn(lrn) != null;
    final lrnStr = lrn?.toString().trim() ?? '';
    final hasValidStudentId = lrnStr.isNotEmpty && !lrnStr.startsWith('=') && !lrnStr.startsWith('#');
    final hasScore = scores.any((s) {
      if (s == null) return false;
      if (s is num && s >= 0) return true;
      final p = double.tryParse(s.toString());
      return p != null && p >= 0;
    });

    return hasValidLrn || hasValidStudentId || hasScore;
  }

  /// Tests whether a given string is a plausible student name.
  /// Rejects Excel formulas, sheet references, error codes, pure numbers, and divider labels.
  static bool isValidStudentName(String? name) {
    if (name == null) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    // Unresolved Excel formula (e.g. "='INPUT DATA'!B14", "=SUM(..)")
    if (trimmed.startsWith('=')) return false;

    // Sheet references or cross-sheet formula remnants
    if (trimmed.contains('!') || trimmed.toUpperCase().contains('INPUT DATA')) return false;

    // Excel error codes
    if (trimmed.startsWith('#') || trimmed.contains('REF!')) return false;

    // Purely numeric, decimals, row numbers, or dashes ("0", "0.0", "1", "50", "-", "--", "---")
    if (RegExp(r'^[\d\.\-\s]+$').hasMatch(trimmed)) return false;

    // Common non-name placeholder strings
    final upper = trimmed.toUpperCase();
    if (upper == '0' || upper == 'N/A' || upper == 'NA' || upper == 'NONE' || upper == 'NULL') {
      return false;
    }

    // Divider and summary keywords
    if (_isNonStudentLabel(upper)) return false;

    // Must contain at least 2 alphabetic letters (allows all real names, e.g. "Al", "Yu", "Dela Cruz")
    if (!RegExp(r'[A-Za-z].*[A-Za-z]').hasMatch(trimmed)) return false;

    return true;
  }

  static bool _isNonStudentLabel(String upper) {
    return upper == 'MALE' ||
        upper == 'FEMALE' ||
        upper.startsWith('TOTAL') ||
        upper.startsWith('KABUUAN') ||
        upper.startsWith('AVERAGE') ||
        upper.contains('COMBINED') ||
        upper.contains('PASSED') ||
        upper.contains('FAILED') ||
        upper.startsWith('BOYS') ||
        upper.startsWith('GIRLS') ||
        upper.contains('HIGHEST POSSIBLE SCORE') ||
        upper == 'HPS' ||
        upper.contains("LEARNER'S") ||
        upper.contains("LEARNERS'") ||
        upper.contains('STUDENT NAME') ||
        upper.contains('NAME OF') ||
        upper.contains('SUMMARY') ||
        upper.contains('CLASS RECORD');
  }

  /// Detects DepEd weight percentages from header strings or top metadata rows.
  /// E.g. "WRITTEN WORKS (40%)", "PERFORMANCE TASKS (40%)", "QUARTERLY ASSESSMENT (20%)".
  static EcrWeightPercentages detectWeights(List<List<dynamic>> grid, List<String> headers) {
    double? ww;
    double? pt;
    double? qa;

    void checkString(String text) {
      final upper = text.toUpperCase();
      if (ww == null) {
        final match = RegExp(r'(?:WRITTEN(?:\s+WORKS)?|WW)[^\d%]{0,15}(\d+(?:\.\d+)?)\s*%').firstMatch(upper);
        if (match != null) ww = double.tryParse(match.group(1)!);
      }
      if (pt == null) {
        final match = RegExp(r'(?:PERFORMANCE(?:\s+TASKS)?|PT)[^\d%]{0,15}(\d+(?:\.\d+)?)\s*%').firstMatch(upper);
        if (match != null) pt = double.tryParse(match.group(1)!);
      }
      if (qa == null) {
        final match = RegExp(r'(?:QUARTERLY(?:\s+ASSESSMENT)?|ASSESSMENT|QA|EXAM)[^\d%]{0,15}(\d+(?:\.\d+)?)\s*%').firstMatch(upper);
        if (match != null) qa = double.tryParse(match.group(1)!);
      }
    }

    // 1. Check all headers
    for (final h in headers) {
      checkString(h);
    }

    // 2. Scan first 15 rows of grid if any component wasn't found
    if (ww == null || pt == null || qa == null) {
      final scanLimit = grid.length < 15 ? grid.length : 15;
      for (int r = 0; r < scanLimit; r++) {
        for (final cell in grid[r]) {
          if (cell != null) {
            checkString(cell.toString());
          }
        }
      }
    }

    // 2b. Check for decimal weights matched to WW / PT / QA columns (e.g. 0.2, 0.6, 0.2 or 0.2, 0.5, 0.3)
    if (ww == null || pt == null || qa == null) {
      final scanLimit = grid.length < 6 ? grid.length : 6;
      for (int r = 0; r < scanLimit; r++) {
        double? rowWw;
        double? rowPt;
        double? rowQa;
        for (int c = 0; c < grid[r].length; c++) {
          final cell = grid[r][c];
          if (cell == null) continue;
          final parsed = double.tryParse(cell.toString().trim());
          if (parsed != null && parsed > 0 && parsed < 1.0) {
            final colContext = (grid.isNotEmpty && c < grid[0].length ? grid[0][c].toString() : '') +
                ' ' + (c < headers.length ? headers[c] : '');
            final normContext = colContext.toUpperCase().replaceAll(' ', '');
            if (rowWw == null && (normContext.contains('WRITTEN') || normContext.contains('WW'))) {
              rowWw = parsed;
            } else if (rowPt == null && (normContext.contains('PERFORMANCE') || normContext.contains('PT'))) {
              rowPt = parsed;
            } else if (rowQa == null && (normContext.contains('EXAM') || normContext.contains('ASSESSMENT') || normContext.contains('QA'))) {
              rowQa = parsed;
            }
          }
        }
        if (rowWw != null && rowPt != null && rowQa != null) {
          final sum = rowWw + rowPt + rowQa;
          if ((sum - 1.0).abs() <= 0.05) {
            ww = (rowWw * 100).roundToDouble();
            pt = (rowPt * 100).roundToDouble();
            qa = (rowQa * 100).roundToDouble();
            break;
          }
        }
      }
    }

    // If all three were detected and sum close to 100%, return them
    if (ww != null && pt != null && qa != null) {
      final sum = ww! + pt! + qa!;
      if ((sum - 100).abs() <= 2.0) {
        return EcrWeightPercentages(
          wwWeight: ww!,
          ptWeight: pt!,
          qaWeight: qa!,
          isDetected: true,
        );
      }
    }

    // Fallback standard DepEd default: 30% WW, 50% PT, 20% QA
    return const EcrWeightPercentages(
      wwWeight: 30.0,
      ptWeight: 50.0,
      qaWeight: 20.0,
      isDetected: false,
    );
  }

  /// Detects whether an Excel file contains a Transmutation sheet and extracts the lookup brackets.
  static EcrTransmutationTable detectTransmutationTable(Excel excel) {
    String? targetSheetName;
    for (final name in excel.tables.keys) {
      final lower = name.toLowerCase().trim();
      if (lower.contains('transmut')) {
        targetSheetName = name;
        break;
      }
    }

    if (targetSheetName == null) {
      return const EcrTransmutationTable(
        description: 'DepEd Base-70',
        passingRawScore: 70.0,
        isDetected: false,
      );
    }

    final sheet = excel.tables[targetSheetName];
    if (sheet == null || sheet.maxRows < 10) {
      return const EcrTransmutationTable(
        description: 'DepEd Base-70',
        passingRawScore: 70.0,
        isDetected: false,
      );
    }

    final rows = sheet.rows;
    final maxCols = sheet.maxColumns;

    int maxValidPairs = 0;
    Map<double, int> bestBrackets = {};

    for (int c = 0; c < maxCols - 1; c++) {
      for (int cNext = c + 1; cNext <= c + 2 && cNext < maxCols; cNext++) {
        final candidateBrackets = <double, int>{};
        bool has75 = false;

        for (int r = 0; r < rows.length; r++) {
          final row = rows[r];
          if (c >= row.length || cNext >= row.length) continue;

          final rawCell = row[c]?.value;
          final gradeCell = row[cNext]?.value;
          if (rawCell == null || gradeCell == null) continue;

          double? rawVal;
          if (rawCell is IntCellValue) {
            rawVal = rawCell.value.toDouble();
          } else if (rawCell is DoubleCellValue) {
            rawVal = rawCell.value;
          } else {
            rawVal = double.tryParse(rawCell.toString().trim());
          }

          int? gradeVal;
          if (gradeCell is IntCellValue) {
            gradeVal = gradeCell.value;
          } else if (gradeCell is DoubleCellValue) {
            gradeVal = gradeCell.value.toInt();
          } else {
            final parsed = double.tryParse(gradeCell.toString().trim());
            if (parsed != null) gradeVal = parsed.toInt();
          }

          if (rawVal != null && gradeVal != null) {
            if (rawVal >= 0 && rawVal <= 100 && gradeVal >= 50 && gradeVal <= 100) {
              candidateBrackets[rawVal] = gradeVal;
              if (gradeVal == 75) has75 = true;
            }
          }
        }

        if (has75 && candidateBrackets.length > maxValidPairs && candidateBrackets.length >= 15) {
          maxValidPairs = candidateBrackets.length;
          bestBrackets = candidateBrackets;
        }
      }
    }

    if (bestBrackets.isNotEmpty && maxValidPairs >= 15) {
      final sortedBrackets = Map.fromEntries(
        bestBrackets.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );

      double passingRaw = 70.0;
      for (final entry in sortedBrackets.entries) {
        if (entry.value == 75) {
          passingRaw = entry.key;
          break;
        }
      }

      String desc;
      if (passingRaw >= 68.0 && passingRaw <= 72.0) {
        desc = 'DepEd Base-70 (Passing: 70 → 75)';
      } else if (passingRaw >= 58.0 && passingRaw <= 62.0) {
        desc = 'DepEd Base-60 (Passing: 60 → 75)';
      } else if (passingRaw >= 48.0 && passingRaw <= 52.0) {
        desc = 'Base-50 (Passing: 50 → 75)';
      } else {
        desc = 'Custom Scale (Passing: ${passingRaw.toStringAsFixed(1)} → 75)';
      }

      final minGrade = sortedBrackets.values.reduce((a, b) => a < b ? a : b).toDouble();
      final maxGrade = sortedBrackets.values.reduce((a, b) => a > b ? a : b).toDouble();

      return EcrTransmutationTable(
        sheetName: targetSheetName,
        description: desc,
        passingRawScore: (passingRaw >= 69.0 && passingRaw <= 71.0) ? 70.0 : passingRaw,
        minRawScore: sortedBrackets.keys.first,
        minGrade: minGrade,
        passingGrade: 75.0,
        maxGrade: maxGrade,
        brackets: sortedBrackets,
        isDetected: true,
      );
    }

    return const EcrTransmutationTable(
      description: 'DepEd Base-70',
      passingRawScore: 70.0,
      isDetected: false,
    );
  }

  /// Finds a horizontal row containing "Highest Possible Score" or "HPS"
  /// and extracts per-column maximum scores.
  static Map<int, double> detectHpsRow(List<List<dynamic>> grid, int headerRowIndex) {
    final Map<int, double> hpsMap = {};

    // Scan up to 6 rows around/below the header row
    final scanEnd = (headerRowIndex + 6 < grid.length) ? headerRowIndex + 6 : grid.length;

    for (int r = headerRowIndex; r < scanEnd; r++) {
      final row = grid[r];
      bool isHpsRow = false;

      // Check first 10 columns for HPS keyword
      final checkLimit = row.length < 10 ? row.length : 10;
      for (int c = 0; c < checkLimit; c++) {
        final cellStr = row[c]?.toString().toUpperCase().trim() ?? '';
        if (cellStr.contains('HIGHEST POSSIBLE SCORE') ||
            cellStr.contains('HIGHEST SCORE') ||
            cellStr == 'HPS' ||
            cellStr.contains('PERFECT SCORE') ||
            cellStr.contains('MAXIMUM SCORE') ||
            cellStr == 'MAX SCORE' ||
            cellStr == 'TOTAL SCORE' ||
            cellStr.contains('PINAKAMATAAS') ||
            cellStr.contains('KABUUANG ISKOR')) {
          isHpsRow = true;
          break;
        }
      }

      // Check for HPS row positioned below header with subtitle (Lastname, Firstname, MI)
      if (!isHpsRow && r > headerRowIndex && r <= headerRowIndex + 2) {
        final nameCell = (row.length > 2) ? row[2]?.toString().trim() ?? '' : '';
        final isSubtitle = nameCell.contains('Lastname') || nameCell.contains('Firstname') || nameCell.isEmpty;
        if (isSubtitle && r + 1 < grid.length) {
          final nextNameCell = (grid[r + 1].length > 2) ? grid[r + 1][2]?.toString().toUpperCase().trim() ?? '' : '';
          final nextIsDividerOrStudent = nextNameCell.startsWith('BOYS') || nextNameCell.startsWith('MALE') || nextNameCell.startsWith('GIRLS') || isValidStudentName(nextNameCell);
          if (nextIsDividerOrStudent) {
            int numCount = 0;
            for (int c = 3; c < row.length; c++) {
              final val = row[c];
              if (val is num && val > 0) numCount++;
              else if (val != null && double.tryParse(val.toString()) != null && double.tryParse(val.toString())! > 0) numCount++;
            }
            if (numCount >= 2) {
              isHpsRow = true;
            }
          }
        }
      }

      if (isHpsRow) {
        for (int c = 0; c < row.length; c++) {
          final val = row[c];
          if (val is num && val > 0) {
            hpsMap[c] = val.toDouble();
          } else if (val != null) {
            final parsed = double.tryParse(val.toString().trim());
            if (parsed != null && parsed > 0) {
              hpsMap[c] = parsed;
            }
          }
        }
        break;
      }
    }

    return hpsMap;
  }

  /// Combines split name columns (LAST, FIRST, M.I.) into standard "LAST, FIRST M.I." format.
  static String combineSplitNames(
    List<dynamic> row, {
    required int lastNameCol,
    int? firstNameCol,
    int? middleInitialCol,
  }) {
    final last = (lastNameCol < row.length) ? row[lastNameCol]?.toString().trim() ?? '' : '';
    final first = (firstNameCol != null && firstNameCol < row.length)
        ? row[firstNameCol]?.toString().trim() ?? ''
        : '';
    final mi = (middleInitialCol != null && middleInitialCol < row.length)
        ? row[middleInitialCol]?.toString().trim() ?? ''
        : '';

    if (first.isEmpty && mi.isEmpty) return last;
    if (first.isEmpty) return '$last $mi'.trim();
    if (mi.isEmpty) return '$last, $first'.trim();
    return '$last, $first $mi${mi.endsWith('.') ? '' : '.'}'.trim();
  }

  // ── SHEET DISCOVERY & PARSING ───────────────────────────────────────────

  /// Inspects bytes and returns all available sheets with candidate scores for a grading period.
  Future<List<EcrSheetSummary>> getAvailableSheets(
    Uint8List bytes,
    String filename, {
    String? gradingPeriod,
  }) async {
    final lowerName = filename.toLowerCase();

    if (lowerName.endsWith('.csv')) {
      return [
        EcrSheetSummary(
          sheetName: filename,
          rowCount: 0,
          columnCount: 0,
          isCandidate: true,
          matchScore: 1.0,
        )
      ];
    }

    try {
      final excel = Excel.decodeBytes(bytes);
      List<EcrSheetSummary> summaries = [];

      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName];
        if (sheet == null) continue;

        final rows = sheet.maxRows;
        final cols = sheet.maxColumns;
        final lowerSheet = sheetName.toLowerCase().trim();

        bool isNonCandidate = false;
        for (final kw in nonCandidateSheetKeywords) {
          if (lowerSheet.contains(kw)) {
            isNonCandidate = true;
            break;
          }
        }

        double score = 0.5;
        if (rows < 5 || cols < 3) {
          score = 0.0;
          isNonCandidate = true;
        }

        if (gradingPeriod != null) {
          final targetKeywords = _getGradingPeriodKeywords(gradingPeriod);
          for (final kw in targetKeywords) {
            if (lowerSheet.contains(kw)) {
              score = 1.0;
              break;
            }
          }
        }

        summaries.add(EcrSheetSummary(
          sheetName: sheetName,
          rowCount: rows,
          columnCount: cols,
          isCandidate: !isNonCandidate && score > 0.3,
          matchScore: score,
        ));
      }

      // Sort by candidate first, then matchScore descending
      summaries.sort((a, b) {
        if (a.isCandidate != b.isCandidate) {
          return a.isCandidate ? -1 : 1;
        }
        return b.matchScore.compareTo(a.matchScore) * -1;
      });

      return summaries;
    } catch (e) {
      throw FormatException(
        'Could not inspect spreadsheet tabs. If using an older .xls file, please save as .xlsx in Excel or export as CSV.',
      );
    }
  }

  List<String> _getGradingPeriodKeywords(String period) {
    final lower = period.toLowerCase();
    if (lower.contains('1') || lower.contains('first')) {
      return ['1st', 'first', 'q1', '1q', 'quarter 1'];
    } else if (lower.contains('2') || lower.contains('second')) {
      return ['2nd', 'second', 'q2', '2q', 'quarter 2'];
    } else if (lower.contains('3') || lower.contains('third')) {
      return ['3rd', 'third', 'q3', '3q', 'quarter 3'];
    } else if (lower.contains('4') || lower.contains('fourth')) {
      return ['4th', 'fourth', 'q4', '4q', 'quarter 4'];
    }
    return [];
  }

  // ── BACKGROUND ISOLATE PARSER ENTRY ────────────────────────────────────

  static EcrParseResult _computeParseFile(EcrParseParams params) {
    final parser = EcrParserService();
    return parser.parseFileSync(
      params.bytes,
      params.filename,
      targetSheetName: params.targetSheetName,
      gradingPeriod: params.gradingPeriod,
    );
  }

  /// Parses file bytes in a background isolate (via compute) to keep UI running at 60/120 FPS.
  Future<EcrParseResult> parseFile(
    Uint8List bytes,
    String filename, {
    String? targetSheetName,
    String? gradingPeriod,
  }) async {
    return compute(
      _computeParseFile,
      EcrParseParams(
        bytes: bytes,
        filename: filename,
        targetSheetName: targetSheetName,
        gradingPeriod: gradingPeriod,
      ),
    );
  }

  /// Synchronous core parser (executes in background isolate)
  EcrParseResult parseFileSync(
    Uint8List bytes,
    String filename, {
    String? targetSheetName,
    String? gradingPeriod,
  }) {
    final lowerName = filename.toLowerCase();
    List<List<dynamic>> rawGrid = [];
    String selectedSheetName = filename;
    List<EcrSheetSummary> availableSheets = [];
    EcrTransmutationTable detectedTransmutation = const EcrTransmutationTable();

    try {
      if (lowerName.endsWith('.csv')) {
        rawGrid = _parseCsv(bytes);
        selectedSheetName = filename;
        availableSheets = [
          EcrSheetSummary(
            sheetName: filename,
            rowCount: rawGrid.length,
            columnCount: rawGrid.isEmpty ? 0 : rawGrid.first.length,
            isCandidate: true,
            matchScore: 1.0,
          )
        ];
      } else if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
        final parsedExcel = _parseExcelWithSheet(
          bytes,
          targetSheetName: targetSheetName,
          gradingPeriod: gradingPeriod,
        );
        rawGrid = _detectAndSliceHorizontalQuarterGrid(parsedExcel.grid, gradingPeriod);
        selectedSheetName = parsedExcel.sheetName;
        availableSheets = parsedExcel.sheets;
        detectedTransmutation = parsedExcel.detectedTransmutation;
      } else {
        throw const FormatException('Unsupported file format. Please upload .xlsx or .csv');
      }
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException(
        'Could not read spreadsheet file: ${e.toString()}. If using an older .xls file, please save as .xlsx in Excel or export as CSV.',
      );
    }

    if (rawGrid.isEmpty) {
      throw const FormatException('Uploaded spreadsheet contains no data or could not be read.');
    }

    // Standardize all rows to equal length
    int maxCols = 0;
    for (final row in rawGrid) {
      if (row.length > maxCols) maxCols = row.length;
    }
    for (int r = 0; r < rawGrid.length; r++) {
      while (rawGrid[r].length < maxCols) {
        rawGrid[r].add('');
      }
    }

    // Detect header row index (scanning up to row 25)
    final headerDetection = _detectHeaderRows(rawGrid);
    final headerRowIndex = headerDetection.headerRowIndex;
    final isStacked = headerDetection.isStackedHeader;
    final headers = headerDetection.finalHeaders;

    // Detect horizontal HPS row
    final rowHpsMap = detectHpsRow(rawGrid, headerRowIndex);
    int? hpsRowIdx;
    for (int r = headerRowIndex; r < (headerRowIndex + 6 < rawGrid.length ? headerRowIndex + 6 : rawGrid.length); r++) {
      final checkLimit = rawGrid[r].length < 10 ? rawGrid[r].length : 10;
      for (int c = 0; c < checkLimit; c++) {
        final str = rawGrid[r][c]?.toString().toUpperCase().trim() ?? '';
        if (str.contains('HIGHEST POSSIBLE SCORE') ||
            str.contains('HIGHEST SCORE') ||
            str == 'HPS' ||
            str.contains('PERFECT SCORE') ||
            str.contains('MAXIMUM SCORE') ||
            str == 'MAX SCORE' ||
            str == 'TOTAL SCORE' ||
            str.contains('PINAKAMATAAS') ||
            str.contains('KABUUANG ISKOR')) {
          hpsRowIdx = r;
          break;
        }
      }
      if (hpsRowIdx != null) break;
    }
    if (hpsRowIdx == null && rowHpsMap.isNotEmpty && headerRowIndex + 1 < rawGrid.length) {
      hpsRowIdx = headerRowIndex + 1;
    }

    // Determine candidate name and LRN column indices from headers
    int nameColIndex = -1;
    int lrnColIndex = -1;
    for (int c = 0; c < headers.length; c++) {
      final h = headers[c].toLowerCase();
      if (nameColIndex == -1 && (h.contains('learner') || h.contains('name') || h.contains('student') || h.contains('pangalan'))) {
        nameColIndex = c;
      }
      if (lrnColIndex == -1 && (h.contains('lrn') || h.contains('id no') || h.contains('ref no'))) {
        lrnColIndex = c;
      }
    }
    if (nameColIndex == -1) nameColIndex = 1; // Default DepEd Col 1

    // Check if LRN column has high fill rate among rows with valid student names
    bool hasHighFillLrn = false;
    if (lrnColIndex != -1) {
      int nonBlankLrn = 0;
      int candidateStudents = 0;
      final start = (hpsRowIdx != null) ? hpsRowIdx + 1 : headerRowIndex + 1;
      for (int r = start; r < rawGrid.length && candidateStudents < 30; r++) {
        final row = rawGrid[r];
        String candidateName = '';
        if (nameColIndex < row.length) {
          candidateName = row[nameColIndex]?.toString().trim() ?? '';
        }
        if (!isValidStudentName(candidateName) && row.isNotEmpty) {
          final c2 = (row.length > 2) ? row[2]?.toString().trim() ?? '' : '';
          final c0 = row[0]?.toString().trim() ?? '';
          if (isValidStudentName(c2)) {
            candidateName = c2;
          } else if (isValidStudentName(c0)) {
            candidateName = c0;
          }
        }
        if (isValidStudentName(candidateName)) {
          candidateStudents++;
          if (lrnColIndex < row.length && cleanLrn(row[lrnColIndex]) != null) {
            nonBlankLrn++;
          }
        }
      }
      hasHighFillLrn = candidateStudents > 0 && (nonBlankLrn / candidateStudents) > 0.40;
    }

    // Filter student rows and record excluded divider/summary rows
    final startRow = (hpsRowIdx != null) ? hpsRowIdx + 1 : headerRowIndex + 1;
    List<List<dynamic>> dataRows = [];
    List<int> originalRowIndices = [];
    List<EcrExcludedRow> excludedRows = [];

    for (int r = startRow; r < rawGrid.length; r++) {
      final row = rawGrid[r];
      final displayRow = r + 1; // 1-indexed

      // Skip completely blank rows
      final hasContent = row.any((c) => c != null && c.toString().trim().isNotEmpty);
      if (!hasContent) continue;

      String nameVal = '';
      if (nameColIndex < row.length) {
        nameVal = row[nameColIndex]?.toString().trim() ?? '';
      }
      // Fallback check col 0 or 2 if nameVal is blank or not a plausible student name
      if (!isValidStudentName(nameVal) && row.isNotEmpty) {
        final c2 = (row.length > 2) ? row[2]?.toString().trim() ?? '' : '';
        final c0 = row[0]?.toString().trim() ?? '';
        if (isValidStudentName(c2)) {
          nameVal = c2;
        } else if (isValidStudentName(c0)) {
          nameVal = c0;
        }
      }

      String? lrnVal;
      if (lrnColIndex != -1 && lrnColIndex < row.length) {
        lrnVal = row[lrnColIndex]?.toString().trim();
      }

      // Collect scores
      final scores = <dynamic>[];
      for (int c = 0; c < row.length; c++) {
        if (c != nameColIndex && c != lrnColIndex) {
          scores.add(sanitizeCellValue(row[c]));
        }
      }

      final isStudent = isStudentRow(
        name: nameVal,
        lrn: lrnVal,
        scores: scores,
        hasHighFillLrnColumn: hasHighFillLrn,
      );

      if (isStudent) {
        dataRows.add(row);
        originalRowIndices.add(displayRow);
      } else {
        // Exclude with specific reason
        String reason = 'Divider / Subtotal row';
        final upper = nameVal.toUpperCase();
        if (upper == 'MALE') {
          reason = 'Section Divider (MALE)';
        } else if (upper.startsWith('BOYS')) {
          reason = 'Section Divider (BOYS)';
        } else if (upper == 'FEMALE') {
          reason = 'Section Divider (FEMALE)';
        } else if (upper.startsWith('GIRLS')) {
          reason = 'Section Divider (GIRLS)';
        } else if (upper.startsWith('TOTAL')) {
          reason = 'Summary Subtotal Row ($nameVal)';
        } else if (upper.contains('AVERAGE')) {
          reason = 'Summary Average Row';
        } else if (hasHighFillLrn && cleanLrn(lrnVal) == null) {
          reason = 'Non-student row (missing valid 12-digit LRN)';
        } else if (!isValidStudentName(nameVal)) {
          reason = 'Empty template row / Unused slot';
        }

        excludedRows.add(EcrExcludedRow(
          rowIndex: displayRow,
          rawText: nameVal.isEmpty ? 'Row $displayRow' : nameVal,
          reason: reason,
        ));
      }
    }

    final detectedWeights = detectWeights(rawGrid, headers);

    return EcrParseResult(
      filename: filename,
      sheetName: selectedSheetName,
      headers: headers,
      rawGrid: rawGrid,
      headerRowIndex: headerRowIndex,
      isStackedHeader: isStacked,
      dataRows: dataRows,
      originalRowIndices: originalRowIndices,
      hpsRowIndex: hpsRowIdx,
      rowHpsMap: rowHpsMap,
      excludedRows: excludedRows,
      availableSheets: availableSheets,
      detectedWeights: detectedWeights,
      detectedTransmutation: detectedTransmutation,
    );
  }

  static List<List<dynamic>> _detectAndSliceHorizontalQuarterGrid(
    List<List<dynamic>> grid,
    String? gradingPeriod,
  ) {
    if (grid.isEmpty || grid.first.length < 50) return grid;

    int maxCheckRows = grid.length < 4 ? grid.length : 4;
    int q1Start = -1;
    int q2Start = -1;
    int q3Start = -1;
    int q4Start = -1;
    int finalStart = -1;

    for (int r = 0; r < maxCheckRows; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        final val = grid[r][c]?.toString().toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
        if (val.isEmpty) continue;

        if (q1Start == -1 && (val.contains('WRITTEN WORKS') || val.contains('WW')) && c > 2) {
          q1Start = c;
        } else if (val.contains('SECOND GRADING') || val.contains('2ND GRADING')) {
          q2Start = c;
        } else if (val.contains('THIRD GRADING') || val.contains('3RD GRADING')) {
          q3Start = c;
        } else if (val.contains('FOURTH GRADING') || val.contains('4TH GRADING')) {
          q4Start = c;
        } else if (val.contains('FINAL GRADING') || val.contains('FINAL GRADE')) {
          finalStart = c;
        }
      }
    }

    if (q1Start == -1 || q2Start == -1) return grid;

    final commonColCount = q1Start;

    int targetQuarter = 1;
    if (gradingPeriod != null) {
      final pLower = gradingPeriod.toLowerCase();
      if (pLower.contains('2') || pLower.contains('second')) {
        targetQuarter = 2;
      } else if (pLower.contains('3') || pLower.contains('third')) {
        targetQuarter = 3;
      } else if (pLower.contains('4') || pLower.contains('fourth')) {
        targetQuarter = 4;
      }
    }

    int targetStart = q1Start;
    int targetEnd = q2Start - 1;

    if (targetQuarter == 2 && q2Start != -1) {
      int actualQ2Start = q2Start;
      for (int c = q2Start; c < (q3Start != -1 ? q3Start : grid.first.length); c++) {
        final v = grid[0][c]?.toString().toUpperCase() ?? '';
        if (v.contains('WRITTEN') || v.contains('WW')) {
          actualQ2Start = c;
          break;
        }
      }
      targetStart = actualQ2Start;
      targetEnd = (q3Start != -1) ? q3Start - 1 : (finalStart != -1 ? finalStart - 1 : grid.first.length - 1);
    } else if (targetQuarter == 3 && q3Start != -1) {
      int actualQ3Start = q3Start;
      for (int c = q3Start; c < (q4Start != -1 ? q4Start : grid.first.length); c++) {
        final v = grid[0][c]?.toString().toUpperCase() ?? '';
        if (v.contains('WRITTEN') || v.contains('WW')) {
          actualQ3Start = c;
          break;
        }
      }
      targetStart = actualQ3Start;
      targetEnd = (q4Start != -1) ? q4Start - 1 : (finalStart != -1 ? finalStart - 1 : grid.first.length - 1);
    } else if (targetQuarter == 4 && q4Start != -1) {
      int actualQ4Start = q4Start;
      for (int c = q4Start; c < (finalStart != -1 ? finalStart : grid.first.length); c++) {
        final v = grid[0][c]?.toString().toUpperCase() ?? '';
        if (v.contains('WRITTEN') || v.contains('WW')) {
          actualQ4Start = c;
          break;
        }
      }
      targetStart = actualQ4Start;
      targetEnd = (finalStart != -1) ? finalStart - 1 : grid.first.length - 1;
    }

    List<List<dynamic>> sliced = [];
    for (final row in grid) {
      List<dynamic> newRow = [];
      for (int c = 0; c < commonColCount && c < row.length; c++) {
        newRow.add(row[c]);
      }
      for (int c = targetStart; c <= targetEnd && c < row.length; c++) {
        newRow.add(row[c]);
      }
      sliced.add(newRow);
    }

    return sliced;
  }

  // ── CSV & EXCEL DECODERS ─────────────────────────────────────────────────

  List<List<dynamic>> _parseCsv(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }
    return csv.decoder.convert(content);
  }

  static Uint8List _sanitizeZipRels(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();
      bool modified = false;
      for (final file in archive.files) {
        if (file.name.endsWith('.rels') && file.content != null) {
          final contentBytes = file.content as List<int>;
          final contentStr = utf8.decode(contentBytes, allowMalformed: true);
          if (contentStr.contains('Target="/xl/')) {
            final fixedStr = contentStr.replaceAll('Target="/xl/', 'Target="');
            final fixedBytes = utf8.encode(fixedStr);
            newArchive.addFile(ArchiveFile(file.name, fixedBytes.length, fixedBytes));
            modified = true;
            continue;
          }
        }
        newArchive.addFile(file);
      }
      if (modified) {
        final encoded = ZipEncoder().encode(newArchive);
        if (encoded != null) {
          return Uint8List.fromList(encoded);
        }
      }
    } catch (_) {}
    return bytes;
  }

  _ParsedExcelData _parseExcelWithSheet(
    Uint8List bytes, {
    String? targetSheetName,
    String? gradingPeriod,
  }) {
    final sanitizedBytes = _sanitizeZipRels(bytes);
    final excel = Excel.decodeBytes(sanitizedBytes);
    final detectedTransmutation = detectTransmutationTable(excel);
    if (excel.tables.isEmpty) {
      return _ParsedExcelData(
        grid: [],
        sheetName: '',
        sheets: [],
        detectedTransmutation: detectedTransmutation,
      );
    }

    final allSheets = excel.tables.keys.toList();
    List<EcrSheetSummary> summaries = [];

    // Find best sheet
    String chosenSheet = allSheets.first;
    double highestScore = -1.0;

    for (final sName in allSheets) {
      final s = excel.tables[sName];
      if (s == null) continue;

      final rows = s.maxRows;
      final cols = s.maxColumns;
      final lower = sName.toLowerCase().trim();

      bool isNonCandidate = false;
      for (final kw in nonCandidateSheetKeywords) {
        if (lower.contains(kw)) {
          isNonCandidate = true;
          break;
        }
      }

      double score = 0.5;
      if (rows < 5 || cols < 3) {
        score = 0.0;
        isNonCandidate = true;
      }

      if (lower.contains('classrecord') || lower.contains('class record')) {
        score = 0.95;
      }

      if (gradingPeriod != null) {
        for (final kw in _getGradingPeriodKeywords(gradingPeriod)) {
          if (lower.contains(kw)) {
            score = 1.0;
            break;
          }
        }
      }

      if (!isNonCandidate && score > highestScore) {
        highestScore = score;
        chosenSheet = sName;
      }

      summaries.add(EcrSheetSummary(
        sheetName: sName,
        rowCount: rows,
        columnCount: cols,
        isCandidate: !isNonCandidate && score > 0.3,
        matchScore: score,
      ));
    }

    if (targetSheetName != null && excel.tables.containsKey(targetSheetName)) {
      chosenSheet = targetSheetName;
    }

    final sheet = excel.tables[chosenSheet];
    if (sheet == null || sheet.maxRows == 0) {
      return _ParsedExcelData(
        grid: [],
        sheetName: chosenSheet,
        sheets: summaries,
        detectedTransmutation: detectedTransmutation,
      );
    }

    List<List<dynamic>> rawGrid = [];

    final sheetRows = sheet.rows;
    final int maxCols = sheet.maxColumns;

    for (int r = 0; r < sheet.maxRows; r++) {
      List<dynamic> rowValues = [];
      final rowData = r < sheetRows.length ? sheetRows[r] : null;

      for (int c = 0; c < maxCols; c++) {
        dynamic val = '';
        if (rowData != null && c < rowData.length) {
          final cell = rowData[c];
          final rawVal = cell?.value;
          if (rawVal != null) {
            if (rawVal is SharedString) {
              val = rawVal.toString();
            } else if (rawVal is TextCellValue) {
              val = rawVal.value.toString();
            } else if (rawVal is IntCellValue) {
              val = rawVal.value;
            } else if (rawVal is DoubleCellValue) {
              val = rawVal.value;
            } else if (rawVal is FormulaCellValue) {
              val = _resolveFormulaReference(excel, rawVal.formula);
            } else if (rawVal is DateCellValue) {
              val = '${rawVal.year}-${rawVal.month}-${rawVal.day}';
            } else {
              val = rawVal.toString();
            }
          }
        }
        rowValues.add(val ?? '');
      }
      rawGrid.add(rowValues);
    }

    // Forward fill merged spans
    try {
      final spans = sheet.spannedItems;
      for (final span in spans) {
        final spanStr = span.toString();
        final parts = spanStr.split(':');
        if (parts.length == 2) {
          final startCoords = _cellAddressToColRow(parts[0]);
          final endCoords = _cellAddressToColRow(parts[1]);

          if (startCoords != null && endCoords != null) {
            final startRow = startCoords['row']!;
            final endRow = endCoords['row']!;
            final startCol = startCoords['col']!;
            final endCol = endCoords['col']!;

            dynamic topValue = '';
            if (startRow < rawGrid.length && startCol < rawGrid[startRow].length) {
              topValue = rawGrid[startRow][startCol];
            }

            if (topValue != null && topValue.toString().trim().isNotEmpty) {
              for (int r = startRow; r <= endRow && r < rawGrid.length; r++) {
                for (int c = startCol; c <= endCol && c < rawGrid[r].length; c++) {
                  if (rawGrid[r][c].toString().trim().isEmpty) {
                    rawGrid[r][c] = topValue;
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // Additional horizontal forward fill for parent category headers in rows 0..15
    _forwardFillHeaderMatrix(rawGrid);

    return _ParsedExcelData(
      grid: rawGrid,
      sheetName: chosenSheet,
      sheets: summaries,
      detectedTransmutation: detectedTransmutation,
    );
  }

  static dynamic _resolveFormulaReference(Excel excel, String formula, {int depth = 0}) {
    if (depth > 4) return formula;
    final trimmed = formula.trim();

    // Cross-sheet reference pattern: e.g. 'INPUT DATA'!B13 or ='INPUT DATA'!B13 or 'INPUT DATA'!$B$13 or INPUT DATA!B13
    if (trimmed.contains('!')) {
      final bangIdx = trimmed.indexOf('!');
      String targetSheetName = trimmed.substring(0, bangIdx).trim();
      String cellAddr = trimmed.substring(bangIdx + 1).trim();

      if (targetSheetName.startsWith('=')) {
        targetSheetName = targetSheetName.substring(1).trim();
      }
      targetSheetName = targetSheetName.replaceAll("'", '').replaceAll('"', '').trim();
      cellAddr = cellAddr.replaceAll(r'$', '').trim();

      Sheet? targetSheet = excel.tables[targetSheetName];
      if (targetSheet == null) {
        for (final k in excel.tables.keys) {
          if (k.trim().toLowerCase() == targetSheetName.toLowerCase()) {
            targetSheet = excel.tables[k];
            break;
          }
        }
      }

      if (targetSheet != null) {
        final coords = _cellAddressToColRow(cellAddr);
        if (coords != null && coords['row']! < targetSheet.maxRows && coords['col']! < targetSheet.maxColumns) {
          final targetCell = targetSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: coords['col']!, rowIndex: coords['row']!),
          );
          final rawVal = targetCell.value;
          if (rawVal != null) {
            if (rawVal is TextCellValue) return rawVal.value.toString().trim();
            if (rawVal is SharedString) return rawVal.toString().trim();
            if (rawVal is IntCellValue) return rawVal.value;
            if (rawVal is DoubleCellValue) return rawVal.value;
            if (rawVal is FormulaCellValue) {
              return _resolveFormulaReference(excel, rawVal.formula, depth: depth + 1);
            }
            return rawVal.toString().trim();
          }
          // The target cell in INPUT DATA is empty/blank!
          return '';
        }
        // Address is outside target sheet's dimensions (blank row in INPUT DATA)
        return '';
      }
    }

    // Do not return raw formula string as cell content
    if (trimmed.startsWith('=')) {
      return '';
    }

    return trimmed;
  }

  static Map<String, int>? _cellAddressToColRow(String addr) {
    final match = RegExp(r'^([A-Z]+)([0-9]+)$', caseSensitive: false).firstMatch(addr.trim());
    if (match == null) return null;

    final colStr = match.group(1)!.toUpperCase();
    final rowStr = match.group(2)!;

    int col = 0;
    for (int i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 64);
    }
    col -= 1;

    int row = (int.tryParse(rowStr) ?? 1) - 1;
    return {'col': col, 'row': row};
  }

  void _forwardFillHeaderMatrix(List<List<dynamic>> grid) {
    int maxCheck = grid.length < 15 ? grid.length : 15;
    for (int r = 0; r < maxCheck; r++) {
      String lastVal = '';
      for (int c = 0; c < grid[r].length; c++) {
        final current = grid[r][c].toString().trim();
        if (current.isNotEmpty) {
          lastVal = current;
        } else if (lastVal.isNotEmpty && _isCategoryHeader(lastVal)) {
          grid[r][c] = lastVal;
        }
      }
    }
  }

  bool _isCategoryHeader(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    if (t.contains('\n') || t.contains('quiz') || t.contains('seatwork') || t.contains('demonstration') || t.contains('assignment')) {
      return false;
    }
    return t.contains('written work') ||
        t.contains('performance task') ||
        t.contains('quarterly assessment') ||
        t.contains('examinations') ||
        t.contains('(ww)') ||
        t.contains('(pt)') ||
        t.contains('(qa)') ||
        t == 'ww' ||
        t == 'pt' ||
        t == 'qa';
  }

  _HeaderScanResult _detectHeaderRows(List<List<dynamic>> grid) {
    int bestRow = 0;
    int maxMatches = -1;
    int scanLimit = grid.length < 25 ? grid.length : 25;

    for (int r = 0; r < scanLimit; r++) {
      int score = 0;
      bool hasStudentColumn = false;
      bool hasIdColumn = false;

      for (final cell in grid[r]) {
        final cellStr = cell.toString().toLowerCase().trim();
        if (cellStr.isEmpty) continue;

        if (cellStr == 'name' ||
            cellStr == 'student' ||
            cellStr.contains('name of student') ||
            cellStr.contains('student name') ||
            cellStr.contains('learner') ||
            cellStr.contains('pangalan')) {
          hasStudentColumn = true;
          score += 15;
        }

        if (cellStr.contains('studno') ||
            cellStr.contains('student no') ||
            cellStr.contains('lrn') ||
            cellStr.contains('id no')) {
          hasIdColumn = true;
          score += 10;
        }

        for (final kw in headerKeywords) {
          if (cellStr == kw || cellStr.contains(kw)) {
            score += 1;
            break;
          }
        }
      }

      if (hasStudentColumn && hasIdColumn) {
        score += 20;
      }

      if (score > maxMatches) {
        maxMatches = score;
        bestRow = r;
      }
    }

    bool isStacked = false;
    List<String> finalHeaders = [];
    int effectiveHeaderRow = bestRow;

    List<dynamic>? parentRow;
    List<dynamic>? childRow;

    for (int r = bestRow - 1; r >= 0; r--) {
      if (_isCategoryRow(grid[r])) {
        parentRow = grid[r];
        childRow = grid[bestRow];
        effectiveHeaderRow = bestRow;
        break;
      }
    }

    if (parentRow == null && bestRow + 1 < grid.length && _isCategoryRow(grid[bestRow]) && _isSubHeaderRow(grid[bestRow + 1])) {
      parentRow = grid[bestRow];
      childRow = grid[bestRow + 1];
      effectiveHeaderRow = bestRow + 1;
    }

    if (parentRow != null && childRow != null) {
      isStacked = true;
      for (int c = 0; c < childRow.length; c++) {
        final topVal = parentRow[c].toString().trim();
        final subVal = childRow[c].toString().trim();

        if (subVal.toLowerCase() == 'quarterly grade' ||
            subVal.toLowerCase() == 'final grade' ||
            subVal.toLowerCase() == 'initial grade') {
          finalHeaders.add(subVal);
        } else if (topVal.isNotEmpty && subVal.isNotEmpty && topVal.toLowerCase() != subVal.toLowerCase()) {
          finalHeaders.add('$topVal - $subVal');
        } else if (subVal.isNotEmpty) {
          finalHeaders.add(subVal);
        } else if (topVal.isNotEmpty) {
          finalHeaders.add(topVal);
        } else {
          finalHeaders.add('Column ${c + 1}');
        }
      }
    } else {
      final row = grid[bestRow];
      for (int c = 0; c < row.length; c++) {
        final val = row[c].toString().trim();
        finalHeaders.add(val.isEmpty ? 'Column ${c + 1}' : val);
      }
    }

    return _HeaderScanResult(
      headerRowIndex: effectiveHeaderRow,
      isStackedHeader: isStacked,
      finalHeaders: finalHeaders,
    );
  }

  bool _isCategoryRow(List<dynamic> row) {
    int categoryCount = 0;
    for (final cell in row) {
      final raw = cell.toString();
      if (raw.contains('\n') || raw.toLowerCase().contains('seatwork') || raw.toLowerCase().contains('demonstration')) {
        continue;
      }
      final str = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      final strNoSpaces = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (str.contains('written work') ||
          strNoSpaces.contains('writtenworks') ||
          str.contains('performance task') ||
          strNoSpaces.contains('performancetasks') ||
          str.contains('quarterly assessment') ||
          strNoSpaces.contains('examinations') ||
          str.contains('(ww)') ||
          str.contains('(pt)') ||
          str.contains('(qa)')) {
        categoryCount++;
      }
    }
    return categoryCount >= 2;
  }

  bool _isSubHeaderRow(List<dynamic> row) {
    int subCount = 0;
    for (final cell in row) {
      final str = cell.toString().trim();
      if (str.isEmpty) continue;
      final lower = str.toLowerCase();
      if (RegExp(r'^\d+$').hasMatch(str) ||
          lower == 'total' ||
          lower == 'ps' ||
          lower == 'ws' ||
          lower == 'hps' ||
          lower.contains('grade')) {
        subCount++;
      }
    }
    return subCount >= 3;
  }
}

class _HeaderScanResult {
  final int headerRowIndex;
  final bool isStackedHeader;
  final List<String> finalHeaders;

  _HeaderScanResult({
    required this.headerRowIndex,
    required this.isStackedHeader,
    required this.finalHeaders,
  });
}

class _ParsedExcelData {
  final List<List<dynamic>> grid;
  final String sheetName;
  final List<EcrSheetSummary> sheets;
  final EcrTransmutationTable detectedTransmutation;

  _ParsedExcelData({
    required this.grid,
    required this.sheetName,
    required this.sheets,
    this.detectedTransmutation = const EcrTransmutationTable(
      description: 'DepEd Base-70',
      passingRawScore: 70.0,
      isDetected: false,
    ),
  });
}
