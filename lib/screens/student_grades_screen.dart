import 'package:flutter/material.dart';
import '../database_helper.dart';

class StudentGradesScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentGradesScreen({super.key, required this.student});

  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  bool _isLoading = true;
  List<String> _subjectList = [];
  Map<String, Map<String, String>> _gradesMap = {};

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    setState(() => _isLoading = true);

    final studentId = widget.student['student_id']?.toString() ?? '';
    if (studentId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final rawScores = await DatabaseHelper().getScoresByStudentId(studentId);

    // Group by subject_name -> grading_period
    Map<String, Map<String, Map<String, double>>> aggregator = {};

    for (var row in rawScores) {
      final subj = row['subject_name']?.toString() ?? 'Unknown Subject';
      final period = row['grading_period']?.toString() ?? '';
      final score = (row['score'] as num?)?.toDouble() ?? 0.0;
      final total = (row['total_score'] as num?)?.toDouble() ?? 0.0;

      String quarterKey = '';
      if (period.contains('1st')) quarterKey = 'Q1';
      else if (period.contains('2nd')) quarterKey = 'Q2';
      else if (period.contains('3rd')) quarterKey = 'Q3';
      else if (period.contains('4th')) quarterKey = 'Q4';

      if (quarterKey.isEmpty || total == 0) continue;

      aggregator.putIfAbsent(subj, () => {});
      aggregator[subj]!.putIfAbsent(quarterKey, () => {'score': 0.0, 'total': 0.0});

      aggregator[subj]![quarterKey]!['score'] = aggregator[subj]![quarterKey]!['score']! + score;
      aggregator[subj]![quarterKey]!['total'] = aggregator[subj]![quarterKey]!['total']! + total;
    }

    // Map to _gradesMap
    Map<String, Map<String, String>> finalGrades = {};
    for (var subj in aggregator.keys) {
      finalGrades[subj] = {'Q1': '', 'Q2': '', 'Q3': '', 'Q4': '', 'Final': '', 'Remarks': ''};
      double sumQ = 0;
      int countQ = 0;

      for (var q in ['Q1', 'Q2', 'Q3', 'Q4']) {
        if (aggregator[subj]!.containsKey(q)) {
          double s = aggregator[subj]![q]!['score']!;
          double t = aggregator[subj]![q]!['total']!;
          double grade = (s / t) * 100;
          finalGrades[subj]![q] = grade.toStringAsFixed(0); // Round to integer for cleaner look
          sumQ += grade;
          countQ++;
        }
      }

      if (countQ > 0) {
        double finalG = sumQ / countQ;
        finalGrades[subj]!['Final'] = finalG.toStringAsFixed(0);
        finalGrades[subj]!['Remarks'] = finalG >= 75 ? 'Passed' : 'Failed';
      }
    }

    setState(() {
      _subjectList = finalGrades.keys.toList()..sort();
      _gradesMap = finalGrades;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F52BA),
        elevation: 0,
        title: const Text('Report Card (SF9)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Student Info Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF0F52BA),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    (student['name']?.toString().isNotEmpty == true)
                        ? student['name'].toString()[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name']?.toString() ?? 'Unknown Student',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LRN: ${student['student_id'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student['grade_level'] ?? ''} - ${student['section'] ?? ''}'.trim().replaceAll(RegExp(r'^-\s*|\s*-$'), ''),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // Grades Data Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _subjectList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.assignment_outlined, size: 64, color: Colors.black26),
                            SizedBox(height: 12),
                            Text('No grades available yet.', style: TextStyle(color: Colors.black45)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFEFF6FF)),
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F52BA)))),
                                  DataColumn(label: Text('1', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F52BA)))),
                                  DataColumn(label: Text('2', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F52BA)))),
                                  DataColumn(label: Text('3', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F52BA)))),
                                  DataColumn(label: Text('4', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F52BA)))),
                                  DataColumn(label: Text('Final', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F52BA)))),
                                  DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F52BA)))),
                                ],
                                rows: _subjectList.map((subj) {
                                  final grades = _gradesMap[subj]!;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(subj, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                      DataCell(Text(grades['Q1']!.isEmpty ? '-' : grades['Q1']!)),
                                      DataCell(Text(grades['Q2']!.isEmpty ? '-' : grades['Q2']!)),
                                      DataCell(Text(grades['Q3']!.isEmpty ? '-' : grades['Q3']!)),
                                      DataCell(Text(grades['Q4']!.isEmpty ? '-' : grades['Q4']!)),
                                      DataCell(Text(grades['Final']!.isEmpty ? '-' : grades['Final']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(
                                        Text(
                                          grades['Remarks']!.isEmpty ? '-' : grades['Remarks']!,
                                          style: TextStyle(
                                            color: grades['Remarks'] == 'Passed' ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
          
          // Bottom Action
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Downloading SF9 Report Card...'), backgroundColor: Color(0xFF0F52BA)),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text(
                  'Download Report Card (SF9)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F52BA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
