import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final students = await DatabaseHelper().getStudents();
    setState(() {
      _students = students;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search, color: Colors.black87),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 24),

          // Title and Add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Student List',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddStudentScreen()),
                  );
                  if (result == true) {
                    _loadStudents();
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1664C5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people,
                  iconBgColor: const Color(0xFFCBEAFB),
                  iconColor: const Color(0xFF1664C5),
                  title: 'Total Students',
                  value: _isLoading ? '-' : _students.length.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.person_add,
                  iconBgColor: const Color(0xFFE2F6E7),
                  iconColor: const Color(0xFF00A364),
                  title: 'New Students',
                  value: '0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.people_outline, size: 64, color: Colors.black26),
                            SizedBox(height: 12),
                            Text('No students yet.', style: TextStyle(color: Colors.black45)),
                            Text('Tap "Add Student" to get started.', style: TextStyle(color: Colors.black38, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final s = _students[index];
                          return _buildStudentCard(context, s);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 24,
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, Map<String, dynamic> student) {
    final name = student['name'] ?? 'Unknown';
    final id = 'ID: ${student['student_id']}';
    final section = '${student['grade_level']} - ${student['section']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Color(0xFFD9D9D9), radius: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(id, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(section, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF1664C5)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentDetailScreen(student: student),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1664C5)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
