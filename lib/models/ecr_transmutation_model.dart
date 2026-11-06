import 'dart:convert';

/// Represents a detected or configured ECR transmutation table and scale
class EcrTransmutationTable {
  final String sheetName;
  final String description;
  final double passingRawScore;
  final double minRawScore;
  final double minGrade;
  final double passingGrade;
  final double maxGrade;
  final Map<double, int> brackets; // sorted: minRawThreshold -> grade
  final bool isDetected;

  const EcrTransmutationTable({
    this.sheetName = '',
    this.description = 'DepEd Base-70',
    this.passingRawScore = 70.0,
    this.minRawScore = 0.0,
    this.minGrade = 60.0,
    this.passingGrade = 75.0,
    this.maxGrade = 100.0,
    this.brackets = const {},
    this.isDetected = false,
  });

  /// Approximate VLOOKUP logic matching Excel
  int lookup(double rawScore) {
    if (brackets.isEmpty) {
      if (rawScore >= 100) return maxGrade.toInt();
      if (rawScore <= 0) return minGrade.toInt();
      if (rawScore >= passingRawScore) {
        final transmuted = passingGrade +
            ((rawScore - passingRawScore) / (100.0 - passingRawScore)) *
                (maxGrade - passingGrade);
        return transmuted.round();
      } else {
        final transmuted = minGrade +
            (rawScore / passingRawScore) * (passingGrade - minGrade);
        final rounded = transmuted.round();
        return rounded >= passingGrade ? (passingGrade - 1).toInt() : rounded;
      }
    }

    if (rawScore < brackets.keys.first) {
      return brackets.values.first;
    }

    int result = brackets.values.first;
    for (final entry in brackets.entries) {
      if (rawScore >= entry.key) {
        result = entry.value;
      } else {
        break;
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'sheetName': sheetName,
    'description': description,
    'passingRawScore': passingRawScore,
    'minRawScore': minRawScore,
    'minGrade': minGrade,
    'passingGrade': passingGrade,
    'maxGrade': maxGrade,
    'brackets': brackets.map((k, v) => MapEntry(k.toString(), v)),
    'isDetected': isDetected,
  };

  factory EcrTransmutationTable.fromJson(Map<String, dynamic> json) {
    final rawBrackets = json['brackets'];
    final Map<double, int> b = {};
    if (rawBrackets is Map) {
      rawBrackets.forEach((k, v) {
        final d = double.tryParse(k.toString());
        final i = int.tryParse(v.toString());
        if (d != null && i != null) b[d] = i;
      });
    }
    return EcrTransmutationTable(
      sheetName: json['sheetName']?.toString() ?? '',
      description: json['description']?.toString() ?? 'DepEd Base-70',
      passingRawScore: (json['passingRawScore'] as num?)?.toDouble() ?? 70.0,
      minRawScore: (json['minRawScore'] as num?)?.toDouble() ?? 0.0,
      minGrade: (json['minGrade'] as num?)?.toDouble() ?? 60.0,
      passingGrade: (json['passingGrade'] as num?)?.toDouble() ?? 75.0,
      maxGrade: (json['maxGrade'] as num?)?.toDouble() ?? 100.0,
      brackets: b,
      isDetected: json['isDetected'] == true,
    );
  }

  @override
  String toString() => '$description (${brackets.length} brackets)';
}

