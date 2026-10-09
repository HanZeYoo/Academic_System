import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../models/ecr_mapping_model.dart';

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
    'do not delete',
    'guidelines',
    'instruction',
    'instructions',
    'transmutation',
    'settings',
    'config',
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
      if (RegExp(r'^\d{12}$').hasMatch(str)) {
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
    if (RegExp(r'^\d{12}$').hasMatch(sanitized)) {
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

  /// Tests whether a given row represents an actual student vs a divider or subtotal row.
  /// - If an LRN column exists with high fill rate, a valid 12-digit LRN is required.
  /// - Keyword blacklist (MALE, FEMALE, TOTAL, etc.) is checked first.
  /// - Subtotal rows with numeric sums are rejected.
  static bool isStudentRow({
    required String name,
    required String? lrn,
    required List<dynamic> scores,
    bool hasHighFillLrnColumn = false,
  }) {
    final trimmedName = name.trim();
    final upperName = trimmedName.toUpperCase();

    // 1. Divider and summary blacklist check
    if (trimmedName.isEmpty) return false;
    if (_isNonStudentLabel(upperName)) return false;

    // 2. High-fill LRN enforcement
    if (hasHighFillLrnColumn) {
      final validLrn = cleanLrn(lrn);
      if (validLrn == null) {
        // Name-only row under an active LRN column is treated as a divider or subtotal
        return false;
      }
    }

    // 3. Evidence check: must have either valid LRN or at least one numeric score
    final hasValidLrn = cleanLrn(lrn) != null;
    final hasScore = scores.any((s) {
      if (s == null) return false;
      if (s is num && s >= 0) return true;
      final p = double.tryParse(s.toString());
      return p != null && p >= 0;
    });

    return hasValidLrn || hasScore;
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
        upper.contains('SUMMARY') ||
        upper.contains('CLASS RECORD');
  }

  /// Finds a horizontal row containing "Highest Possible Score" or "HPS"
  /// and extracts per-column maximum scores.
  static Map<int, double> detectHpsRow(List<List<dynamic>> grid, int headerRowIndex) {
    final Map<int, double> hpsMap = {};

    // Scan up to 5 rows around/below the header row
    final scanEnd = (headerRowIndex + 5 < grid.length) ? headerRowIndex + 5 : grid.length;

    for (int r = headerRowIndex; r < scanEnd; r++) {
      final row = grid[r];
      bool isHpsRow = false;

      // Check first 4 columns for HPS keyword
      for (int c = 0; c < (row.length < 4 ? row.length : 4); c++) {
        final cellStr = row[c]?.toString().toUpperCase().trim() ?? '';
        if (cellStr.contains('HIGHEST POSSIBLE SCORE') || cellStr == 'HPS') {
          isHpsRow = true;
          break;
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

  /// Parses file bytes into grid, resolves merged spans, extracts HPS row, and filters student rows.
  Future<EcrParseResult> parseFile(
    Uint8List bytes,
    String filename, {
    String? targetSheetName,
    String? gradingPeriod,
  }) async {
    final lowerName = filename.toLowerCase();
    List<List<dynamic>> rawGrid = [];
    String selectedSheetName = filename;
    List<EcrSheetSummary> availableSheets = [];

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
        rawGrid = parsedExcel.grid;
        selectedSheetName = parsedExcel.sheetName;
        availableSheets = parsedExcel.sheets;
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
    for (int r = headerRowIndex; r < (headerRowIndex + 5 < rawGrid.length ? headerRowIndex + 5 : rawGrid.length); r++) {
      for (int c = 0; c < (rawGrid[r].length < 4 ? rawGrid[r].length : 4); c++) {
        final str = rawGrid[r][c]?.toString().toUpperCase().trim() ?? '';
        if (str.contains('HIGHEST POSSIBLE SCORE') || str == 'HPS') {
          hpsRowIdx = r;
          break;
        }
      }
      if (hpsRowIdx != null) break;
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

    // Check if LRN column has high fill rate in the grid
    bool hasHighFillLrn = false;
    if (lrnColIndex != -1) {
      int nonBlankLrn = 0;
      int checkedRows = 0;
      final start = (hpsRowIdx != null) ? hpsRowIdx + 1 : headerRowIndex + 1;
      for (int r = start; r < rawGrid.length && checkedRows < 30; r++) {
        final row = rawGrid[r];
        if (row.any((cell) => cell != null && cell.toString().trim().isNotEmpty)) {
          checkedRows++;
          if (lrnColIndex < row.length && cleanLrn(row[lrnColIndex]) != null) {
            nonBlankLrn++;
          }
        }
      }
      hasHighFillLrn = checkedRows > 0 && (nonBlankLrn / checkedRows) > 0.40;
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
      // Fallback check col 0 or 2 if nameVal is blank
      if (nameVal.isEmpty && row.isNotEmpty) {
        final c0 = row[0]?.toString().trim() ?? '';
        final c2 = (row.length > 2) ? row[2]?.toString().trim() ?? '' : '';
        if (RegExp(r'[A-Za-z]').hasMatch(c2)) {
          nameVal = c2;
        } else if (RegExp(r'[A-Za-z]').hasMatch(c0)) {
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
        } else if (upper == 'FEMALE') {
          reason = 'Section Divider (FEMALE)';
        } else if (upper.startsWith('TOTAL')) {
          reason = 'Summary Subtotal Row ($nameVal)';
        } else if (upper.contains('AVERAGE')) {
          reason = 'Summary Average Row';
        } else if (hasHighFillLrn && cleanLrn(lrnVal) == null) {
          reason = 'Non-student row (missing valid 12-digit LRN)';
        }

        excludedRows.add(EcrExcludedRow(
          rowIndex: displayRow,
          rawText: nameVal.isEmpty ? 'Row $displayRow' : nameVal,
          reason: reason,
        ));
      }
    }

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
    );
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

  _ParsedExcelData _parseExcelWithSheet(
    Uint8List bytes, {
    String? targetSheetName,
    String? gradingPeriod,
  }) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return _ParsedExcelData(grid: [], sheetName: '', sheets: []);
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
      return _ParsedExcelData(grid: [], sheetName: chosenSheet, sheets: summaries);
    }

    List<List<dynamic>> rawGrid = [];

    for (int r = 0; r < sheet.maxRows; r++) {
      List<dynamic> rowValues = [];
      for (int c = 0; c < sheet.maxColumns; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        dynamic val = cell.value;
        if (val != null && val is SharedString) {
          val = val.toString();
        } else if (val != null && val is TextCellValue) {
          val = val.value.toString();
        } else if (val != null && val is IntCellValue) {
          val = val.value;
        } else if (val != null && val is DoubleCellValue) {
          val = val.value;
        } else if (val != null && val is FormulaCellValue) {
          val = val.formula;
        } else if (val != null && val is DateCellValue) {
          val = '${val.year}-${val.month}-${val.day}';
        } else if (val != null) {
          val = val.toString();
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

    return _ParsedExcelData(grid: rawGrid, sheetName: chosenSheet, sheets: summaries);
  }

  Map<String, int>? _cellAddressToColRow(String addr) {
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
    final t = text.toLowerCase();
    return t.contains('written') ||
        t.contains('performance') ||
        t.contains('quarterly') ||
        t.contains('assessment') ||
        t.contains('task') ||
        t.contains('work');
  }

  _HeaderScanResult _detectHeaderRows(List<List<dynamic>> grid) {
    int bestRow = 0;
    int maxMatches = -1;
    int scanLimit = grid.length < 25 ? grid.length : 25;

    for (int r = 0; r < scanLimit; r++) {
      int score = 0;
      for (final cell in grid[r]) {
        final cellStr = cell.toString().toLowerCase().trim();
        if (cellStr.isEmpty) continue;

        for (final kw in headerKeywords) {
          if (cellStr == kw || cellStr.contains(kw)) {
            score += 1;
            break;
          }
        }
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

    if (bestRow > 0 && _isCategoryRow(grid[bestRow - 1])) {
      parentRow = grid[bestRow - 1];
      childRow = grid[bestRow];
      effectiveHeaderRow = bestRow;
    } else if (bestRow + 1 < grid.length && _isCategoryRow(grid[bestRow]) && _isSubHeaderRow(grid[bestRow + 1])) {
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
      final str = cell.toString().toLowerCase().trim();
      if (str.contains('written') ||
          str.contains('performance') ||
          str.contains('quarterly') ||
          str.contains('assessment') ||
          str.contains('task')) {
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

  _ParsedExcelData({
    required this.grid,
    required this.sheetName,
    required this.sheets,
  });
}
