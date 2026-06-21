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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 10),
            const Text(
              'Delete Announcement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAnnouncement(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
        _audienceOptions.add(selectedAudience); // Ensure it's in the dropdown options
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E66B4).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(isEditing ? Icons.edit : Icons.campaign, color: const Color(0xFF1E66B4), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEditing ? 'Edit Announcement' : 'Post Announcement',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      labelText: 'Title',
                      hintText: 'Enter announcement title',
                      labelStyle: const TextStyle(color: Color(0xFF1E66B4)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1E66B4), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentCtrl,
                    decoration: InputDecoration(
                      labelText: 'Content',
                      hintText: 'Enter announcement content...',
                      labelStyle: const TextStyle(color: Color(0xFF1E66B4)),
                      alignLabelWithHint: true,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1E66B4), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedAudience,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Audience',
                      labelStyle: const TextStyle(color: Color(0xFF1E66B4)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1E66B4), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    items: _audienceOptions.map((opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(
                        opt,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    )).toList(),
                    onChanged: (val) {
                      setStateModal(() => selectedAudience = val!);
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      setStateModal(() => isPinned = !isPinned);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isPinned,
                            activeColor: const Color(0xFF1E66B4),
                            onChanged: (val) {
                              setStateModal(() => isPinned = val ?? false);
                            },
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Pin announcement to the top',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;
                
                // Show loading dialog
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
                  // Send Push Notification for New Announcement
                  try {
                    // Fetch all users with tokens
                    final usersWithTokens = await Supabase.instance.client
                        .from('users')
                        .select('fcm_token')
                        .not('fcm_token', 'is', null);
                        
                    // Extract unique tokens to avoid duplicate notifications
                    final Set<String> uniqueTokens = {};
                    for (var user in usersWithTokens) {
                      final token = user['fcm_token'];
                      if (token != null && token.toString().isNotEmpty) {
                        uniqueTokens.add(token.toString());
                      }
                    }

                    for (var token in uniqueTokens) {
                      // Fire and forget notification for each unique token
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
                  Navigator.pop(context); // Close loading dialog
                  Navigator.pop(context); // Close post dialog
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66B4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isEditing ? 'Save Changes' : 'Post'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.role != 'student' && widget.role != 'parent') ...[
            const SizedBox(height: 20),
            _buildPostButton(),
          ],
          const SizedBox(height: 24),
          const Text(
            'Announcements',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_announcements.isEmpty)
            const Text('No announcements posted yet.', style: TextStyle(color: Colors.grey)),
          ..._announcements.map((a) => _buildAnnouncementCard(
                id: a['id'] as int,
                title: a['title']?.toString() ?? '',
                date: a['date_posted']?.toString() ?? '',
                audience: a['audience']?.toString() ?? '',
                status: a['status']?.toString() ?? 'Active',
                statusColor: const Color(0xFF4DC271),
                content: a['content']?.toString() ?? '',
                isPinned: (a['is_pinned'] as int?) == 1,
                author: a['author']?.toString(),
              )),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E66B4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.campaign, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'Manage Announcements',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E66B4),
          ),
        ),
      ],
    );
  }

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showPostDialog(),
        icon: const Icon(Icons.add_alert, color: Colors.white),
        label: const Text(
          'Post New Announcement',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E66B4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
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
    // Admin (widget.username == null) can edit anything. Teacher can only edit their own. Student/Parent cannot edit.
    bool canEdit = widget.role != 'student' && widget.role != 'parent' && (widget.username == null || author == widget.username);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPinned ? const Color(0xFF1E66B4) : Colors.grey.shade300,
          width: isPinned ? 2 : 1,
        ),
        boxShadow: [
          if (isPinned)
            BoxShadow(
              color: const Color(0xFF1E66B4).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned) ...[
                const Icon(Icons.push_pin, color: Color(0xFF1E66B4), size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                date,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.group, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  audience,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          if (canEdit) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(Icons.edit, 'Edit', const Color(0xFF1E66B4), () {
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
                const SizedBox(width: 16),
                _buildActionButton(Icons.delete, 'Delete', Colors.red, () => _confirmDelete(id)),
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
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
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
