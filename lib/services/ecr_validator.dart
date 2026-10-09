import '../models/ecr_mapping_model.dart';

class EcrValidator {
  /// Validates full matrix dataset against mapped column targets, checks HPS limits,
  /// detects in-file duplicates, and cross-checks component totals.
  EcrValidationSummary validateFullDataset({
    required List<List<dynamic>> dataRows,
    required List<EcrColumnMapping> mappings,
  }) {
    List<EcrValidationError> errors = [];
    int errorRowCount = 0;

    final studentNameMapping = mappings.where((m) => m.target == EcrTargetCategory.studentName).firstOrNull;
    final lrnMapping = mappings.where((m) => m.target == EcrTargetCategory.lrn).firstOrNull;
    final lastNameMapping = mappings.where((m) => m.target == EcrTargetCategory.lastName).firstOrNull;
    final firstNameMapping = mappings.where((m) => m.target == EcrTargetCategory.firstName).firstOrNull;

    final hasStudentIdentifier = studentNameMapping != null ||
        lrnMapping != null ||
        (lastNameMapping != null && firstNameMapping != null);

    if (!hasStudentIdentifier) {
      errors.add(EcrValidationError(
        rowIndex: 0,
        columnIndex: 0,
        columnName: 'Mapping Error',
        message: 'At least one column must be mapped to Student Name, LRN, or Split Names (Last Name + First Name).',
      ));
      return EcrValidationSummary(
        totalRows: dataRows.length,
        validRows: 0,
        errorRows: dataRows.length,
        errors: errors,
      );
    }

    final numericMappings = mappings.where((m) =>
        m.target.isNumeric &&
        !m.target.isHps &&
        m.target != EcrTargetCategory.ignore &&
        m.target != EcrTargetCategory.calculatedIgnore).toList();

    // In-file duplicate trackers
    final Map<String, int> seenLrns = {};
    final Map<String, int> seenNames = {};

    // Group item mappings by parent component block for total cross-check
    final wwItemMappings = mappings.where((m) => m.target.component == 'WW' && !m.target.isHps && m.target != EcrTargetCategory.componentTotal).toList();
    final ptItemMappings = mappings.where((m) => m.target.component == 'PT' && !m.target.isHps && m.target != EcrTargetCategory.componentTotal).toList();
    final wwTotalMapping = mappings.where((m) => m.target == EcrTargetCategory.componentTotal && m.parentBlock == 'WW').firstOrNull;
    final ptTotalMapping = mappings.where((m) => m.target == EcrTargetCategory.componentTotal && m.parentBlock == 'PT').firstOrNull;

    for (int r = 0; r < dataRows.length; r++) {
      final row = dataRows[r];
      final displayRowIndex = r + 1; // 1-indexed for display
      bool rowHasError = false;

      // Validate Student Name / LRN presence
      String studentNameVal = '';
      String lrnVal = '';

      if (studentNameMapping != null && studentNameMapping.columnIndex < row.length) {
        studentNameVal = row[studentNameMapping.columnIndex]?.toString().trim() ?? '';
      } else if (lastNameMapping != null && lastNameMapping.columnIndex < row.length) {
        final last = row[lastNameMapping.columnIndex]?.toString().trim() ?? '';
        final first = (firstNameMapping != null && firstNameMapping.columnIndex < row.length)
            ? row[firstNameMapping.columnIndex]?.toString().trim() ?? ''
            : '';
        studentNameVal = '$last, $first'.trim();
      }

      if (lrnMapping != null && lrnMapping.columnIndex < row.length) {
        lrnVal = row[lrnMapping.columnIndex]?.toString().trim() ?? '';
      }

      if (studentNameVal.isEmpty && lrnVal.isEmpty) {
        errors.add(EcrValidationError(
          rowIndex: displayRowIndex,
          columnIndex: studentNameMapping?.columnIndex ?? lrnMapping?.columnIndex ?? 0,
          columnName: studentNameMapping?.originalHeader ?? lrnMapping?.originalHeader ?? 'Student',
          message: 'Row $displayRowIndex: Missing both Student Name and LRN.',
        ));
        rowHasError = true;
      }

      // Check In-File Duplicate LRN
      if (lrnVal.isNotEmpty) {
        if (seenLrns.containsKey(lrnVal)) {
          errors.add(EcrValidationError(
            rowIndex: displayRowIndex,
            columnIndex: lrnMapping?.columnIndex ?? 0,
            columnName: lrnMapping?.originalHeader ?? 'LRN',
            message: 'Row $displayRowIndex: Duplicate LRN "$lrnVal" already appeared in Row ${seenLrns[lrnVal]}.',
            isWarning: true,
          ));
        } else {
          seenLrns[lrnVal] = displayRowIndex;
        }
      }

      // Check In-File Duplicate Student Name
      if (studentNameVal.isNotEmpty) {
        final normalizedName = normalizeFuzzyName(studentNameVal);
        if (seenNames.containsKey(normalizedName)) {
          errors.add(EcrValidationError(
            rowIndex: displayRowIndex,
            columnIndex: studentNameMapping?.columnIndex ?? 0,
            columnName: studentNameMapping?.originalHeader ?? 'Student Name',
            message: 'Row $displayRowIndex: Duplicate Student Name "$studentNameVal" matches Row ${seenNames[normalizedName]}.',
            isWarning: true,
          ));
        } else {
          seenNames[normalizedName] = displayRowIndex;
        }
      }

      // Validate numeric score columns & Score > HPS checks
      for (final m in numericMappings) {
        if (m.columnIndex >= row.length) continue;

        final valStr = row[m.columnIndex]?.toString().trim() ?? '';
        if (valStr.isEmpty) continue; // Blank score is allowed (unsubmitted / zero)

        // Formulas cannot be read directly in excel 4.0.6 (handled gracefully)
        if (valStr.startsWith('=')) continue;

        final parsed = double.tryParse(valStr);
        if (parsed == null) {
          errors.add(EcrValidationError(
            rowIndex: displayRowIndex,
            columnIndex: m.columnIndex,
            columnName: m.originalHeader,
            message: 'Row $displayRowIndex ("$studentNameVal"): Non-numeric score "$valStr" in column "${m.originalHeader}".',
          ));
          rowHasError = true;
        } else if (parsed < 0) {
          errors.add(EcrValidationError(
            rowIndex: displayRowIndex,
            columnIndex: m.columnIndex,
            columnName: m.originalHeader,
            message: 'Row $displayRowIndex ("$studentNameVal"): Negative score "$valStr" in column "${m.originalHeader}".',
          ));
          rowHasError = true;
        } else {
          // Score > HPS validation check
          final effectiveHps = m.detectedRowHps ?? m.customHps;
          if (effectiveHps != null && parsed > effectiveHps) {
            errors.add(EcrValidationError(
              rowIndex: displayRowIndex,
              columnIndex: m.columnIndex,
              columnName: m.originalHeader,
              message: 'Row $displayRowIndex ("$studentNameVal"): Score "$valStr" exceeds HPS (${effectiveHps.toInt()}) in column "${m.originalHeader}".',
              isWarning: true,
            ));
          }
        }
      }

      // Cross-check Component Totals (WW & PT)
      _crossCheckComponentTotal(
        row: row,
        displayRowIndex: displayRowIndex,
        studentName: studentNameVal,
        componentLabel: 'WW',
        itemMappings: wwItemMappings,
        totalMapping: wwTotalMapping,
        errors: errors,
      );

      _crossCheckComponentTotal(
        row: row,
        displayRowIndex: displayRowIndex,
        studentName: studentNameVal,
        componentLabel: 'PT',
        itemMappings: ptItemMappings,
        totalMapping: ptTotalMapping,
        errors: errors,
      );

      if (rowHasError) {
        errorRowCount++;
      }
    }

    final validRows = dataRows.length - errorRowCount;

    return EcrValidationSummary(
      totalRows: dataRows.length,
      validRows: validRows < 0 ? 0 : validRows,
      errorRows: errorRowCount,
      errors: errors,
    );
  }

  /// Cross-checks sum of raw items against component total column if present
  void _crossCheckComponentTotal({
    required List<dynamic> row,
    required int displayRowIndex,
    required String studentName,
    required String componentLabel,
    required List<EcrColumnMapping> itemMappings,
    required EcrColumnMapping? totalMapping,
    required List<EcrValidationError> errors,
  }) {
    if (totalMapping == null || totalMapping.columnIndex >= row.length) return;

    final reportedValStr = row[totalMapping.columnIndex]?.toString().trim() ?? '';
    if (reportedValStr.isEmpty || reportedValStr.startsWith('=')) return; // Formula or empty cell

    final reportedTotal = double.tryParse(reportedValStr);
    if (reportedTotal == null) return;

    double computedSum = 0.0;
    bool hasAnyScore = false;

    for (final m in itemMappings) {
      if (m.columnIndex >= row.length) continue;
      final valStr = row[m.columnIndex]?.toString().trim() ?? '';
      if (valStr.isEmpty || valStr.startsWith('=')) continue;
      final numVal = double.tryParse(valStr);
      if (numVal != null) {
        computedSum += numVal;
        hasAnyScore = true;
      }
    }

    if (hasAnyScore && (computedSum - reportedTotal).abs() > 0.05) {
      errors.add(EcrValidationError(
        rowIndex: displayRowIndex,
        columnIndex: totalMapping.columnIndex,
        columnName: totalMapping.originalHeader,
        message: 'Row $displayRowIndex ("$studentName"): $componentLabel computed items sum ($computedSum) does not match reported total ($reportedTotal).',
        isWarning: true,
      ));
    }
  }

  /// Normalizes a name string for fuzzy comparison (case-insensitive, trims, strips punctuation)
  static String normalizeFuzzyName(String name) {
    String clean = name.toLowerCase()
        .replaceAll(RegExp(r'[,.\-_]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Sort name parts so "Dela Cruz, Juan" matches "Juan Dela Cruz"
    final tokens = clean.split(' ').where((t) => t.isNotEmpty).toList();
    tokens.sort();
    return tokens.join(' ');
  }

  /// Reconciles parsed students in ECR file against official section roster from database
  EcrRosterMatchResult reconcileWithRoster({
    required List<List<dynamic>> dataRows,
    required List<EcrColumnMapping> mappings,
    required List<Map<String, dynamic>> enrolledStudents,
  }) {
    final lrnMapping = mappings.where((m) => m.target == EcrTargetCategory.lrn).firstOrNull;
    final nameMapping = mappings.where((m) => m.target == EcrTargetCategory.studentName).firstOrNull;
    final lastNameMapping = mappings.where((m) => m.target == EcrTargetCategory.lastName).firstOrNull;
    final firstNameMapping = mappings.where((m) => m.target == EcrTargetCategory.firstName).firstOrNull;

    // Index enrolled students by LRN and normalized name
    final Map<String, Map<String, dynamic>> enrolledByLrn = {};
    final Map<String, Map<String, dynamic>> enrolledByName = {};

    for (final s in enrolledStudents) {
      final sLrn = s['student_id']?.toString().trim();
      final sName = s['name']?.toString().trim() ?? '';
      if (sLrn != null && sLrn.isNotEmpty) {
        enrolledByLrn[sLrn] = s;
      }
      if (sName.isNotEmpty) {
        enrolledByName[normalizeFuzzyName(sName)] = s;
      }
    }

    int matchedCount = 0;
    int unmatchedCount = 0;
    int duplicateCount = 0;
    List<String> unmatchedNames = [];
    List<String> duplicateNames = [];
    final Set<String> matchedEnrolledIds = {};

    for (final row in dataRows) {
      String rowLrn = '';
      String rowName = '';

      if (lrnMapping != null && lrnMapping.columnIndex < row.length) {
        rowLrn = row[lrnMapping.columnIndex]?.toString().trim() ?? '';
      }

      if (nameMapping != null && nameMapping.columnIndex < row.length) {
        rowName = row[nameMapping.columnIndex]?.toString().trim() ?? '';
      } else if (lastNameMapping != null && lastNameMapping.columnIndex < row.length) {
        final last = row[lastNameMapping.columnIndex]?.toString().trim() ?? '';
        final first = (firstNameMapping != null && firstNameMapping.columnIndex < row.length)
            ? row[firstNameMapping.columnIndex]?.toString().trim() ?? ''
            : '';
        rowName = '$last, $first'.trim();
      }

      Map<String, dynamic>? match;

      // 1. Primary match by LRN
      if (rowLrn.isNotEmpty && enrolledByLrn.containsKey(rowLrn)) {
        match = enrolledByLrn[rowLrn];
      }

      // 2. Secondary fuzzy match by Name
      if (match == null && rowName.isNotEmpty) {
        final norm = normalizeFuzzyName(rowName);
        if (enrolledByName.containsKey(norm)) {
          match = enrolledByName[norm];
        }
      }

      if (match != null) {
        final studentId = match['student_id']?.toString() ?? '';
        if (matchedEnrolledIds.contains(studentId)) {
          duplicateCount++;
          duplicateNames.add(rowName.isNotEmpty ? rowName : (rowLrn.isNotEmpty ? 'LRN: $rowLrn' : 'Student $studentId'));
        } else {
          matchedEnrolledIds.add(studentId);
          matchedCount++;
        }
      } else {
        unmatchedCount++;
        unmatchedNames.add(rowName.isNotEmpty ? rowName : (rowLrn.isNotEmpty ? 'LRN: $rowLrn' : 'Unknown Student'));
      }
    }

    final totalRows = dataRows.length;
    final matchRate = totalRows > 0 ? (matchedCount / totalRows) : 0.0;

    return EcrRosterMatchResult(
      totalSheetStudents: totalRows,
      matchedCount: matchedCount,
      unmatchedCount: unmatchedCount,
      duplicateCount: duplicateCount,
      unmatchedNames: unmatchedNames,
      duplicateNames: duplicateNames,
      matchRate: matchRate,
    );
  }
}
