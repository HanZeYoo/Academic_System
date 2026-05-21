import 'package:flutter/material.dart';
import '../database_helper.dart';

class StudentProfileScreen extends StatefulWidget {
  final String username;
  const StudentProfileScreen({super.key, required this.username});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _studentData;
  List<Map<String, dynamic>> _subjectDetails = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final db = DatabaseHelper();
    final data = await db.getStudentByEmail(widget.username);
    final schedule = await db.getStudentSchedule(widget.username);
    
    if (mounted) {
      setState(() {
        _studentData = data;
        _subjectDetails = schedule;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final name = _studentData?['name']?.toString() ?? 'Unknown Student';
    final email = _studentData?['email']?.toString() ?? widget.username;
    final studentId = _studentData?['student_id']?.toString() ?? 'N/A';
    final gradeLvl = _studentData?['grade_level']?.toString() ?? 'N/A';

    return SingleChildScrollView(
      child: Container(
        color: const Color(0xFFCBEAFB), // Light blue background
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with dark blue background and overlapping avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  color: const Color(0xFF224A60), // Dark blue header
                ),
                // Avatar
                Positioned(
                  top: 40,
                  left: 24,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.person, size: 90, color: Colors.black),
                  ),
                ),
                // Edit Profile Button
                Positioned(
                  top: 110,
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
            const SizedBox(height: 60), // Spacing for overlapping avatar
            
            // Student Information Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Name: ', name),
                        const SizedBox(height: 12),
                        _buildInfoRow('Student ID: ', studentId),
                        const SizedBox(height: 12),
                        _buildInfoRow('Email: ', email),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Grade Lvl: ', gradeLvl),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 24),

            // Subject Details Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subject details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    if (_subjectDetails.isEmpty)
                      const Text('No subjects assigned yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                    else
                      ..._subjectDetails.map((c) => _buildListText(
                        '${c['subject_code']} - ${c['subject_name']}'
                      )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Login Activity Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Login Activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'First access to site:',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Saturday, 24 January 2026, 8:45 PM (110 days 18 hours)',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Last access to site:',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Friday, 15 May 2026, 3:20 PM (5 secs)',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
          fontFamily: 'Roboto',
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
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
    );
  }
}
