import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../services/email_service.dart';
import '../utils/avatar_utils.dart';
import '../utils/dialog_utils.dart';
import 'add_teacher_screen.dart';
import 'teacher_detail_screen.dart';
import '../widgets/pagination_controls.dart';
import '../widgets/skeleton_loader.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  List<Map<String, dynamic>> _teachers = [];
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

  List<Map<String, dynamic>> get _filteredTeachers {
    if (_searchQuery.trim().isEmpty) return _teachers;
    final q = _searchQuery.toLowerCase().trim();
    return _teachers.where((t) {
      final name = (t['name'] ?? '').toString().toLowerCase();
      final id = (t['teacher_id'] ?? '').toString().toLowerCase();
      final dept = (t['department'] ?? '').toString().toLowerCase();
      final email = (t['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q) || dept.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    final teachers = await DatabaseHelper().getTeachers();
    if (!mounted) return;
    setState(() {
      _teachers = teachers;
      _isLoading = false;
    });
  }

  String? _normalizeEmploymentStatus(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower == 'full-time') return 'Full-Time';
    if (lower == 'part-time') return 'Part-Time';
    if (lower == 'contract') return 'Contract';
    return trimmed;
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
            title: const Text('Import Teachers from CSV'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File: ${picked.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text('Detected ${dataRows.length} teacher record(s) to import.'),
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

      for (final row in dataRows) {
        var teacherId = readField(row, 'teacher_id', 0);
        final name = readField(row, 'name', 1);
        final department = readField(row, 'department', 2);
        final email = readField(row, 'email', 3).toLowerCase();
        final gender = readField(row, 'gender', 4);
        final birthdate = readField(row, 'birthdate', 5);
        final contactNumber = readField(row, 'contact_number', 6);
        final address = readField(row, 'address', 7);
        final specialization = readField(row, 'specialization', 8);
        final employmentStatus =
            _normalizeEmploymentStatus(readField(row, 'employment_status', 9));
        final hiringDate = readField(row, 'hiring_date', 10);
        final assignedSection = readField(row, 'assigned_section', 11);

        if (name.isEmpty ||
            email.isEmpty ||
            !emailRegex.hasMatch(email) ||
            (!email.endsWith('.com') && !email.endsWith('.ph'))) {
          invalidCount++;
          continue;
        }

        if (teacherId.isEmpty) {
          teacherId = await db.generateNextTeacherId();
        }

        final existingId = await db.getTeacherByTeacherId(teacherId);
        final existingEmail =
            await db.getTeacherByEmail(email, forceRefresh: true);
        final existingUser = await db.getUserByUsername(email);

        if (existingId != null ||
            existingEmail != null ||
            existingUser != null) {
          duplicateCount++;
          continue;
        }

        await db.addTeacher(
          teacherId: teacherId,
          name: name,
          department: department.isEmpty ? 'Unknown Department' : department,
          email: email,
          gender: gender.isEmpty ? null : gender,
          birthdate: birthdate.isEmpty ? null : birthdate,
          contactNumber: contactNumber.isEmpty ? null : contactNumber,
          address: address.isEmpty ? null : address,
          specialization: specialization.isEmpty ? null : specialization,
          employmentStatus: employmentStatus,
          hiringDate: hiringDate.isEmpty ? null : hiringDate,
          assignedSection: assignedSection.isEmpty ? null : assignedSection,
        );

        if (sendWelcomeEmails) {
          try {
            await EmailService.sendEmail(
              toEmail: email,
              subject: 'Welcome to the Academic System!',
              messageText:
                  'Hello $name,<br><br>Your teacher account has been created successfully.<br><br><b>Username/Email:</b> $email<br><b>Temporary Password:</b> teacher123<br><br>Please log in to your account and change your password immediately.',
            );
          } catch (e) {
            debugPrint('Failed to send teacher welcome email to $email: $e');
          }
        }

        importedCount++;
      }

      await _loadTeachers();

      if (mounted) {
        final buffer = StringBuffer(
          'Successfully imported $importedCount teacher(s)!',
        );
        if (duplicateCount > 0) {
          buffer.write('\n(Skipped $duplicateCount duplicate(s))');
        }
        if (invalidCount > 0) {
          buffer.write('\n(Skipped $invalidCount invalid row(s))');
        }
        await AestheticDialogs.showSuccessDialog(
          context,
          title: 'Import Complete',
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
                hintText: 'Search by teacher name, ID, department, or email...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
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
                      'Faculty Directory',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage teaching faculty, departments & teaching loads',
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
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
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: const Text('Add Teacher'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1664C5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                        'Faculty Directory',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage teaching faculty, departments & teaching loads',
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add Teacher'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1664C5),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.badge_rounded,
                  iconBgColor: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF1664C5),
                  title: _searchQuery.isNotEmpty ? 'Matching Teachers' : 'Total Faculty',
                  value: _isLoading ? '-' : (_searchQuery.isNotEmpty ? _filteredTeachers.length.toString() : _teachers.length.toString()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.domain_rounded,
                  iconBgColor: const Color(0xFFEDE9FE),
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Departments',
                  value: _isLoading ? '-' : _teachers.map((e) => e['department']?.toString() ?? '').toSet().where((x) => x.isNotEmpty).length.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // List
          Expanded(
            child: _isLoading
                ? SkeletonPresets.cardList(itemCount: 6, padding: EdgeInsets.zero)
                : _teachers.isEmpty
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
                              child: const Icon(Icons.co_present_rounded, size: 48, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No teachers registered yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap "Add Teacher" or "Import CSV" to add faculty members.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : _filteredTeachers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 54, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                Text(
                                  'No teachers found matching "$_searchQuery"',
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
                                  onRefresh: _loadTeachers,
                                  child: Builder(
                                    builder: (context) {
                                      final pageItems = paginateList(_filteredTeachers, _currentPage, _pageSize);
                                      return ListView.builder(
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        itemCount: pageItems.length,
                                        itemBuilder: (context, index) {
                                          final t = pageItems[index];
                                          return _buildTeacherCard(context, t);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                              PaginationControls(
                                currentPage: clampPage(_currentPage, _filteredTeachers.length, _pageSize),
                                totalItems: _filteredTeachers.length,
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

  Widget _buildTeacherCard(BuildContext context, Map<String, dynamic> teacher) {
    final name = teacher['name']?.toString() ?? 'Unknown';
    final id = 'ID: ${teacher['teacher_id']}';
    final department = teacher['department']?.toString() ?? 'General Faculty';
    final email = teacher['email']?.toString() ?? 'No email';

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
            photo: teacher['profile_picture']?.toString(),
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
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        department,
                        style: const TextStyle(
                          color: Color(0xFF6D28D9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty && email != 'No email') ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'View Profile',
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
            tooltip: 'Edit Details',
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B)),
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
