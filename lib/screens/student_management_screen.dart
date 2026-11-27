import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../database_helper.dart';
import '../services/email_service.dart';
import '../utils/avatar_utils.dart';
import '../utils/dialog_utils.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';
import '../widgets/pagination_controls.dart';
import '../widgets/skeleton_loader.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_searchQuery.trim().isEmpty) return _students;
    final q = _searchQuery.toLowerCase().trim();
    final cleanQ = q.replaceAll(RegExp(r'[\s\-]'), '');
    return _students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final id = (s['student_id'] ?? '').toString().toLowerCase();
      final cleanId = id.replaceAll(RegExp(r'[\s\-]'), '');
      final grade = (s['grade_level'] ?? '').toString().toLowerCase();
      final section = (s['section'] ?? '').toString().toLowerCase();
      final gender = (s['gender'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          id.contains(q) ||
          (cleanQ.isNotEmpty && cleanId.contains(cleanQ)) ||
          grade.contains(q) ||
          section.contains(q) ||
          gender.contains(q);
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
    if (!mounted) return;
    setState(() {
      _students = students;
      _isLoading = false;
    });
  }

  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes ??
          (picked.path != null ? await File(picked.path!).readAsBytes() : null);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read CSV file data.')),
          );
        }
        return;
      }

      var csvText = utf8.decode(bytes);
      if (csvText.startsWith('\uFEFF')) {
        csvText = csvText.substring(1);
      }

      final fields =
          await Stream<String>.value(csvText).transform(csv.decoder).toList();

      if (fields.length <= 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV file is empty or only contains headers.'),
            ),
          );
        }
        return;
      }

      final dataRows = fields
          .skip(1)
          .where((row) => row.any((cell) => cell.toString().trim().isNotEmpty))
          .toList();

      if (dataRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV file is empty or only contains headers.'),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      bool sendWelcomeEmails = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Import Students from CSV'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File: ${picked.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text('Detected ${dataRows.length} student record(s) to import.'),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sendWelcomeEmails,
                  onChanged: (val) =>
                      setDialogState(() => sendWelcomeEmails = val ?? false),
                  title: const Text(
                    'Send welcome emails with credentials',
                    style: TextStyle(fontSize: 14),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1664C5),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Import'),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() => _isLoading = true);

      final headerRow = fields.first;
      final Map<String, int> headerIndex = {};
      for (int c = 0; c < headerRow.length; c++) {
        final key = headerRow[c]
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[\s\-]+'), '_');
        if (key.isNotEmpty) {
          headerIndex[key] = c;
        }
      }

      String readField(List<dynamic> row, String headerName, int fallbackIndex) {
        final idx = headerIndex[headerName] ?? fallbackIndex;
        if (idx < 0 || idx >= row.length) return '';
        return row[idx].toString().trim();
      }

      int importedCount = 0;
      int duplicateCount = 0;
      int invalidCount = 0;
      final db = DatabaseHelper();
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      final neuIdRegex = RegExp(r'^\d{2}-\d{4}-\d{3}$');
      final nineDigitsRegex = RegExp(r'^\d{9}$');
      final lrnRegex = RegExp(r'^\d{12}$');

      for (final row in dataRows) {
        final studentId = readField(row, 'student_id', 0);
        final name = readField(row, 'name', 1);
        final gradeLevel = readField(row, 'grade_level', 2);
        final section = readField(row, 'section', 3);
        final email = readField(row, 'email', 4).toLowerCase();
        final parentEmail = readField(row, 'parent_email', 5).toLowerCase();
        final gender = readField(row, 'gender', 6);
        final birthdate = readField(row, 'birthdate', 7);
        final contactNumber = readField(row, 'contact_number', 8);
        final parentName = readField(row, 'parent_name', 9);
        final parentContact = readField(row, 'parent_contact', 10);
        final address = readField(row, 'address', 11);

        final cleanStudentId = studentId.replaceAll(RegExp(r'[\s\-]'), '');
        final isValidNeuId = neuIdRegex.hasMatch(studentId) ||
            nineDigitsRegex.hasMatch(cleanStudentId);
        final isValidLrn = lrnRegex.hasMatch(cleanStudentId);

        if ((!isValidNeuId && !isValidLrn) || name.isEmpty) {
          invalidCount++;
          continue;
        }

        if (email.isNotEmpty &&
            (!emailRegex.hasMatch(email) ||
                (!email.endsWith('.com') && !email.endsWith('.ph')))) {
          invalidCount++;
          continue;
        }

        // Duplicate Checks
        final existingId = await db.getStudentByStudentId(studentId);
        final existingEmail = email.isNotEmpty
            ? await db.getStudentByEmail(email, forceRefresh: true)
            : null;
        final existingUser =
            email.isNotEmpty ? await db.getUserByUsername(email) : null;

        if (existingId != null ||
            existingEmail != null ||
            existingUser != null) {
          duplicateCount++;
          continue;
        }

        await db.addStudent(
          studentId: studentId,
          name: name,
          gradeLevel: gradeLevel.isEmpty ? 'N/A' : gradeLevel,
          section: section.isEmpty ? 'N/A' : section,
          email: email,
          parentEmail: parentEmail,
          gender: gender.isEmpty ? null : gender,
          birthdate: birthdate.isEmpty ? null : birthdate,
          contactNumber: contactNumber.isEmpty ? null : contactNumber,
          parentName: parentName.isEmpty ? null : parentName,
          parentContact: parentContact.isEmpty ? null : parentContact,
          address: address.isEmpty ? null : address,
        );

        if (sendWelcomeEmails) {
          final studentDefaultPassword =
              DatabaseHelper.defaultStudentPassword(studentId);
          // Send Welcome Email to Student
          if (email.isNotEmpty) {
            try {
              await EmailService.sendEmail(
                toEmail: email,
                subject: 'Welcome to the Academic System!',
                messageText:
                    'Hello $name,<br><br>Your student account has been created successfully.<br><br><b>Username/Email:</b> $email<br><b>Temporary Password:</b> $studentDefaultPassword<br><br>Please log in to your account and change your password immediately.',
              );
            } catch (e) {
              debugPrint('Failed to send student welcome email to $email: $e');
            }
          }

          // Send Welcome Email to Parent
          if (parentEmail.isNotEmpty) {
            try {
              await EmailService.sendEmail(
                toEmail: parentEmail,
                subject: 'Parent Portal - Academic System',
                messageText:
                    'Hello Parent of $name,<br><br>Your parent account has been created successfully. You can now monitor your child\'s academic progress.<br><br><b>Username/Email:</b> $parentEmail<br><b>Temporary Password:</b> parent123<br><br>Please log in to your account to get started.',
              );
            } catch (e) {
              debugPrint(
                  'Failed to send parent welcome email to $parentEmail: $e');
            }
          }
        }

        importedCount++;
      }

      await _loadStudents();

      if (mounted) {
        final buffer = StringBuffer(
          'Successfully imported $importedCount student(s)!',
        );
        if (duplicateCount > 0) {
          buffer.write('\n(Skipped $duplicateCount duplicate(s))');
        }
        if (invalidCount > 0) {
          buffer.write('\n(Skipped $invalidCount invalid row(s))');
        }
        await AestheticDialogs.showSuccessDialog(
          context,
          title: 'Import Successful',
          message: buffer.toString(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _currentPage = 1;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by student name, ID / LRN, grade, or section...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _currentPage = 1;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title and Add button row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 560;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Directory',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage enrolled learners, section assignments & profiles',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _importCSV,
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Import CSV'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1664C5),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddStudentScreen()),
                              );
                              if (result == true) {
                                _loadStudents();
                              }
                            },
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: const Text('Add Student'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1664C5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Student Directory',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage enrolled learners, section assignments & profiles',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _importCSV,
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Import CSV'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1664C5),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add Student'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1664C5),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people_alt_rounded,
                  iconBgColor: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF1664C5),
                  title: _searchQuery.isNotEmpty ? 'Matching Students' : 'Total Students',
                  value: _isLoading ? '-' : (_searchQuery.isNotEmpty ? _filteredStudents.length.toString() : _students.length.toString()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.school_rounded,
                  iconBgColor: const Color(0xFFDCFCE7),
                  iconColor: const Color(0xFF10B981),
                  title: 'Grade Levels Active',
                  value: _isLoading ? '-' : _students.map((e) => e['grade_level']?.toString() ?? '').toSet().where((x) => x.isNotEmpty).length.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // List
          Expanded(
            child: _isLoading
                ? SkeletonPresets.cardList(itemCount: 6, padding: EdgeInsets.zero)
                : _students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.people_outline, size: 48, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No students registered yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap "Add Student" or "Import CSV" to get started.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : _filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 54, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                Text(
                                  'No students found matching "$_searchQuery"',
                                  style: const TextStyle(color: Color(0xFF475569), fontSize: 15, fontWeight: FontWeight.w500),
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
                        : Column(
                            children: [
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: _loadStudents,
                                  child: Builder(
                                    builder: (context) {
                                      final pageItems = paginateList(_filteredStudents, _currentPage, _pageSize);
                                      return ListView.builder(
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        itemCount: pageItems.length,
                                        itemBuilder: (context, index) {
                                          final s = pageItems[index];
                                          return _buildStudentCard(context, s);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                              PaginationControls(
                                currentPage: clampPage(_currentPage, _filteredStudents.length, _pageSize),
                                totalItems: _filteredStudents.length,
                                pageSize: _pageSize,
                                accentColor: const Color(0xFF1664C5),
                                margin: const EdgeInsets.only(top: 10),
                                onPageChanged: (page) => setState(() => _currentPage = page),
                              ),
                            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AvatarUtils.buildAvatar(
            photo: student['profile_picture']?.toString(),
            name: name,
            radius: 26,
            foregroundColor: const Color(0xFF1664C5),
            backgroundColor: const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        id,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1664C5).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        section,
                        style: const TextStyle(
                          color: Color(0xFF1664C5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View Profile',
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
            tooltip: 'Edit Details',
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B)),
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
