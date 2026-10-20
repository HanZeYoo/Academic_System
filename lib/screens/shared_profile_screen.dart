import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../utils/avatar_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/role_theme.dart';

enum UserRole { admin, teacher, student }

class SharedProfileScreen extends StatefulWidget {
  final String username;
  final UserRole role;

  const SharedProfileScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<SharedProfileScreen> createState() => _SharedProfileScreenState();
}

class _SharedProfileScreenState extends State<SharedProfileScreen> {
  bool _isLoading = true;
  String? _profilePicturePath;

  // Shared Data
  Map<String, dynamic>? _userData;
  
  // Role-specific Data
  List<Map<String, dynamic>> _extraDataList = [];

  // Admin In-Memory Data (Fallback if no DB for admin)
  String _adminName = 'System Administrator';
  String _adminId = 'ADM-2026-001';
  String _adminEmail = 'admin@school.edu.ph';
  String _adminDepartment = 'IT Department';
  String _adminContact = '';
  String _adminAddress = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final db = DatabaseHelper();
    
    if (widget.role == UserRole.admin) {
      _adminEmail = widget.username.isNotEmpty ? widget.username : 'admin@school.edu.ph';
      final adminPic = await db.getAdminProfilePicture(_adminEmail);
      if (mounted) {
        setState(() {
          _profilePicturePath = adminPic;
          _isLoading = false;
        });
      }
      return;
    }

    if (widget.role == UserRole.teacher) {
      final data = await db.getTeacherByEmail(widget.username);
      if (data != null) {
        final name = data['name']?.toString() ?? '';
        if (name.isNotEmpty) {
          _extraDataList = await db.getSubjectClassesByTeacher(name);
        }
      }
      if (mounted) {
        setState(() {
          _userData = data;
          _profilePicturePath = data?['profile_picture']?.toString();
          _isLoading = false;
        });
      }
      return;
    }

    if (widget.role == UserRole.student) {
      final data = await db.getStudentByEmail(widget.username);
      final schedule = await db.getStudentSchedule(widget.username);
      if (mounted) {
        setState(() {
          _userData = data;
          _extraDataList = schedule;
          _profilePicturePath = data?['profile_picture']?.toString();
          _isLoading = false;
        });
      }
      return;
    }
  }

  Future<void> _pickProfilePicture() async {
    final photo = await AvatarUtils.showPhotoPickerModal(
      context: context,
      primaryColor: _getThemeColor(),
      hasExistingPhoto: _profilePicturePath != null && _profilePicturePath!.isNotEmpty,
    );

    if (photo == null) return;

    setState(() => _isLoading = true);
    final db = DatabaseHelper();

    if (photo.isEmpty) {
      // Remove photo
      if (widget.role == UserRole.teacher) {
        await db.updateTeacherProfilePicture(widget.username, '');
      } else if (widget.role == UserRole.student) {
        await db.updateStudentProfilePicture(widget.username, '');
      } else if (widget.role == UserRole.admin) {
        await db.updateAdminProfilePicture(_adminEmail, '');
      }
      if (mounted) {
        setState(() {
          _profilePicturePath = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Update photo
      if (widget.role == UserRole.teacher) {
        await db.updateTeacherProfilePicture(widget.username, photo);
      } else if (widget.role == UserRole.student) {
        await db.updateStudentProfilePicture(widget.username, photo);
      } else if (widget.role == UserRole.admin) {
        await db.updateAdminProfilePicture(_adminEmail, photo);
      }
      if (mounted) {
        setState(() {
          _profilePicturePath = photo;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showEditDialog() {
    final s = _userData ?? {};
    
    // Admin fields
    final adminNameCtrl = TextEditingController(text: _adminName);
    final adminIdCtrl = TextEditingController(text: _adminId);
    final emailCtrl = TextEditingController(text: widget.role == UserRole.admin ? _adminEmail : (s['email'] ?? ''));
    final departmentCtrl = TextEditingController(text: widget.role == UserRole.admin ? _adminDepartment : (s['department'] ?? ''));
    
    // Shared fields
    final nameCtrl = TextEditingController(text: s['name'] ?? '');
    final contactCtrl = TextEditingController(text: widget.role == UserRole.admin ? _adminContact : (s['contact_number'] ?? ''));
    final addressCtrl = TextEditingController(text: widget.role == UserRole.admin ? _adminAddress : (s['address'] ?? ''));
    
    // Teacher specific
    final specializationCtrl = TextEditingController(text: s['specialization'] ?? '');
    
    String? selectedGender = ['Male', 'Female', 'Other'].contains(s['gender']) ? s['gender'] : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 580),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getThemeColor(),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Edit Profile',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.role == UserRole.admin) ...[
                          _dialogField('Full Name', adminNameCtrl),
                          const SizedBox(height: 14),
                          _dialogField('Admin ID', adminIdCtrl),
                          const SizedBox(height: 14),
                          _dialogField('Email', emailCtrl, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                          _dialogField('Department', departmentCtrl),
                          const SizedBox(height: 14),
                          _dialogField('Contact Number', contactCtrl, keyboardType: TextInputType.phone),
                          const SizedBox(height: 14),
                          _dialogField('Address', addressCtrl, maxLines: 2),
                        ] else ...[
                          _dialogField('Full Name', nameCtrl),
                          const SizedBox(height: 14),
                          _dialogLabel('Gender'),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedGender,
                                hint: const Text('Select gender', style: TextStyle(color: Colors.grey)),
                                items: ['Male', 'Female', 'Other'].map((g) =>
                                  DropdownMenuItem(value: g, child: Text(g))
                                ).toList(),
                                onChanged: (val) => setDialogState(() => selectedGender = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _dialogField('Contact Number', contactCtrl, keyboardType: TextInputType.phone),
                          const SizedBox(height: 14),
                          _dialogField('Address', addressCtrl, maxLines: 2),
                          if (widget.role == UserRole.teacher) ...[
                            const SizedBox(height: 14),
                            _dialogField('Specialization', specializationCtrl),
                          ]
                        ],
                      ],
                    ),
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _getThemeColor()),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Cancel', style: TextStyle(color: _getThemeColor())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getThemeColor(),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            if (widget.role == UserRole.admin) {
                              setState(() {
                                _adminName = adminNameCtrl.text.trim().isEmpty ? _adminName : adminNameCtrl.text.trim();
                                _adminId = adminIdCtrl.text.trim().isEmpty ? _adminId : adminIdCtrl.text.trim();
                                _adminEmail = emailCtrl.text.trim().isEmpty ? _adminEmail : emailCtrl.text.trim();
                                _adminDepartment = departmentCtrl.text.trim().isEmpty ? _adminDepartment : departmentCtrl.text.trim();
                                _adminContact = contactCtrl.text.trim();
                                _adminAddress = addressCtrl.text.trim();
                              });
                            } else if (widget.role == UserRole.teacher) {
                              if (nameCtrl.text.trim().isEmpty) return;
                              await DatabaseHelper().updateTeacher(
                                _userData!['id'],
                                name: nameCtrl.text.trim(),
                                gender: selectedGender,
                                contactNumber: contactCtrl.text.trim(),
                                address: addressCtrl.text.trim(),
                                specialization: specializationCtrl.text.trim(),
                              );
                            } else if (widget.role == UserRole.student) {
                              if (nameCtrl.text.trim().isEmpty) return;
                              await DatabaseHelper().updateStudent(
                                _userData!['id'],
                                name: nameCtrl.text.trim(),
                                gender: selectedGender,
                                contactNumber: contactCtrl.text.trim(),
                                address: addressCtrl.text.trim(),
                              );
                            }

                            if (context.mounted) Navigator.pop(context);
                            await _loadProfileData();
                            if (mounted) {
                              AestheticDialogs.showSuccessDialog(
                                context,
                                title: 'Profile Updated',
                                message: 'Your profile details have been updated successfully!',
                              );
                            }
                          },
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getThemeColor() {
    switch (widget.role) {
      case UserRole.admin: return RoleTheme.adminTheme.primary;
      case UserRole.teacher: return RoleTheme.teacherTheme.primary;
      case UserRole.student: return RoleTheme.studentTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    String displayName = '';
    String displayEmail = '';
    String displayRole = '';
    String departmentOrSection = '';
    String departmentOrSectionLabel = '';

    if (widget.role == UserRole.admin) {
      displayName = _adminName;
      displayEmail = _adminEmail;
      displayRole = 'Super Admin';
      departmentOrSectionLabel = 'Department: ';
      departmentOrSection = _adminDepartment;
    } else if (widget.role == UserRole.teacher) {
      displayName = _userData?['name']?.toString() ?? 'Unknown Teacher';
      displayEmail = _userData?['email']?.toString() ?? widget.username;
      displayRole = 'Teacher';
      departmentOrSectionLabel = 'Department: ';
      departmentOrSection = _userData?['department']?.toString() ?? 'N/A';
    } else if (widget.role == UserRole.student) {
      displayName = _userData?['name']?.toString() ?? 'Unknown Student';
      displayEmail = _userData?['email']?.toString() ?? widget.username;
      displayRole = 'Student';
      departmentOrSectionLabel = 'Section: ';
      departmentOrSection = '${_userData?['grade_level'] ?? ''} - ${_userData?['section'] ?? ''}';
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───────────────────────────────────────────────
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                Container(height: 160, width: double.infinity, color: _getThemeColor()),
                // Avatar
                Positioned(
                  top: 24,
                  left: 24,
                  child: GestureDetector(
                    onTap: _pickProfilePicture,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AvatarUtils.buildAvatar(
                            photo: _profilePicturePath,
                            name: displayName,
                            radius: 52,
                            foregroundColor: _getThemeColor(),
                            backgroundColor: const Color(0xFFF1F5F9),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _getThemeColor(),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Edit Profile Button
                Positioned(
                  top: 110, right: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showEditDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('Edit Profile',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Basic Info ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name: ', displayName),
                      const SizedBox(height: 12),
                      if (widget.role == UserRole.admin) ...[
                        _buildInfoRow('Admin ID: ', _adminId),
                        const SizedBox(height: 12),
                      ],
                      if (widget.role == UserRole.student) ...[
                        _buildInfoRow('LRN: ', _userData?['student_id']?.toString() ?? 'N/A'),
                        const SizedBox(height: 12),
                      ],
                      _buildInfoRow('Email: ', displayEmail),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Role: ', displayRole),
                      const SizedBox(height: 12),
                      _buildInfoRow(departmentOrSectionLabel, departmentOrSection),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 24),

          // ─── Role Specific Card ────────────────────────────────────
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
                  Text(_getRoleSpecificTitle(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._buildRoleSpecificContent(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Login Activity ──────────────────────────────────────
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
                  const Text('Account Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Status:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 4),
                  const Text('Active and verified',
                    style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w500)),
                  if (widget.role == UserRole.admin) ...[
                     const SizedBox(height: 24),
                     const Text('Last access to site:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                     const SizedBox(height: 4),
                     Text('${DateTime.now().toString().split('.')[0]}',
                       style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getRoleSpecificTitle() {
    switch (widget.role) {
      case UserRole.admin: return 'System Privileges & Managed Modules';
      case UserRole.teacher: return 'Assigned Classes & Subjects';
      case UserRole.student: return 'Enrolled Subjects & Schedule';
    }
  }

  List<Widget> _buildRoleSpecificContent() {
    if (widget.role == UserRole.admin) {
      return [
        _buildListText('• Full Access - Student Information Management'),
        _buildListText('• Full Access - Teacher Profiles & Assignments'),
        _buildListText('• Read/Write - Subject & Curriculum Scheduling'),
        _buildListText('• Read/Write - Academic Evaluations & Analytics'),
        _buildListText('• Full Access - System Reports & Parent Notifications'),
      ];
    } else if (widget.role == UserRole.teacher) {
      if (_extraDataList.isEmpty) {
        return [const Text('No classes assigned yet.', style: TextStyle(color: Colors.grey, fontSize: 13))];
      }
      return _extraDataList.map((c) => _buildListText(
        '• ${c['subject_name']} (${c['grade_level']} - ${c['section_name']})'
      )).toList();
    } else if (widget.role == UserRole.student) {
      if (_extraDataList.isEmpty) {
        return [const Text('No subjects enrolled.', style: TextStyle(color: Colors.grey, fontSize: 13))];
      }
      return _extraDataList.map((s) => _buildListText(
        '• ${s['subject_name']} (${s['time'] ?? 'TBA'} - ${s['room'] ?? 'TBA'})'
      )).toList();
    }
    return [];
  }

  Widget _buildInfoRow(String title, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: 'Roboto'),
        children: [
          TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildListText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    );
  }

  Widget _dialogField(String label, TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text, int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _getThemeColor())),
          ),
        ),
      ],
    );
  }

  Widget _dialogLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getThemeColor()));
  }
}
