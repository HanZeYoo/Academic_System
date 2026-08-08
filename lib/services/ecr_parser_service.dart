import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

class EcrParseResult {
  final String filename;
  final List<String> headers;
  final List<List<dynamic>> rawGrid;
  final int headerRowIndex;
  final bool isStackedHeader;
  final List<List<dynamic>> dataRows;

  EcrParseResult({
    required this.filename,
    required this.headers,
    required this.rawGrid,
    required this.headerRowIndex,
    required this.isStackedHeader,
    required this.dataRows,
  });
}

class EcrParserService {
  /// Keywords used to evaluate candidate header row density
  static const List<String> headerKeywords = [
    'name',
    'student',
    'learner',
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
    'score/50',
    'score/100',
  ];

  /// Parses file bytes (.xlsx, .xls, or .csv) into a raw matrix, forward-fills merged cells,
  /// and detects single or stacked header rows.
  Future<EcrParseResult> parseFile(Uint8List bytes, String filename) async {
    final lowerName = filename.toLowerCase();
    List<List<dynamic>> rawGrid = [];

    if (lowerName.endsWith('.csv')) {
      rawGrid = _parseCsv(bytes);
    } else if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
      rawGrid = _parseExcel(bytes);
    } else {
      throw FormatException('Unsupported file format. Please upload .xlsx, .xls, or .csv');
    }

    if (rawGrid.isEmpty) {
      throw FormatException('Uploaded file is empty or could not be read.');
    }

    // Standardize all rows to equal length by padding empty strings
    int maxCols = 0;
    for (final row in rawGrid) {
      if (row.length > maxCols) maxCols = row.length;
    }
    for (int r = 0; r < rawGrid.length; r++) {
      while (rawGrid[r].length < maxCols) {
        rawGrid[r].add('');
      }
    }

    // Detect header row index
    final headerDetection = _detectHeaderRows(rawGrid);
    final headerRowIndex = headerDetection.headerRowIndex;
    final isStacked = headerDetection.isStackedHeader;
    final headers = headerDetection.finalHeaders;

    // Data rows are all non-empty rows following the header row(s)
    final startDataRow = isStacked ? headerRowIndex + 1 : headerRowIndex + 1;
    List<List<dynamic>> dataRows = [];
    for (int i = startDataRow; i < rawGrid.length; i++) {
      final row = rawGrid[i];
      // Skip completely blank rows
      final hasContent = row.any((cell) => cell != null && cell.toString().trim().isNotEmpty);
      if (hasContent) {
        dataRows.add(row);
      }
    }

    return EcrParseResult(
      filename: filename,
      headers: headers,
      rawGrid: rawGrid,
      headerRowIndex: headerRowIndex,
      isStackedHeader: isStacked,
      dataRows: dataRows,
    );
  }

  /// Parse CSV bytes into a 2D matrix
  List<List<dynamic>> _parseCsv(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    return csv.decoder.convert(content);
  }

  /// Parse Excel bytes, decode spanned/merged cells, and forward fill
  List<List<dynamic>> _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    // Pick first table/sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.maxRows == 0) return [];

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
        } else if (val != null && val is DateCellValue) {
          val = '${val.year}-${val.month}-${val.day}';
        } else if (val != null) {
          val = val.toString();
        }
        rowValues.add(val ?? '');
      }
      rawGrid.add(rowValues);
    }

    // Forward-fill merged cells using sheet.spannedItems if available
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

            // Get top-left cell value
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
    } catch (_) {
      // Fallback if spannedItems accessor varies
    }

    // Additional horizontal & vertical forward-fill pass for header region (rows 0..10)
    _forwardFillHeaderMatrix(rawGrid);

    return rawGrid;
  }

  /// Converts cell address string like 'A1' or 'AA12' to 0-indexed column and row
  Map<String, int>? _cellAddressToColRow(String addr) {
    final match = RegExp(r'^([A-Z]+)([0-9]+)$', caseSensitive: false).firstMatch(addr.trim());
    if (match == null) return null;

    final colStr = match.group(1)!.toUpperCase();
    final rowStr = match.group(2)!;

    int col = 0;
    for (int i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 64);
    }
    col -= 1; // 0-indexed

    int row = (int.tryParse(rowStr) ?? 1) - 1; // 0-indexed
    return {'col': col, 'row': row};
  }

  /// Forward-fill empty cells horizontally and vertically in top 10 header rows
  /// to handle merged headers where Excel package API span details are non-standard
  void _forwardFillHeaderMatrix(List<List<dynamic>> grid) {
    int maxCheck = grid.length < 10 ? grid.length : 10;

    // Horizontal forward-fill for category header spans
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

  /// Detects header row index by density scoring and checks for stacked headers
  _HeaderScanResult _detectHeaderRows(List<List<dynamic>> grid) {
    int bestRow = 0;
    int maxMatches = -1;

    int scanLimit = grid.length < 10 ? grid.length : 10;

    for (int r = 0; r < scanLimit; r++) {
      int score = 0;
      for (final cell in grid[r]) {
        final cellStr = cell.toString().toLowerCase().trim();
        if (cellStr.isEmpty) continue;

        for (final kw in headerKeywords) {
          if (cellStr == kw || cellStr.contains(kw)) {
            score += 1;
            break; // 1 point per matching cell
          }
        }
      }

      if (score > maxMatches) {
        maxMatches = score;
        bestRow = r;
      }
    }

    // Check if stacked header exists (the row immediately above has category names)
    bool isStacked = false;
    List<String> finalHeaders = [];

    if (bestRow > 0) {
      final prevRow = grid[bestRow - 1];
      final currRow = grid[bestRow];

      // Check if prevRow has category words like Written / Performance / QA
      int prevCategoryCount = 0;
      for (final cell in prevRow) {
        final str = cell.toString().toLowerCase();
        if (str.contains('written') ||
            str.contains('performance') ||
            str.contains('task') ||
            str.contains('assessment') ||
            str.contains('quarter')) {
          prevCategoryCount++;
        }
      }

      if (prevCategoryCount > 0) {
        isStacked = true;
        for (int c = 0; c < currRow.length; c++) {
          final topVal = prevRow[c].toString().trim();
          final subVal = currRow[c].toString().trim();

          if (topVal.isNotEmpty && subVal.isNotEmpty && topVal.toLowerCase() != subVal.toLowerCase()) {
            finalHeaders.add('$topVal - $subVal');
          } else if (subVal.isNotEmpty) {
            finalHeaders.add(subVal);
          } else {
            finalHeaders.add(topVal);
          }
        }
      }
    }

    if (!isStacked) {
      final row = grid[bestRow];
      for (int c = 0; c < row.length; c++) {
        final val = row[c].toString().trim();
        finalHeaders.add(val.isEmpty ? 'Column ${c + 1}' : val);
      }
    }

    return _HeaderScanResult(
      headerRowIndex: bestRow,
      isStackedHeader: isStacked,
      finalHeaders: finalHeaders,
    );
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
