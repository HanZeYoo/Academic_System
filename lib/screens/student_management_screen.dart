import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../database_helper.dart';
import '../services/email_service.dart';
import '../utils/dialog_utils.dart';
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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_searchQuery.trim().isEmpty) return _students;
    final q = _searchQuery.toLowerCase().trim();
    return _students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final id = (s['student_id'] ?? '').toString().toLowerCase();
      final grade = (s['grade_level'] ?? '').toString().toLowerCase();
      final section = (s['section'] ?? '').toString().toLowerCase();
      final gender = (s['gender'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q) || grade.contains(q) || section.contains(q) || gender.contains(q);
    }).toList();
  }

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

  Future<void> _importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        setState(() => _isLoading = true);
        File file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input.transform(utf8.decoder).transform(csv.decoder).toList();

        if (fields.isEmpty || fields.length == 1) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV file is empty or only contains headers.')));
          }
          setState(() => _isLoading = false);
          return;
        }

        int importedCount = 0;
        int duplicateCount = 0;
        final db = DatabaseHelper();
        
        for (int i = 1; i < fields.length; i++) {
          final row = fields[i];
          if (row.isEmpty || row[0].toString().trim().isEmpty) continue;

          while (row.length < 12) {
             row.add('');
          }

          final studentId = row[0].toString().trim();
          final email = row[4].toString().trim();
          
          // Duplicate Checks
          final existingId = await db.getStudentByStudentId(studentId);
          final existingEmail = await db.getStudentByEmail(email);
          
          if (existingId != null || existingEmail != null) {
            duplicateCount++;
            continue; // Skip this row
          }

          final name = row[1].toString().trim();
          final gradeLevel = row[2].toString().trim();
          final section = row[3].toString().trim();
          final parentEmail = row[5].toString().trim();
          final gender = row[6].toString().trim();
          final birthdate = row[7].toString().trim();
          final contactNumber = row[8].toString().trim();
          final parentName = row[9].toString().trim();
          final parentContact = row[10].toString().trim();
          final address = row[11].toString().trim();

          await db.addStudent(
            studentId: studentId,
            name: name,
            gradeLevel: gradeLevel,
            section: section,
            email: email,
            parentEmail: parentEmail,
            gender: gender.isEmpty ? null : gender,
            birthdate: birthdate.isEmpty ? null : birthdate,
            contactNumber: contactNumber.isEmpty ? null : contactNumber,
            parentName: parentName.isEmpty ? null : parentName,
            parentContact: parentContact.isEmpty ? null : parentContact,
            address: address.isEmpty ? null : address,
          );
          
          // Send Welcome Email to Student
          if (email.isNotEmpty) {
            try {
              await EmailService.sendEmail(
                toEmail: email,
                subject: 'Welcome to the Academic System!',
                messageText: 'Hello $name,<br><br>Your student account has been created successfully.<br><br><b>Username/Email:</b> $email<br><b>Temporary Password:</b> student123<br><br>Please log in to your account and change your password immediately.',
              );
            } catch (e) {
              print('Failed to send student welcome email to $email: $e');
            }
          }
          
          // Send Welcome Email to Parent
          if (parentEmail.isNotEmpty) {
            try {
              await EmailService.sendEmail(
                toEmail: parentEmail,
                subject: 'Parent Portal - Academic System',
                messageText: 'Hello Parent of $name,<br><br>Your parent account has been created successfully. You can now monitor your child\'s academic progress.<br><br><b>Username/Email:</b> $parentEmail<br><b>Temporary Password:</b> parent123<br><br>Please log in to your account to get started.',
              );
            } catch (e) {
              print('Failed to send parent welcome email to $parentEmail: $e');
            }
          }
          
          importedCount++;
        }

        if (mounted) {
          String msg = 'Successfully imported $importedCount students!';
          if (duplicateCount > 0) {
            msg += '\n(Skipped $duplicateCount duplicates)';
          }
          AestheticDialogs.showSuccessDialog(
            context,
            title: 'Import Successful',
            message: msg,
          );
        }
        _loadStudents();
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error importing CSV: $e'), backgroundColor: Colors.red));
      }
      setState(() => _isLoading = false);
    }
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
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by student name, LRN, grade, or section...',
              prefixIcon: const Icon(Icons.search, color: Colors.black87),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20, color: Colors.black54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
          ),
          const SizedBox(height: 24),

          // Title and Add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Student List',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _importCSV,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Import CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1664C5),
                      side: const BorderSide(color: Color(0xFF1664C5)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
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
                  title: _searchQuery.isNotEmpty ? 'Matching Students' : 'Total Students',
                  value: _isLoading ? '-' : (_searchQuery.isNotEmpty ? _filteredStudents.length.toString() : _students.length.toString()),
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
                    : _filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off, size: 64, color: Colors.black26),
                                const SizedBox(height: 12),
                                Text(
                                  'No students found matching "$_searchQuery"',
                                  style: const TextStyle(color: Colors.black54, fontSize: 15),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  child: const Text('Clear search'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadStudents,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final s = _filteredStudents[index];
                                return _buildStudentCard(context, s);
                              },
                            ),
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
    final id = 'LRN: ${student['student_id']}';
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
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(id, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 2),
                Text(section, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddStudentScreen(existingStudent: student),
                  ),
                );
                if (result == true) {
                  _loadStudents();
                }
              },
            ),
          ],
        ),
      );
    }
  }
