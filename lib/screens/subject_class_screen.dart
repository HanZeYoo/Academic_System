import 'package:flutter/material.dart';
import 'add_subject_class_screen.dart';
import '../database_helper.dart';

class SubjectClassScreen extends StatefulWidget {
  const SubjectClassScreen({super.key});

  @override
  State<SubjectClassScreen> createState() => _SubjectClassScreenState();
}

class _SubjectClassScreenState extends State<SubjectClassScreen> {
  List<Map<String, dynamic>> _subjectClasses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjectClasses();
  }

  Future<void> _loadSubjectClasses() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper().getSubjectClasses();
    setState(() {
      _subjectClasses = data;
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
          const SizedBox(height: 20),
          
          // Title
          Row(
            children: const [
              Icon(Icons.layers, color: Color(0xFF1664C5)),
              SizedBox(width: 8),
              Text(
                'Subject & Class',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.menu_book,
                  iconBgColor: const Color(0xFFCBEAFB),
                  iconColor: const Color(0xFF1664C5),
                  title: 'Total Subjects',
                  value: _isLoading ? '-' : _subjectClasses.length.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.class_,
                  iconBgColor: const Color(0xFFE2F6E7),
                  iconColor: const Color(0xFF00A364),
                  title: 'Total Classes',
                  value: _isLoading ? '-' : _subjectClasses.length.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddSubjectClassScreen()),
                );
                if (result == true) {
                  _loadSubjectClasses();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1664C5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Add Subject / Class',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _subjectClasses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.class_outlined, size: 64, color: Colors.black26),
                            SizedBox(height: 12),
                            Text('No subjects or classes found.', style: TextStyle(color: Colors.black45)),
                            Text('Tap "Add Subject / Class" to create one.', style: TextStyle(color: Colors.black38, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _subjectClasses.length,
                        itemBuilder: (context, index) {
                          final item = _subjectClasses[index];
                          return _buildSubjectClassCard(
                            item['subject_name'] ?? 'Unknown Subject',
                            'Code: ${item['subject_code']} | Section: ${item['section_name']}',
                            'Teacher: ${item['assigned_teacher']}',
                          );
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

  Widget _buildSubjectClassCard(String name, String details, String teacher) {
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
          const CircleAvatar(
            backgroundColor: Color(0xFFD9D9D9), 
            radius: 30,
            child: Icon(Icons.menu_book, color: Colors.black54),
          ),
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
                  details,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  teacher,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_red_eye_outlined,
              color: Color(0xFF1664C5),
            ),
            onPressed: () {},
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
