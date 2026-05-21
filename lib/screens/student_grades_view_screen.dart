import 'package:flutter/material.dart';
import '../database_helper.dart';

class StudentGradesViewScreen extends StatefulWidget {
  final String username;
  const StudentGradesViewScreen({super.key, required this.username});

  @override
  State<StudentGradesViewScreen> createState() => _StudentGradesViewScreenState();
}

class _StudentGradesViewScreenState extends State<StudentGradesViewScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _scores = [];

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final db = DatabaseHelper();
    final scores = await db.getStudentAllScores(widget.username);
    
    if (mounted) {
      setState(() {
        _scores = scores;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group scores by subject_code
    final Map<String, List<Map<String, dynamic>>> groupedScores = {};
    for (var score in _scores) {
      final subjectCode = score['subject_code'] ?? 'Unknown Subject';
      groupedScores.putIfAbsent(subjectCode, () => []).add(score);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E66B4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.grade, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(
                'My Grades',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E66B4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (groupedScores.isEmpty)
            const Center(
              child: Text(
                'No grades recorded yet.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ...groupedScores.keys.map((subjectCode) => _buildSubjectScores(subjectCode, groupedScores[subjectCode]!)),
        ],
      ),
    );
  }

  Widget _buildSubjectScores(String subjectCode, List<Map<String, dynamic>> subjectScores) {
    final subjectName = subjectScores.isNotEmpty ? subjectScores.first['subject_name'] ?? '' : '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            '$subjectCode - $subjectName',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF224A60)),
          ),
          children: subjectScores.map((score) {
            final category = score['category'] ?? '';
            final itemLabel = score['item_label'] ?? '';
            final points = score['score']?.toString() ?? '0';
            final total = score['total_score']?.toString() ?? '0';
            final period = score['grading_period'] ?? '';
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$category - $itemLabel',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Period: $period',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E66B4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$points / $total',
                      style: const TextStyle(
                        color: Color(0xFF1E66B4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
