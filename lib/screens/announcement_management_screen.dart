import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database_helper.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  final String? username;
  final String? role;
  const AnnouncementManagementScreen({super.key, this.username, this.role});

  @override
  State<AnnouncementManagementScreen> createState() => _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState extends State<AnnouncementManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _announcements = [];
  List<String> _audienceOptions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    
    // Load audience options based on role
    if (widget.role != 'student') {
      if (widget.username != null) {
        final teacher = await db.getTeacherByEmail(widget.username!);
        if (teacher != null) {
          final classes = await db.getSubjectClassesByTeacher(teacher['name'].toString());
          _audienceOptions = classes.map((c) => '${c["grade_level"]} - ${c["section_name"]} (${c["subject_name"]})').toList();
        }
      } else {
        _audienceOptions = ['System-wide', 'All Students', 'All Teachers'];
      }
    }

    // Load announcements
    final announcements = await db.getAnnouncements(widget.username, role: widget.role);
    
    if (mounted) {
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    await DatabaseHelper().deleteAnnouncement(id);
    _loadData();
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Announcement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this bulletin announcement? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAnnouncement(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPostDialog({Map<String, dynamic>? existingAnnouncement}) {
    final isEditing = existingAnnouncement != null;
    final titleCtrl = TextEditingController(text: isEditing ? existingAnnouncement['title'] : '');
    final contentCtrl = TextEditingController(text: isEditing ? existingAnnouncement['content'] : '');
    
    String selectedAudience = 'System-wide';
    if (isEditing) {
      selectedAudience = existingAnnouncement['audience'];
      if (!_audienceOptions.contains(selectedAudience)) {
        _audienceOptions.add(selectedAudience);
      }
    } else if (_audienceOptions.isNotEmpty) {
      selectedAudience = _audienceOptions.first;
    }
    
    bool isPinned = isEditing ? (existingAnnouncement['is_pinned'] == 1) : false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F52BA).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(isEditing ? Icons.edit_note_rounded : Icons.campaign_rounded, color: const Color(0xFF0F52BA), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing ? 'Edit Announcement' : 'New Announcement',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Announcement Title',
                      hintText: 'e.g. Schedule Update or Campus Event',
                      labelStyle: const TextStyle(color: Color(0xFF0F52BA), fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: contentCtrl,
                    decoration: InputDecoration(
                      labelText: 'Announcement Details',
                      hintText: 'Enter full description...',
                      labelStyle: const TextStyle(color: Color(0xFF0F52BA), fontSize: 13),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedAudience,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Target Audience',
                      labelStyle: const TextStyle(color: Color(0xFF0F52BA), fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: _audienceOptions.map((opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(
                        opt,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    )).toList(),
                    onChanged: (val) {
                      setStateModal(() => selectedAudience = val!);
                    },
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      setStateModal(() => isPinned = !isPinned);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isPinned,
                            activeColor: const Color(0xFF0F52BA),
                            onChanged: (val) {
                              setStateModal(() => isPinned = val ?? false);
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Pin announcement to the top of notice boards',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                final announcementData = {
                  'title': titleCtrl.text,
                  'content': contentCtrl.text,
                  'audience': selectedAudience,
                  'date_posted': isEditing ? existingAnnouncement['date_posted'] : DateTime.now().toString().split(' ')[0],
                  'status': 'Active',
                  'is_pinned': isPinned ? 1 : 0,
                  'author': isEditing ? existingAnnouncement['author'] : (widget.username ?? 'admin'),
                };
                
                if (isEditing) {
                  await DatabaseHelper().updateAnnouncement(existingAnnouncement['id'], announcementData);
                } else {
                  await DatabaseHelper().addAnnouncement(announcementData);
                  try {
                    final usersWithTokens = await Supabase.instance.client
                        .from('users')
                        .select('fcm_token')
                        .not('fcm_token', 'is', null);
                        
                    final Set<String> uniqueTokens = {};
                    for (var user in usersWithTokens) {
                      final token = user['fcm_token'];
                      if (token != null && token.toString().isNotEmpty) {
                        uniqueTokens.add(token.toString());
                      }
                    }

                    for (var token in uniqueTokens) {
                      try {
                        await Supabase.instance.client.functions.invoke('send-fcm', body: {
                          'title': 'New Announcement',
                          'body': titleCtrl.text,
                          'token': token,
                        });
                      } catch(e) {
                        print('Push error: $e');
                      }
                    }
                  } catch (e) {
                    print('Error sending announcement push: $e');
                  }
                }
                
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F52BA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isEditing ? 'Save Changes' : 'Publish'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF0F52BA),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (widget.role != 'student' && widget.role != 'parent') ...[
              const SizedBox(height: 18),
              _buildPostButton(),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.campaign_outlined, size: 20, color: Color(0xFF0F52BA)),
                const SizedBox(width: 8),
                const Text(
                  'Bulletin Feed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F52BA).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _announcements.length.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F52BA),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_announcements.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_off_outlined, size: 36, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No announcements posted yet',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Important institutional notices and circulars will be published here.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._announcements.map((a) => _buildAnnouncementCard(
                    id: a['id'] as int,
                    title: a['title']?.toString() ?? '',
                    date: a['date_posted']?.toString() ?? '',
                    audience: a['audience']?.toString() ?? '',
                    status: a['status']?.toString() ?? 'Active',
                    statusColor: const Color(0xFF10B981),
                    content: a['content']?.toString() ?? '',
                    isPinned: (a['is_pinned'] as int?) == 1,
                    author: a['author']?.toString(),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F52BA), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F52BA).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Announcements Hub',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Campus-wide notices, updates & circulars',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth >= 600;
        return Align(
          alignment: isWeb ? Alignment.centerLeft : Alignment.center,
          child: SizedBox(
            width: isWeb ? 260 : double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPostDialog(),
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Publish Announcement',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F52BA),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementCard({
    required int id,
    required String title,
    required String date,
    required String audience,
    required String status,
    required Color statusColor,
    required String content,
    required bool isPinned,
    String? author,
  }) {
    bool canEdit = widget.role != 'student' && widget.role != 'parent' && (widget.username == null || author == widget.username);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPinned ? const Color(0xFF0F52BA) : const Color(0xFFE2E8F0),
          width: isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPinned ? const Color(0xFF0F52BA).withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
            blurRadius: isPinned ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.push_pin_rounded, color: Color(0xFFD97706), size: 13),
                      SizedBox(width: 4),
                      Text(
                        'PINNED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Text(
                    date,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Text(
                    audience,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.45),
          ),
          if (canEdit) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(Icons.edit_outlined, 'Edit', const Color(0xFF0F52BA), () {
                  _showPostDialog(existingAnnouncement: {
                    'id': id,
                    'title': title,
                    'content': content,
                    'audience': audience,
                    'is_pinned': isPinned ? 1 : 0,
                    'date_posted': date,
                    'author': author,
                  });
                }),
                const SizedBox(width: 18),
                _buildActionButton(Icons.delete_outline_rounded, 'Delete', const Color(0xFFEF4444), () => _confirmDelete(id)),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
