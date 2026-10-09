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
      'pangalan ng mag-aaral'
    ],
    'Last Name': ['last name', 'lastname', 'apelyido', 'surname'],
    'First Name': ['first name', 'firstname', 'given name', 'pangalan'],
    'Middle Initial': ['middle initial', 'mi', 'm.i.', 'gitnang inisyal'],
    'LRN': ['lrn', 'learner reference number', 'learner ref', 'ref no', 'id no', 'student id'],
    'Written Work': ['written work', 'written works', 'written', 'ww', 'quiz', 'pagsusulit', 'sw', 'seatwork'],
    'Performance Task': ['performance task', 'performance tasks', 'performance', 'pt', 'output', 'gawain', 'pet'],
    'Quarterly Assessment': [
      'quarterly assessment',
      'quarterly',
      'qa',
      'exam',
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
      'general average'
    ],
  };

  /// Default HPS values when HPS columns are not explicitly present in file
  double defaultWwHps;
  double defaultPtHps;
  double defaultQaHps;

  EcrMappingEngine({
    this.defaultWwHps = 100.0,
    this.defaultPtHps = 100.0,
    this.defaultQaHps = 100.0,
  });

  /// Run auto-detection heuristics over column headers with hierarchical block resolution
  List<EcrColumnMapping> autoDetectMappings({
    required List<String> headers,
    required List<List<dynamic>> previewRows,
    EcrMappingTemplate? savedTemplate,
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

        // Increment position counters only when an activity item was assigned
        if (target.label.startsWith('WW')) wwActivityIndex++;
        if (target.label.startsWith('PT')) ptActivityIndex++;
        if (target.label.startsWith('QA') && target != EcrTargetCategory.hpsQa) qaActivityIndex++;
      } else {
        // 3. Independent column resolution (Name, LRN, Final Grade, Split Names)
        final indepMatch = _evaluateIndependentColumn(headerLower);
        target = indepMatch.target;
        confidence = indepMatch.confidence;
        reasons.addAll(indepMatch.reasons);
      }

      // 4. Data profiling signal check on preview rows
      final profileResult = _profileColumnData(colIndex, target, previewRows);
      confidence = (confidence + profileResult.scoreModifier).clamp(0.0, 1.0);
      reasons.addAll(profileResult.notes);

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
    if (lower.contains('written') || lower.contains('ww') || lower.contains('pagsusulit')) {
      return 'WW';
    }
    if (lower.contains('performance') || lower.contains('pt') || lower.contains('gawain') || lower.contains('task')) {
      return 'PT';
    }
    if (lower.contains('quarterly assessment') ||
        lower.contains('quarter assessment') ||
        lower.contains('qa') ||
        lower.contains('periodical') ||
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
      reasons.add('Quarterly Assessment component score');
      return _RoleResolution(EcrTargetCategory.qa, 0.90, reasons);
    }

    if (detectedNumber <= 10) {
      final label = '$parentBlock$detectedNumber';
      final target = EcrTargetCategory.fromLabel(label);
      reasons.add('Mapped to $label by position in $parentBlock block');
      return _RoleResolution(target != EcrTargetCategory.ignore ? target : EcrTargetCategory.ww1, 0.90, reasons);
    } else {
      // OVERFLOW: Component exceeds standard 10 items
      reasons.add(
        'Warning: $parentBlock exceeds standard 10 items (Item $detectedNumber). Consider consolidating or mapping manually.',
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

    // Standalone "Total" outside any component block
    if (headerLower == 'total' || headerLower == 'grade') {
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

      // Check 12-digit integer
      if (RegExp(r'^\d{12}$').hasMatch(str)) {
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

  void _applyHpsFallbacks(List<EcrColumnMapping> mappings) {
    bool hasWwHps = mappings.any((m) => m.target == EcrTargetCategory.hpsWw || (m.detectedRowHps != null && m.target.component == 'WW'));
    bool hasPtHps = mappings.any((m) => m.target == EcrTargetCategory.hpsPt || (m.detectedRowHps != null && m.target.component == 'PT'));
    bool hasQaHps = mappings.any((m) => m.target == EcrTargetCategory.hpsQa || (m.detectedRowHps != null && m.target.component == 'QA'));

    for (final m in mappings) {
      if (m.target.component == 'WW' && !m.target.isHps && !hasWwHps) {
        m.assumedHps = true;
        m.customHps ??= defaultWwHps;
      }
      if (m.target.component == 'PT' && !m.target.isHps && !hasPtHps) {
        m.assumedHps = true;
        m.customHps ??= defaultPtHps;
      }
      if (m.target.component == 'QA' && !m.target.isHps && !hasQaHps) {
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
