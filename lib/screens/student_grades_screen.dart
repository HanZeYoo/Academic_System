import 'package:flutter/material.dart';

class StudentGradesScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentGradesScreen({super.key, required this.student});

  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  // Mock data for grades
  final List<Map<String, dynamic>> _subjects = [
    {'name': 'Mathematics', 'q1': '88', 'q2': '90', 'q3': '92', 'q4': '', 'final': '90', 'remarks': 'Passed'},
    {'name': 'Science', 'q1': '85', 'q2': '87', 'q3': '88', 'q4': '', 'final': '86.7', 'remarks': 'Passed'},
    {'name': 'English', 'q1': '92', 'q2': '91', 'q3': '93', 'q4': '', 'final': '92', 'remarks': 'Passed'},
    {'name': 'Filipino', 'q1': '89', 'q2': '88', 'q3': '89', 'q4': '', 'final': '88.7', 'remarks': 'Passed'},
    {'name': 'History', 'q1': '86', 'q2': '85', 'q3': '87', 'q4': '', 'final': '86', 'remarks': 'Passed'},
  ];

  @override
  Widget build(BuildContext context) {
    final student = widget.student;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F52BA),
        elevation: 0,
        title: const Text('Academic Grades', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        'ID: ${student['student_id'] ?? 'N/A'}',
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
          
          // Grades List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                return _buildSubjectGradeCard(subject);
              },
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
                    const SnackBar(content: Text('Grades saved successfully!'), backgroundColor: Colors.green),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text(
                  'Update Grades',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildSubjectGradeCard(Map<String, dynamic> subject) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subject['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F52BA),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: subject['remarks'] == 'Passed' ? const Color(0xFFE8F5E9) : const Color(0xFFFEF2E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    subject['remarks'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: subject['remarks'] == 'Passed' ? const Color(0xFF198754) : const Color(0xFFE67E22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Grades Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildGradeInput('Q1', subject['q1'])),
                const SizedBox(width: 8),
                Expanded(child: _buildGradeInput('Q2', subject['q2'])),
                const SizedBox(width: 8),
                Expanded(child: _buildGradeInput('Q3', subject['q3'])),
                const SizedBox(width: 8),
                Expanded(child: _buildGradeInput('Q4', subject['q4'])),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Final',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject['final'].toString().isNotEmpty ? subject['final'] : '-',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeInput(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: value.isEmpty ? Colors.white : const Color(0xFFF8FAFC),
            border: Border.all(color: value.isEmpty ? Colors.blue.shade200 : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: value.isEmpty ? Colors.grey : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
