import '../models/ecr_mapping_model.dart';

class EcrMappingEngine {
  /// Thresholds for mapping confidence
  static const double autoApplyThreshold = 0.85;
  static const double reviewThreshold = 0.60;

  /// Known aliases dictionary for auto-detect heuristic mapping
  static const Map<String, List<String>> _aliases = {
    'Student Name': [
      'name',
      'student',
      'learner name',
      'student name',
      'learner',
      'pangalan',
      'name of learner',
      'learners\' names',
      'learner\'s names',
      'pangalan ng mag-aaral',
      'name of student',
      'name of students',
      'name (lastname, firstname mi)',
      '(lastname, firstname, mi)',
    ],
    'Last Name': ['last name', 'lastname', 'apelyido', 'surname'],
    'First Name': ['first name', 'firstname', 'given name', 'pangalan'],
    'Middle Initial': ['middle initial', 'mi', 'm.i.', 'gitnang inisyal'],
    'LRN': [
      'lrn',
      'learner reference number',
      'learner ref',
      'ref no',
      'id no',
      'student id',
      'studno',
      'studno.',
      'stud no',
      'stud no.',
      'student no',
      'student no.',
      'student number',
    ],
    'Written Work': ['written work', 'written works', 'written', 'ww', 'quiz', 'pagsusulit', 'sw', 'seatwork'],
    'Performance Task': ['performance task', 'performance tasks', 'performance', 'pt', 'output', 'gawain', 'pet'],
    'Quarterly Assessment': [
      'quarterly assessment',
      'quarterly',
      'qa',
      'exam',
      'examinations',
      'examination',
      'summative test',
      'quarterly exam',
      'q1 exam',
      'q2 exam',
      'q3 exam',
      'q4 exam',
      'periodical',
      'markahan',
      'assessment'
    ],
    'HPS': ['hps', 'highest possible score', 'max score', 'total score'],
    'Total / Final Grade': [
      'final grade',
      'quarterly grade',
      'initial grade',
      'transmuted grade',
      'markahang marka',
      'general average',
      'periodic grade',
      'remarks',
    ],
  };

  /// Default HPS values when HPS columns are not explicitly present in file
  double defaultWwHps;
  double defaultPtHps;
  double defaultQaHps;

  EcrMappingEngine({
    this.defaultWwHps = 20.0,
    this.defaultPtHps = 50.0,
    this.defaultQaHps = 100.0,
  });

  /// Run auto-detection heuristics over column headers with hierarchical block resolution
  List<EcrColumnMapping> autoDetectMappings({
    required List<String> headers,
    required List<List<dynamic>> previewRows,
    EcrMappingTemplate? savedTemplate,
    Map<int, double>? rowHpsMap,
  }) {
    List<EcrColumnMapping> mappings = [];

    // Saved template lookup
    final Map<String, String>? templateMap = savedTemplate?.mappingJson;

    // 1. First pass: Identify Parent Component Blocks for each column
    final List<String?> parentBlocks = List.generate(headers.length, (i) => _detectParentBlock(headers[i]));

    // Track activity item counts per parent block to determine position-in-block
    int wwActivityIndex = 1;
    int ptActivityIndex = 1;
    int qaActivityIndex = 1;

    for (int colIndex = 0; colIndex < headers.length; colIndex++) {
      final rawHeader = headers[colIndex];
      final headerLower = rawHeader.toLowerCase().trim();
      final block = parentBlocks[colIndex];

      EcrTargetCategory target = EcrTargetCategory.ignore;
      double confidence = 0.0;
      List<String> reasons = [];
      String? parentBlock = block;

      // Check if saved template exists
      if (templateMap != null && templateMap.containsKey(rawHeader)) {
        final targetLabel = templateMap[rawHeader]!;
        target = EcrTargetCategory.fromLabel(targetLabel);
        confidence = 1.0;
        reasons.add('Matched saved teacher template for "$rawHeader"');

        // Prevent QA column collision if an old template mapped multiple columns to generic QA
        if (target.component == 'QA' && !target.isHps && block == 'QA') {
          if (target == EcrTargetCategory.qa && qaActivityIndex > 1) {
            target = _getQaTarget(qaActivityIndex);
            reasons.add('Auto-separated legacy template QA item to #$qaActivityIndex');
          }
        }
      } else if (block != null) {
        // 2. Hierarchical block resolution
        final blockMatch = _evaluateBlockColumnRole(
          header: rawHeader,
          headerLower: headerLower,
          parentBlock: block,
          activityIndex: block == 'WW'
              ? wwActivityIndex
              : block == 'PT'
                  ? ptActivityIndex
                  : qaActivityIndex,
        );

        target = blockMatch.target;
        confidence = blockMatch.confidence;
        reasons.addAll(blockMatch.reasons);
      } else {
        // 3. Independent column resolution (Name, LRN, Final Grade, Split Names)
        final indepMatch = _evaluateIndependentColumn(headerLower);
        target = indepMatch.target;
        confidence = indepMatch.confidence;
        reasons.addAll(indepMatch.reasons);
      }

      // Increment position counters only when an activity item was assigned
      if (target.label.startsWith('WW')) wwActivityIndex++;
      if (target.label.startsWith('PT')) ptActivityIndex++;
      if (target.label.startsWith('QA') && target != EcrTargetCategory.hpsQa) qaActivityIndex++;

      // 4. Data profiling signal check on preview rows
      final profileResult = _profileColumnData(colIndex, target, previewRows);
      confidence = (confidence + profileResult.scoreModifier).clamp(0.0, 1.0);
      reasons.addAll(profileResult.notes);

      // If column is ignore and has explicitly empty data in previewRows, treat as clean unused slot
      final bool isExplicitlyEmptyInPreview = previewRows.isNotEmpty &&
          !previewRows.any((row) =>
              colIndex < row.length &&
              row[colIndex] != null &&
              row[colIndex].toString().trim().isNotEmpty &&
              row[colIndex].toString().trim() != '0');
      if (target == EcrTargetCategory.ignore && isExplicitlyEmptyInPreview) {
        reasons.clear();
        reasons.add('Unused template slot');
        confidence = 0.80;
      }

      final hasWarning = reasons.any((r) => r.contains('Warning') || r.contains('exceeds'));
      final isLowConfidence = hasWarning || (confidence < reviewThreshold && target != EcrTargetCategory.ignore);

      mappings.add(EcrColumnMapping(
        columnIndex: colIndex,
        originalHeader: rawHeader,
        target: target,
        confidenceScore: confidence,
        isLowConfidence: isLowConfidence,
        hasTypeMismatch: profileResult.hasTypeMismatch,
        parentBlock: parentBlock,
        reasons: reasons,
        detectedRowHps: rowHpsMap?[colIndex],
      ));
    }

    // Flag missing HPS per component as assumed
    _applyHpsFallbacks(mappings);

    return mappings;
  }

  /// Detects whether a header belongs to WRITTEN WORKS, PERFORMANCE TASKS, or QUARTERLY ASSESSMENT
  String? _detectParentBlock(String header) {
    final lower = header.toLowerCase().trim();

    // Do NOT treat overall quarterly grade or final grade as QA parent block
    for (final gradeKw in _aliases['Total / Final Grade']!) {
      if (lower == gradeKw || lower.contains(gradeKw)) {
        return null;
      }
    }

    // Look for component indicators in stacked or standalone headers
    if (lower.contains('written') || lower.contains('ww') || lower.contains('pagsusulit') ||
        lower.contains('quiz') || lower.contains('seatwork') || lower.contains('assignment')) {
      return 'WW';
    }
    if (lower.contains('performance') || lower.contains('pt') || lower.contains('gawain') ||
        lower.contains('task') || lower.contains('activity') || lower.contains('project') || lower.contains('output')) {
      return 'PT';
    }
    final lowerNoSpaces = lower.replaceAll(' ', '');
    if (lower.contains('quarterly assessment') ||
        lower.contains('quarter assessment') ||
        lower.contains('qa') ||
        lower.contains('periodical') ||
        lower.contains('examinations') ||
        lower.contains('examination') ||
        lowerNoSpaces.contains('examinations') ||
        lower.contains('exam') ||
        lower.contains('summative test') ||
        lower.contains('markahan') ||
        (lower.contains('quarterly') && !lower.contains('grade')) ||
        (lower.contains('assessment') && !lower.contains('grade'))) {
      return 'QA';
    }
    return null;
  }

  /// Evaluates a column nested within a parent block (WW / PT / QA)
  _RoleResolution _evaluateBlockColumnRole({
    required String header,
    required String headerLower,
    required String parentBlock,
    required int activityIndex,
  }) {
    List<String> reasons = ['Nested within $parentBlock parent component block'];

    // Extract child token (e.g. from "WRITTEN WORKS - 1" or "WW1")
    String childToken = headerLower;
    if (headerLower.contains('-')) {
      final parts = headerLower.split('-');
      childToken = parts.last.trim();
    } else if (headerLower.contains(':')) {
      final parts = headerLower.split(':');
      childToken = parts.last.trim();
    }

    // A. Check for HPS inside block
    if (childToken.contains('hps') || childToken.contains('highest') || headerLower.contains('highest possible score')) {
      final hpsTarget = parentBlock == 'WW'
          ? EcrTargetCategory.hpsWw
          : parentBlock == 'PT'
              ? EcrTargetCategory.hpsPt
              : EcrTargetCategory.hpsQa;
      reasons.add('Identified as $parentBlock Highest Possible Score');
      return _RoleResolution(hpsTarget, 0.95, reasons);
    }

    // B. Check for DepEd Calculated / Percentage columns (PS, WS)
    if (childToken == 'ps' ||
        childToken == 'ws' ||
        childToken.contains('percentage') ||
        childToken.contains('percent score') ||
        childToken.contains('%age') ||
        childToken.contains('weighted') ||
        childToken.contains('weighted score')) {
      reasons.add('DepEd calculated formula column ($childToken) ignored from raw scores');
      return _RoleResolution(EcrTargetCategory.calculatedIgnore, 0.95, reasons);
    }

    // C. Check for Component Total (Must NEVER be mapped to totalGrade!)
    if (childToken == 'total' ||
        childToken == 'sum' ||
        childToken == 'kabuuan' ||
        childToken == 'kabuuang marka' ||
        childToken == 'total score') {
      reasons.add('Component total for $parentBlock (check column, not raw score)');
      return _RoleResolution(EcrTargetCategory.componentTotal, 0.95, reasons);
    }

    // D. Check for Activity Number or Label (e.g. "1", "2", "Quiz 1", "Activity 3")
    int detectedNumber = activityIndex;

    // Check if child token contains an explicit number
    final numMatch = RegExp(r'\b(\d+)\b').firstMatch(childToken);
    if (numMatch != null) {
      final parsedNum = int.tryParse(numMatch.group(1)!);
      if (parsedNum != null && parsedNum > 0) {
        detectedNumber = parsedNum;
      }
    }

    // E. Map to component activity enum or handle overflow
    if (parentBlock == 'QA') {
      reasons.add('Quarterly Assessment component score #$detectedNumber');
      final target = _getQaTarget(detectedNumber);
      return _RoleResolution(target, 0.90, reasons);
    }

    if (detectedNumber <= 20) {
      final label = '$parentBlock$detectedNumber';
      final target = EcrTargetCategory.fromLabel(label);
      if (detectedNumber > 10) {
        reasons.add(
          'Warning: $parentBlock exceeds standard 10 items (Item $detectedNumber)',
        );
        return _RoleResolution(target != EcrTargetCategory.ignore ? target : EcrTargetCategory.ww1, 0.65, reasons);
      }
      reasons.add('Mapped to $label by position in $parentBlock block');
      return _RoleResolution(target != EcrTargetCategory.ignore ? target : EcrTargetCategory.ww1, 0.90, reasons);
    } else {
      reasons.add(
        'Warning: $parentBlock exceeds maximum 20 items (Item $detectedNumber). Consider consolidating or mapping manually.',
      );
      return _RoleResolution(EcrTargetCategory.ignore, 0.50, reasons);
    }
  }
  /// Evaluates independent columns outside any component block
  _RoleResolution _evaluateIndependentColumn(String headerLower) {
    if (headerLower.isEmpty) {
      return _RoleResolution(EcrTargetCategory.ignore, 0.0, ['Empty column header']);
    }

    // Pass 1: Exact alias matches take highest priority
    for (final kw in _aliases['LRN']!) {
      if (headerLower == kw) {
        return _RoleResolution(EcrTargetCategory.lrn, 1.0, ['Exact LRN alias match']);
      }
    }
    for (final kw in _aliases['Student Name']!) {
      if (headerLower == kw) {
        return _RoleResolution(EcrTargetCategory.studentName, 1.0, ['Exact Student Name alias match']);
      }
    }
    for (final kw in _aliases['Last Name']!) {
      if (headerLower == kw) {
        return _RoleResolution(EcrTargetCategory.lastName, 1.0, ['Exact Last Name alias match']);
      }
    }
    for (final kw in _aliases['First Name']!) {
      if (headerLower == kw) {
        return _RoleResolution(EcrTargetCategory.firstName, 1.0, ['Exact First Name alias match']);
      }
    }
    for (final kw in _aliases['Middle Initial']!) {
      if (headerLower == kw) {
        return _RoleResolution(EcrTargetCategory.middleInitial, 1.0, ['Exact Middle Initial alias match']);
      }
    }
    for (final kw in _aliases['Total / Final Grade']!) {
      if (headerLower == kw) {
        return _RoleResolution(EcrTargetCategory.totalGrade, 0.90, ['Exact Final Grade alias match']);
      }
    }

    // Pass 2: Prefix and partial keyword matches
    // Check Split Name: Last Name
    for (final kw in _aliases['Last Name']!) {
      if (headerLower.startsWith(kw)) {
        return _RoleResolution(EcrTargetCategory.lastName, 0.95, ['Matched Last Name alias']);
      }
    }

    // Check Split Name: First Name
    for (final kw in _aliases['First Name']!) {
      if (headerLower.startsWith(kw)) {
        return _RoleResolution(EcrTargetCategory.firstName, 0.95, ['Matched First Name alias']);
      }
    }

    // Check Split Name: Middle Initial
    for (final kw in _aliases['Middle Initial']!) {
      if (headerLower.startsWith(kw)) {
        return _RoleResolution(EcrTargetCategory.middleInitial, 0.95, ['Matched Middle Initial alias']);
      }
    }

    // Check LRN keyword
    for (final kw in _aliases['LRN']!) {
      if (headerLower.contains(kw)) {
        return _RoleResolution(EcrTargetCategory.lrn, 0.85, ['Matched LRN keyword']);
      }
    }

    // Check Full Student Name keyword
    for (final kw in _aliases['Student Name']!) {
      if (headerLower.contains(kw)) {
        return _RoleResolution(EcrTargetCategory.studentName, 0.85, ['Matched Student Name keyword']);
      }
    }

    // Check Overall Total / Final Grade keyword
    for (final kw in _aliases['Total / Final Grade']!) {
      if (headerLower.contains(kw)) {
        return _RoleResolution(EcrTargetCategory.totalGrade, 0.75, ['Matched Final Grade keyword']);
      }
    }

    // Check Gender / Sex columns
    if (headerLower == 'gender' || headerLower == 'sex' || headerLower == 'kasarian') {
      return _RoleResolution(EcrTargetCategory.ignore, 0.90, ['Student Gender metadata column (Ignored for grading)']);
    }

    // Check Standalone Written Work columns (e.g. "WW1", "Quiz 1", "SW 2", "Seatwork 3", "Pagsusulit 1")
    final wwMatch = RegExp(r'^(?:ww|quiz|sw|seatwork|pagsusulit|written(?: work)?)\s*[-_:]?\s*(\d+)$').firstMatch(headerLower);
    if (wwMatch != null) {
      final num = int.tryParse(wwMatch.group(1)!) ?? 1;
      if (num >= 1 && num <= 20) {
        final target = EcrTargetCategory.fromLabel('WW$num');
        return _RoleResolution(target, 0.92, ['Adaptive match: Standalone Written Work activity item $num']);
      }
    }
    if (headerLower == 'ww' || headerLower == 'quiz' || headerLower == 'seatwork' || headerLower == 'written work') {
      return _RoleResolution(EcrTargetCategory.ww1, 0.85, ['Adaptive match: Standalone Written Work column']);
    }

    // Check Standalone Performance Task columns (e.g. "PT1", "Activity 1", "Act 2", "Project 3", "Output 1", "Task 4")
    final ptMatch = RegExp(r'^(?:pt|act|activity|task|output|project|gawain|performance(?: task)?)\s*[-_:]?\s*(\d+)$').firstMatch(headerLower);
    if (ptMatch != null) {
      final num = int.tryParse(ptMatch.group(1)!) ?? 1;
      if (num >= 1 && num <= 20) {
        final target = EcrTargetCategory.fromLabel('PT$num');
        return _RoleResolution(target, 0.92, ['Adaptive match: Standalone Performance Task activity item $num']);
      }
    }
    if (headerLower == 'pt' || headerLower == 'activity' || headerLower == 'act' || headerLower == 'performance task' || headerLower == 'project') {
      return _RoleResolution(EcrTargetCategory.pt1, 0.85, ['Adaptive match: Standalone Performance Task column']);
    }

    // Check Standalone Quarterly Assessment / Exam columns
    final qaMatch = RegExp(r'^(?:qa|exam|quarterly(?: exam)?|periodical(?: exam)?|term exam)\s*[-_:]?\s*(\d+)$').firstMatch(headerLower);
    if (qaMatch != null) {
      final num = int.tryParse(qaMatch.group(1)!) ?? 1;
      if (num >= 1 && num <= 10) {
        final target = _getQaTarget(num);
        return _RoleResolution(target, 0.92, ['Adaptive match: Standalone Quarterly Assessment activity item $num']);
      }
    }

    if (headerLower == 'qa' ||
        headerLower == 'exam' ||
        headerLower == 'quarterly assessment' ||
        headerLower == 'periodical' ||
        headerLower == 'periodical exam' ||
        headerLower == 'quarterly exam' ||
        headerLower == 'term exam' ||
        headerLower == 'markahang pagsusulit' ||
        headerLower.contains('periodical') ||
        headerLower.contains('quarterly exam')) {
      return _RoleResolution(EcrTargetCategory.qa, 0.92, ['Adaptive match: Quarterly Assessment / Periodical Exam']);
    }

    // Standalone "Total" outside any component block
    if (headerLower == 'total' || headerLower == 'grade' || headerLower == 'general average') {
      return _RoleResolution(EcrTargetCategory.totalGrade, 0.70, ['Standalone Total outside component block']);
    }

    return _RoleResolution(EcrTargetCategory.ignore, 0.0, ['Unrecognized header']);
  }

  /// Profiles data cells in preview rows to boost confidence or flag type mismatches
  _ProfileResult _profileColumnData(
    int colIndex,
    EcrTargetCategory target,
    List<List<dynamic>> previewRows,
  ) {
    if (previewRows.isEmpty) {
      return _ProfileResult(scoreModifier: 0.0, hasTypeMismatch: false, notes: []);
    }

    int numericCount = 0;
    int twelveDigitCount = 0;
    int formulaCount = 0;
    int nonEmptyCount = 0;
    bool hasTypeMismatch = false;
    List<String> notes = [];

    for (final row in previewRows) {
      if (colIndex >= row.length) continue;
      final val = row[colIndex];
      if (val == null) continue;

      final str = val.toString().trim();
      if (str.isEmpty) continue;

      nonEmptyCount++;

      // Check if formula
      if (str.startsWith('=')) {
        formulaCount++;
      }

      // Check 12-digit LRN or 9-digit NEU Student ID (with or without dashes)
      final clean = str.replaceAll(RegExp(r'[\s\-]'), '');
      if (RegExp(r'^\d{12}$').hasMatch(clean) || RegExp(r'^\d{9}$').hasMatch(clean) || RegExp(r'^\d{2}-\d{4}-\d{3}$').hasMatch(str)) {
        twelveDigitCount++;
      }

      // Check numeric score
      final numVal = double.tryParse(str);
      if (numVal != null) {
        numericCount++;
      } else if (target.isNumeric && !str.startsWith('=')) {
        hasTypeMismatch = true;
      }
    }

    double modifier = 0.0;

    // Profile LRN
    if (target == EcrTargetCategory.lrn && nonEmptyCount > 0) {
      if ((twelveDigitCount / nonEmptyCount) >= 0.80) {
        modifier += 0.10;
        notes.add('Data profile confirmed 12-digit LRN pattern');
      }
    }

    // Profile Student Name
    if (target == EcrTargetCategory.studentName && nonEmptyCount > 0) {
      if (numericCount == 0) {
        modifier += 0.05;
        notes.add('Data profile confirmed textual student names');
      }
    }

    // Profile Scores
    if (target.isNumeric && nonEmptyCount > 0) {
      if ((numericCount / nonEmptyCount) >= 0.80) {
        modifier += 0.05;
        notes.add('Data profile confirmed numeric score values');
      } else if (hasTypeMismatch) {
        modifier -= 0.20;
        notes.add('Warning: Non-numeric values found in numeric score column');
      }
    }

    // Renormalize formula-only columns (e.g. calculated totals)
    if (nonEmptyCount > 0 && (formulaCount / nonEmptyCount) >= 0.80) {
      notes.add('Column contains spreadsheet formula references');
    }

    return _ProfileResult(
      scoreModifier: modifier,
      hasTypeMismatch: hasTypeMismatch,
      notes: notes,
    );
  }

  EcrTargetCategory _getQaTarget(int number) {
    switch (number) {
      case 1:
        return EcrTargetCategory.qa;
      case 2:
        return EcrTargetCategory.qa2;
      case 3:
        return EcrTargetCategory.qa3;
      case 4:
        return EcrTargetCategory.qa4;
      case 5:
        return EcrTargetCategory.qa5;
      case 6:
        return EcrTargetCategory.qa6;
      case 7:
        return EcrTargetCategory.qa7;
      case 8:
        return EcrTargetCategory.qa8;
      case 9:
        return EcrTargetCategory.qa9;
      case 10:
        return EcrTargetCategory.qa10;
      default:
        return EcrTargetCategory.qa;
    }
  }

  void _applyHpsFallbacks(List<EcrColumnMapping> mappings) {
    for (final m in mappings) {
      if (m.detectedRowHps != null && m.detectedRowHps! > 0) {
        m.assumedHps = false;
        continue;
      }
      if (m.target.component == 'WW' && !m.target.isHps) {
        m.assumedHps = true;
        m.customHps ??= defaultWwHps;
      }
      if (m.target.component == 'PT' && !m.target.isHps) {
        m.assumedHps = true;
        m.customHps ??= defaultPtHps;
      }
      if (m.target.component == 'QA' && !m.target.isHps) {
        m.assumedHps = true;
        m.customHps ??= defaultQaHps;
      }
    }
  }
}

class _RoleResolution {
  final EcrTargetCategory target;
  final double confidence;
  final List<String> reasons;

  _RoleResolution(this.target, this.confidence, this.reasons);
}

class _ProfileResult {
  final double scoreModifier;
  final bool hasTypeMismatch;
  final List<String> notes;

  _ProfileResult({
    required this.scoreModifier,
    required this.hasTypeMismatch,
    required this.notes,
  });
}
