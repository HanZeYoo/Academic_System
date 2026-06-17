import 'package:flutter/material.dart';
import '../database_helper.dart';

class AdminArchiveScreen extends StatefulWidget {
  const AdminArchiveScreen({super.key});

  @override
  State<AdminArchiveScreen> createState() => _AdminArchiveScreenState();
}

class _AdminArchiveScreenState extends State<AdminArchiveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> _archivedTeachers = [];
  List<Map<String, dynamic>> _archivedStudents = [];
  List<Map<String, dynamic>> _archivedSubjects = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper();
    final teachers = await db.getArchivedTeachers();
    final students = await db.getArchivedStudents();
    final subjects = await db.getArchivedSubjectClasses();

    if (mounted) {
      setState(() {
        _archivedTeachers = teachers;
        _archivedStudents = students;
        _archivedSubjects = subjects;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreTeacher(int id, String name) async {
    await DatabaseHelper().restoreTeacher(id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name restored successfully.')));
    _loadArchives();
  }

  Future<void> _restoreStudent(int id, String name) async {
    await DatabaseHelper().restoreStudent(id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name restored successfully.')));
    _loadArchives();
  }

  Future<void> _restoreSubject(int id, String name) async {
    await DatabaseHelper().restoreSubjectClass(id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name restored successfully.')));
    _loadArchives();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFCBEAFB),
      child: Column(
        children: [
          Container(
            color: const Color(0xFF2B81B7),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'Teachers'),
                Tab(text: 'Students'),
                Tab(text: 'Subjects'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_archivedTeachers, 'Teacher', Icons.person_off, (item) {
                        _restoreTeacher(item['id'], item['name'] ?? 'Unknown');
                      }),
                      _buildList(_archivedStudents, 'Student', Icons.people_outline, (item) {
                        _restoreStudent(item['id'], item['name'] ?? 'Unknown');
                      }),
                      _buildList(_archivedSubjects, 'Subject', Icons.book_outlined, (item) {
                        _restoreSubject(item['id'], item['subject_name'] ?? 'Unknown');
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String type, IconData emptyIcon, Function(Map<String, dynamic>) onRestore) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No archived $type records found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final String name = type == 'Subject' ? (item['subject_name'] ?? 'Unknown') : (item['name'] ?? 'Unknown');
        final String subtitle = type == 'Subject' ? (item['subject_code'] ?? '') : (type == 'Teacher' ? item['teacher_id'] : item['student_id']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: Icon(type == 'Subject' ? Icons.book : Icons.person, color: Colors.grey.shade600),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF224A60))),
            subtitle: Text('ID/Code: $subtitle'),
            trailing: ElevatedButton.icon(
              onPressed: () => onRestore(item),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Restore'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1664C5),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
