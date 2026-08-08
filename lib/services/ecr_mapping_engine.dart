import '../models/ecr_mapping_model.dart';

class EcrMappingEngine {
  /// Known aliases dictionary for auto-detect heuristic mapping
  static const Map<String, List<String>> _aliases = {
    'Student Name': ['name', 'student', 'learner name', 'student name', 'learner', 'pangalan', 'name of learner'],
    'LRN': ['lrn', 'learner reference number', 'learner ref', 'ref no', 'id no', 'student id'],
    'Written Work': ['written work', 'written', 'ww', 'quiz', 'pagsusulit', 'ww1', 'ww2', 'ww3', 'ww4', 'ww5'],
    'Performance Task': ['performance task', 'performance', 'pt', 'output', 'gawain', 'pt1', 'pt2', 'pt3', 'pt4', 'pt5'],
    'Quarterly Assessment': ['quarterly assessment', 'quarterly', 'qa', 'exam', 'q1 exam', 'q2 exam', 'q3 exam', 'q4 exam', 'periodical', 'markahan'],
    'HPS': ['hps', 'highest possible score', 'max score', 'total score'],
    'Total / Final Grade': ['total', 'final grade', 'grade', 'raw score', 'initial grade', 'transmuted grade', 'final score'],
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

  /// Run auto-detection heuristics over column headers
  List<EcrColumnMapping> autoDetectMappings({
    required List<String> headers,
    required List<List<dynamic>> previewRows,
    EcrMappingTemplate? savedTemplate,
  }) {
    List<EcrColumnMapping> mappings = [];

    int wwCounter = 1;
    int ptCounter = 1;

    // Check if saved template exists for this teacher & subject
    final Map<String, String>? templateMap = savedTemplate?.mappingJson;

    for (int colIndex = 0; colIndex < headers.length; colIndex++) {
      final rawHeader = headers[colIndex];
      final headerLower = rawHeader.toLowerCase().trim();

      EcrTargetCategory target = EcrTargetCategory.ignore;
      double confidence = 0.0;
      bool isLowConfidence = false;

      // 1. If saved template has mapping for this header, use it with 100% confidence
      if (templateMap != null && templateMap.containsKey(rawHeader)) {
        final targetLabel = templateMap[rawHeader]!;
        target = EcrTargetCategory.fromLabel(targetLabel);
        confidence = 1.0;
      } else {
        // 2. Perform fuzzy heuristic detection
        final match = _evaluateHeaderHeuristic(headerLower, wwCounter, ptCounter);
        target = match.target;
        confidence = match.confidence;

        // Increment component counters when assigned
        if (target.label.startsWith('WW')) wwCounter++;
        if (target.label.startsWith('PT')) ptCounter++;

        if (confidence < 0.70 && target != EcrTargetCategory.ignore) {
          isLowConfidence = true;
        }
      }

      // Check if preview rows have non-numeric data for numeric target column
      bool typeMismatch = false;
      if (target.isNumeric) {
        for (final row in previewRows) {
          if (colIndex < row.length) {
            final valStr = row[colIndex]?.toString().trim() ?? '';
            if (valStr.isNotEmpty && double.tryParse(valStr) == null) {
              typeMismatch = true;
              break;
            }
          }
        }
      }

      mappings.add(EcrColumnMapping(
        columnIndex: colIndex,
        originalHeader: rawHeader,
        target: target,
        confidenceScore: confidence,
        isLowConfidence: isLowConfidence,
        hasTypeMismatch: typeMismatch,
      ));
    }

    // Flag missing HPS per component as assumed
    _applyHpsFallbacks(mappings);

    return mappings;
  }

  /// Score header string against alias keywords
  _HeuristicMatch _evaluateHeaderHeuristic(String headerLower, int wwCount, int ptCount) {
    if (headerLower.isEmpty) {
      return _HeuristicMatch(EcrTargetCategory.ignore, 0.0);
    }

    // Check Student Name
    for (final kw in _aliases['Student Name']!) {
      if (headerLower == kw) return _HeuristicMatch(EcrTargetCategory.studentName, 1.0);
      if (headerLower.contains(kw)) return _HeuristicMatch(EcrTargetCategory.studentName, 0.85);
    }

    // Check LRN
    for (final kw in _aliases['LRN']!) {
      if (headerLower == kw) return _HeuristicMatch(EcrTargetCategory.lrn, 1.0);
      if (headerLower.contains(kw)) return _HeuristicMatch(EcrTargetCategory.lrn, 0.85);
    }

    // Check HPS
    for (final kw in _aliases['HPS']!) {
      if (headerLower.contains(kw)) {
        if (headerLower.contains('written') || headerLower.contains('ww')) {
          return _HeuristicMatch(EcrTargetCategory.hpsWw, 0.90);
        } else if (headerLower.contains('performance') || headerLower.contains('pt')) {
          return _HeuristicMatch(EcrTargetCategory.hpsPt, 0.90);
        } else if (headerLower.contains('qa') || headerLower.contains('exam')) {
          return _HeuristicMatch(EcrTargetCategory.hpsQa, 0.90);
        }
        return _HeuristicMatch(EcrTargetCategory.hpsWw, 0.65);
      }
    }

    // Check Written Works (WW)
    for (final kw in _aliases['Written Work']!) {
      if (headerLower.contains(kw)) {
        final wwEnum = EcrTargetCategory.fromLabel('WW$wwCount');
        final score = headerLower == kw ? 0.95 : 0.75;
        return _HeuristicMatch(wwEnum != EcrTargetCategory.ignore ? wwEnum : EcrTargetCategory.ww1, score);
      }
    }

    // Check Performance Tasks (PT)
    for (final kw in _aliases['Performance Task']!) {
      if (headerLower.contains(kw)) {
        final ptEnum = EcrTargetCategory.fromLabel('PT$ptCount');
        final score = headerLower == kw ? 0.95 : 0.75;
        return _HeuristicMatch(ptEnum != EcrTargetCategory.ignore ? ptEnum : EcrTargetCategory.pt1, score);
      }
    }

    // Check Quarterly Assessment (QA)
    for (final kw in _aliases['Quarterly Assessment']!) {
      if (headerLower.contains(kw)) {
        return _HeuristicMatch(EcrTargetCategory.qa, 0.85);
      }
    }

    // Check Total / Final Grade
    for (final kw in _aliases['Total / Final Grade']!) {
      if (headerLower == kw) return _HeuristicMatch(EcrTargetCategory.totalGrade, 0.90);
      if (headerLower.contains(kw)) return _HeuristicMatch(EcrTargetCategory.totalGrade, 0.75);
    }

    return _HeuristicMatch(EcrTargetCategory.ignore, 0.0);
  }

  void _applyHpsFallbacks(List<EcrColumnMapping> mappings) {
    bool hasWwHps = mappings.any((m) => m.target == EcrTargetCategory.hpsWw);
    bool hasPtHps = mappings.any((m) => m.target == EcrTargetCategory.hpsPt);
    bool hasQaHps = mappings.any((m) => m.target == EcrTargetCategory.hpsQa);

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

class _HeuristicMatch {
  final EcrTargetCategory target;
  final double confidence;

  _HeuristicMatch(this.target, this.confidence);
}
