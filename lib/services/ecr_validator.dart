import '../models/ecr_mapping_model.dart';

class EcrValidator {
  /// Validates full matrix dataset against mapped column targets
  EcrValidationSummary validateFullDataset({
    required List<List<dynamic>> dataRows,
    required List<EcrColumnMapping> mappings,
  }) {
    List<EcrValidationError> errors = [];
    int errorRowCount = 0;

    final studentNameMapping = mappings.where((m) => m.target == EcrTargetCategory.studentName).firstOrNull;
    final lrnMapping = mappings.where((m) => m.target == EcrTargetCategory.lrn).firstOrNull;

    if (studentNameMapping == null && lrnMapping == null) {
      errors.add(EcrValidationError(
        rowIndex: 0,
        columnIndex: 0,
        columnName: 'Mapping Error',
        message: 'At least one column must be mapped to Student Name or LRN.',
      ));
      return EcrValidationSummary(
        totalRows: dataRows.length,
        validRows: 0,
        errorRows: dataRows.length,
        errors: errors,
      );
    }

    final numericMappings = mappings.where((m) => m.target.isNumeric && m.target != EcrTargetCategory.ignore).toList();

    for (int r = 0; r < dataRows.length; r++) {
      final row = dataRows[r];
      final displayRowIndex = r + 1; // 1-indexed for display
      bool rowHasError = false;

      // Validate Student Name / LRN presence
      String studentNameVal = '';
      String lrnVal = '';

      if (studentNameMapping != null && studentNameMapping.columnIndex < row.length) {
        studentNameVal = row[studentNameMapping.columnIndex]?.toString().trim() ?? '';
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

      // Validate numeric score columns
      for (final m in numericMappings) {
        if (m.columnIndex >= row.length) continue;

        final valStr = row[m.columnIndex]?.toString().trim() ?? '';
        if (valStr.isEmpty) continue; // Allow blank score (treated as 0 or unsubmitted)

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
        } else if (m.customHps != null && parsed > m.customHps!) {
          errors.add(EcrValidationError(
            rowIndex: displayRowIndex,
            columnIndex: m.columnIndex,
            columnName: m.originalHeader,
            message: 'Row $displayRowIndex ("$studentNameVal"): Score "$valStr" exceeds total HPS (${m.customHps}).',
            isWarning: true,
          ));
        }
      }

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
}
