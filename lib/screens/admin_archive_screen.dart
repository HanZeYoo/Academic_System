import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../utils/dialog_utils.dart';

class AdminArchiveScreen extends StatefulWidget {
  const AdminArchiveScreen({super.key});

  @override
  State<AdminArchiveScreen> createState() => _AdminArchiveScreenState();
}

class _AdminArchiveScreenState extends State<AdminArchiveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isPurging = false;

  List<Map<String, dynamic>> _archivedTeachers = [];
  List<Map<String, dynamic>> _archivedStudents = [];
  List<Map<String, dynamic>> _archivedSubjects = [];

  static const int retentionDays = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadArchives();
  }

  Future<void> _loadArchives({bool runPurge = true}) async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper();

    // Auto-purge any records that have exceeded the 30-day retention limit
    if (runPurge) {
      await db.purgeExpiredArchivedRecords(retentionDays: retentionDays);
    }

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

  Future<void> _triggerManualPurge() async {
    setState(() => _isPurging = true);
    final result = await DatabaseHelper().purgeExpiredArchivedRecords(retentionDays: retentionDays);
    final total = (result['students'] ?? 0) + (result['teachers'] ?? 0) + (result['subjects'] ?? 0);
    
    if (mounted) {
      setState(() => _isPurging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(total > 0 
              ? 'Successfully purged $total expired records permanently.' 
              : 'No expired records found (all are within the $retentionDays-day limit).'),
          backgroundColor: total > 0 ? Colors.green.shade700 : const Color(0xFF1664C5),
        ),
      );
      _loadArchives(runPurge: false);
    }
  }

  Future<void> _restoreRecord(String type, int id, String name) async {
    final db = DatabaseHelper();
    if (type == 'Teacher') {
      await db.restoreTeacher(id);
    } else if (type == 'Student') {
      await db.restoreStudent(id);
    } else {
      await db.restoreSubjectClass(id);
    }

    if (mounted) {
      await AestheticDialogs.showSuccessDialog(
        context,
        title: 'Record Restored',
        message: '$name restored successfully and returned to active lists.',
      );
      _loadArchives(runPurge: false);
    }
  }

  Future<void> _confirmPermanentDelete(String type, int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Permanent Delete'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "$name"?\n\n'
          '⚠️ This action is IRREVERSIBLE and will immediately remove all data from the database without waiting for the $retentionDays-day limit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = DatabaseHelper();
      if (type == 'Teacher') {
        await db.permanentlyDeleteTeacher(id);
      } else if (type == 'Student') {
        await db.permanentlyDeleteStudent(id);
      } else {
        await db.permanentlyDeleteSubjectClass(id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permanently deleted "$name".'), backgroundColor: Colors.red.shade800),
        );
        _loadArchives(runPurge: false);
      }
    }
  }

  Map<String, dynamic> _getRetentionInfo(dynamic deletedAtRaw) {
    if (deletedAtRaw == null) {
      return {
        'text': 'Within 30-day window',
        'color': Colors.blue.shade800,
        'bgColor': Colors.blue.shade50,
        'urgent': false,
      };
    }

    try {
      final deletedAt = DateTime.parse(deletedAtRaw.toString()).toLocal();
      final expiryDate = deletedAt.add(const Duration(days: retentionDays));
      final remaining = expiryDate.difference(DateTime.now()).inDays;

      if (remaining <= 0) {
        return {
          'text': 'Expired • Pending auto-delete',
          'color': Colors.red.shade800,
          'bgColor': Colors.red.shade50,
          'urgent': true,
        };
      } else if (remaining <= 5) {
        return {
          'text': '$remaining day${remaining == 1 ? '' : 's'} remaining before permanent delete',
          'color': Colors.red.shade800,
          'bgColor': Colors.red.shade50,
          'urgent': true,
        };
      } else if (remaining <= 10) {
        return {
          'text': '$remaining days remaining before permanent delete',
          'color': Colors.orange.shade900,
          'bgColor': Colors.orange.shade50,
          'urgent': false,
        };
      } else {
        return {
          'text': '$remaining days remaining before permanent delete',
          'color': const Color(0xFF1664C5),
          'bgColor': const Color(0xFFE3F2FD),
          'urgent': false,
        };
      }
    } catch (_) {
      return {
        'text': 'Within 30-day window',
        'color': Colors.blue.shade800,
        'bgColor': Colors.blue.shade50,
        'urgent': false,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFCBEAFB),
      child: Column(
        children: [
          // ── Retention Policy Banner ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFE1F0FA),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF1664C5), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Soft Delete & 30-Day Retention Policy Active',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF103B5B)),
                      ),
                      Text(
                        'Items stay archived for $retentionDays days before being permanently deleted from the database.',
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _isPurging ? null : _triggerManualPurge,
                  icon: _isPurging
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Purge Expired', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1664C5),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          // ── Tabs ─────────────────────────────────────────────────────
          Container(
            color: const Color(0xFF2B81B7),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Teachers (${_archivedTeachers.length})'),
                Tab(text: 'Students (${_archivedStudents.length})'),
                Tab(text: 'Subjects (${_archivedSubjects.length})'),
              ],
            ),
          ),
          // ── Tab Views ────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_archivedTeachers, 'Teacher', Icons.person_off),
                      _buildList(_archivedStudents, 'Student', Icons.people_outline),
                      _buildList(_archivedSubjects, 'Subject', Icons.book_outlined),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String type, IconData emptyIcon) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No archived $type records found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Deleted records will appear here for $retentionDays days before permanent deletion.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadArchives(runPurge: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final String name = type == 'Subject' ? (item['subject_name'] ?? 'Unknown') : (item['name'] ?? 'Unknown');
          final String subtitle = type == 'Subject'
              ? (item['subject_code'] ?? '')
              : (type == 'Teacher' ? (item['teacher_id'] ?? '') : (item['student_id'] ?? ''));

          final retention = _getRetentionInfo(item['deleted_at']);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: Icon(type == 'Subject' ? Icons.book : Icons.person, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF224A60)),
                            ),
                            const SizedBox(height: 2),
                            Text('ID/Code: $subtitle', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      // Actions
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _restoreRecord(type, item['id'], name),
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Restore', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1664C5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _confirmPermanentDelete(type, item['id'], name),
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            tooltip: 'Permanently Delete Now',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Retention Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: retention['bgColor'] as Color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          retention['urgent'] == true ? Icons.timer_off_outlined : Icons.timer_outlined,
                          size: 14,
                          color: retention['color'] as Color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          retention['text'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: retention['color'] as Color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
