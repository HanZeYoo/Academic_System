import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'add_teacher_screen.dart';
import 'teacher_detail_screen.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    final teachers = await DatabaseHelper().getTeachers();
    setState(() {
      _teachers = teachers;
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
                'Teacher List',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddTeacherScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadTeachers();
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Teacher'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1664C5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people,
                  iconBgColor: const Color(0xFFCBEAFB),
                  iconColor: const Color(0xFF1664C5),
                  title: 'Total Teachers',
                  value: _isLoading ? '-' : _teachers.length.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.person_add,
                  iconBgColor: const Color(0xFFE2F6E7),
                  iconColor: const Color(0xFF00A364),
                  title: 'New Teachers',
                  value: '0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _teachers.isEmpty
                ? const Center(child: Text('No teachers found.'))
                : ListView.builder(
                    itemCount: _teachers.length,
                    itemBuilder: (context, index) {
                      final t = _teachers[index];
                      return _buildTeacherCard(context, t);
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
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
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

  Widget _buildTeacherCard(BuildContext context, Map<String, dynamic> teacher) {
    final name = teacher['name']?.toString() ?? 'Unknown';
    final id = 'ID: ${teacher['teacher_id']}';
    final department = teacher['department']?.toString() ?? 'No Department';
    final email = teacher['email']?.toString() ?? 'No email found';

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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  id,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  department,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_red_eye_outlined,
              color: Color(0xFF1664C5),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeacherDetailScreen(teacher: teacher),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1664C5)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddTeacherScreen(teacherToEdit: teacher),
                ),
              );
              if (result == true) {
                _loadTeachers();
              }
            },
          ),
        ],
      ),
    );
  }
}
