import 'package:flutter/material.dart';
import '../database_helper.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String username;
  const TeacherProfileScreen({super.key, required this.username});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _teacherData;
  List<Map<String, dynamic>> _assignedClasses = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final data = await DatabaseHelper().getTeacherByEmail(widget.username);
    if (data != null) {
      final name = data['name']?.toString() ?? '';
      if (name.isNotEmpty) {
        _assignedClasses = await DatabaseHelper().getSubjectClassesByTeacher(name);
      }
    }
    setState(() {
      _teacherData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final name = _teacherData?['name']?.toString() ?? 'Unknown Teacher';
    final email = _teacherData?['email']?.toString() ?? widget.username;
    final subject = _teacherData?['subject']?.toString() ?? 'N/A';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with dark blue background and overlapping avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 80,
                width: double.infinity,
                color: const Color(0xFF3383B3), // Match teacher dashboard appbar color
              ),
              const Positioned(
                top: 30, // Avatar overlaps the blue header and light blue body
                left: 24,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 80, color: Color(0xFF3383B3)),
                ),
              ),
              Positioned(
                top: 90,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA1C6E6), // Light grayish blue
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 70), // Spacing after overlapping avatar
          // Teacher Information Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name: ', name),
                      const SizedBox(height: 12),
                      _buildInfoRow('Email: ', email),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Role: ', 'Teacher'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Subject: ', subject),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 24),

          // Assigned Classes Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assigned Classes & Subjects',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_assignedClasses.isEmpty)
                    const Text('No classes assigned yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    ..._assignedClasses.map((c) => _buildListText(
                      '• ${c['subject_name']} (${c['grade_level']} - ${c['section_name']})'
                    )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Activity Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Status:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Active and verified',
                    style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
          fontFamily: 'Roboto', // Inherit default font, override weights
        ),
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildListText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }
}
