import 'dart:convert';

/// Represents available target categories for ECR grade components
enum EcrTargetCategory {
  studentName('Student Name', isNumeric: false),
  lrn('LRN', isNumeric: false),
  ww1('WW1', isNumeric: true, component: 'WW'),
  ww2('WW2', isNumeric: true, component: 'WW'),
  ww3('WW3', isNumeric: true, component: 'WW'),
  ww4('WW4', isNumeric: true, component: 'WW'),
  ww5('WW5', isNumeric: true, component: 'WW'),
  ww6('WW6', isNumeric: true, component: 'WW'),
  ww7('WW7', isNumeric: true, component: 'WW'),
  ww8('WW8', isNumeric: true, component: 'WW'),
  ww9('WW9', isNumeric: true, component: 'WW'),
  ww10('WW10', isNumeric: true, component: 'WW'),
  pt1('PT1', isNumeric: true, component: 'PT'),
  pt2('PT2', isNumeric: true, component: 'PT'),
  pt3('PT3', isNumeric: true, component: 'PT'),
  pt4('PT4', isNumeric: true, component: 'PT'),
  pt5('PT5', isNumeric: true, component: 'PT'),
  pt6('PT6', isNumeric: true, component: 'PT'),
  pt7('PT7', isNumeric: true, component: 'PT'),
  pt8('PT8', isNumeric: true, component: 'PT'),
  pt9('PT9', isNumeric: true, component: 'PT'),
  pt10('PT10', isNumeric: true, component: 'PT'),
  qa('QA', isNumeric: true, component: 'QA'),
  hpsWw('HPS (Written Work)', isNumeric: true, isHps: true, component: 'WW'),
  hpsPt('HPS (Performance Task)', isNumeric: true, isHps: true, component: 'PT'),
  hpsQa('HPS (Quarterly Assessment)', isNumeric: true, isHps: true, component: 'QA'),
  totalGrade('Total / Final Grade', isNumeric: true),
  ignore('Ignore Column', isNumeric: false);

  final String label;
  final bool isNumeric;
  final bool isHps;
  final String? component;

  const EcrTargetCategory(
    this.label, {
    required this.isNumeric,
    this.isHps = false,
    this.component,
  });

  static EcrTargetCategory fromLabel(String label) {
    return EcrTargetCategory.values.firstWhere(
      (e) => e.label == label,
      orElse: () => EcrTargetCategory.ignore,
    );
  }
}

/// Represents the auto-detected or manually updated mapping of a single spreadsheet column
class EcrColumnMapping {
  final int columnIndex;
  final String originalHeader;
  EcrTargetCategory target;
  double confidenceScore; // 0.0 to 1.0
  bool isLowConfidence; // confidence < 0.70
  bool hasTypeMismatch; // True if preview data has non-numeric in numeric column
  bool assumedHps; // True if HPS was not found in sheet and used default
  double? customHps; // Override total HPS for this component column

  EcrColumnMapping({
    required this.columnIndex,
    required this.originalHeader,
    required this.target,
    this.confidenceScore = 1.0,
    this.isLowConfidence = false,
    this.hasTypeMismatch = false,
    this.assumedHps = false,
    this.customHps,
  });

  Map<String, dynamic> toJson() => {
        'columnIndex': columnIndex,
        'originalHeader': originalHeader,
        'target': target.label,
        'confidenceScore': confidenceScore,
        'isLowConfidence': isLowConfidence,
        'hasTypeMismatch': hasTypeMismatch,
        'assumedHps': assumedHps,
        'customHps': customHps,
      };

  factory EcrColumnMapping.fromJson(Map<String, dynamic> json) => EcrColumnMapping(
        columnIndex: json['columnIndex'] ?? 0,
        originalHeader: json['originalHeader'] ?? '',
        target: EcrTargetCategory.fromLabel(json['target'] ?? 'Ignore Column'),
        confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 1.0,
        isLowConfidence: json['isLowConfidence'] ?? false,
        hasTypeMismatch: json['hasTypeMismatch'] ?? false,
        assumedHps: json['assumedHps'] ?? false,
        customHps: (json['customHps'] as num?)?.toDouble(),
      );
}

/// Represents a validation error/warning on a single data row
class EcrValidationError {
  final int rowIndex; // 1-indexed row number in original file
  final int columnIndex;
  final String columnName;
  final String message;
  final bool isWarning;

  EcrValidationError({
    required this.rowIndex,
    required this.columnIndex,
    required this.columnName,
    required this.message,
    this.isWarning = false,
  });
}

/// Summary of full dataset validation results before saving
class EcrValidationSummary {
  final int totalRows;
  final int validRows;
  final int errorRows;
  final List<EcrValidationError> errors;

  EcrValidationSummary({
    required this.totalRows,
    required this.validRows,
    required this.errorRows,
    required this.errors,
  });

  bool get hasErrors => errorRows > 0;
}

/// Saved Mapping Template for Teacher + Subject
class EcrMappingTemplate {
  final String? id;
  final String teacherId;
  final String subjectId;
  final Map<String, String> mappingJson; // originalHeader -> targetField label
  final String? createdAt;
  final String? updatedAt;

  EcrMappingTemplate({
    this.id,
    required this.teacherId,
    required this.subjectId,
    required this.mappingJson,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toSupabaseMap() => {
        if (id != null) 'id': id,
        'teacher_id': teacherId,
        'subject_id': subjectId,
        'mapping_json': jsonEncode(mappingJson),
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory EcrMappingTemplate.fromSupabaseMap(Map<String, dynamic> map) {
    Map<String, String> parsedMapping = {};
    final jsonStr = map['mapping_json'];
    if (jsonStr is String && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          parsedMapping = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    } else if (jsonStr is Map) {
      parsedMapping = jsonStr.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    return EcrMappingTemplate(
      id: map['id']?.toString(),
      teacherId: map['teacher_id']?.toString() ?? '',
      subjectId: map['subject_id']?.toString() ?? '',
      mappingJson: parsedMapping,
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}
