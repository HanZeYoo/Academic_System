import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../utils/avatar_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/role_theme.dart';

enum UserRole { admin, teacher, student, parent }

class SharedProfileScreen extends StatefulWidget {
  final String username;
  final UserRole role;
  final String? adminRoleTitle;

  const SharedProfileScreen({
    super.key,
    required this.username,
    required this.role,
    this.adminRoleTitle,
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

  // Admin Data (Cached in SharedPreferences)
  String _adminName = 'System Administrator';
  String _adminId = 'ADM-2026-001';
  String _adminEmail = 'admin@academic.system';
  String _adminDepartment = 'IT Department';
  String _adminContact = '';
  String _adminAddress = '';
  late DateTime _lastAccessTime;

  @override
  void initState() {
    super.initState();
    _lastAccessTime = DateTime.now();
    _loadProfileData();
  }

  RoleColorScheme _getRoleTheme() {
    if (widget.role == UserRole.admin) {
      return RoleTheme.getRoleTheme(widget.adminRoleTitle ?? 'admin');
    } else if (widget.role == UserRole.teacher) {
      return RoleTheme.teacherTheme;
    } else if (widget.role == UserRole.student) {
      return RoleTheme.studentTheme;
    } else if (widget.role == UserRole.parent) {
      return RoleTheme.parentTheme;
    }
    return RoleTheme.adminTheme;
  }

  Future<void> _loadProfileData() async {
    final db = DatabaseHelper();

    if (widget.role == UserRole.admin) {
      _adminEmail = widget.username.isNotEmpty ? widget.username : 'admin@academic.system';
      final adminPic = await db.getAdminProfilePicture(_adminEmail);

      // Load cached admin info from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        _adminName = prefs.getString('admin_name_$_adminEmail') ?? _adminName;
        _adminId = prefs.getString('admin_id_$_adminEmail') ?? _adminId;
        _adminDepartment = prefs.getString('admin_dept_$_adminEmail') ?? _adminDepartment;
        _adminContact = prefs.getString('admin_contact_$_adminEmail') ?? _adminContact;
        _adminAddress = prefs.getString('admin_address_$_adminEmail') ?? _adminAddress;
      } catch (_) {}

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

    if (widget.role == UserRole.parent) {
      final children = await db.getStudentsByParentEmail(widget.username);
      if (mounted) {
        setState(() {
          _extraDataList = children;
          if (children.isNotEmpty) {
            _userData = {
              'parent_name': children.first['parent_name'] ?? 'Guardian Parent',
              'parent_contact': children.first['parent_contact'] ?? '',
              'email': widget.username,
            };
          }
          _isLoading = false;
        });
      }
      return;
    }
  }

  Future<void> _pickProfilePicture() async {
    final theme = _getRoleTheme();
    final photo = await AvatarUtils.showPhotoPickerModal(
      context: context,
      primaryColor: theme.primary,
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

  void _copyToClipboard(String text, String label) {
    if (text.trim().isEmpty || text == 'N/A' || text == 'Not provided') return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Copied $label to clipboard: "$text"')),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showEditDialog() {
    final theme = _getRoleTheme();
    final s = _userData ?? {};

    // Admin fields
    final adminNameCtrl = TextEditingController(text: _adminName);
    final adminIdCtrl = TextEditingController(text: _adminId);
    final emailCtrl = TextEditingController(
      text: widget.role == UserRole.admin ? _adminEmail : (s['email'] ?? widget.username),
    );
    final departmentCtrl = TextEditingController(
      text: widget.role == UserRole.admin ? _adminDepartment : (s['department'] ?? ''),
    );

    // Shared fields
    final nameCtrl = TextEditingController(
      text: widget.role == UserRole.parent ? (s['parent_name'] ?? '') : (s['name'] ?? ''),
    );
    final contactCtrl = TextEditingController(
      text: widget.role == UserRole.admin
          ? _adminContact
          : (widget.role == UserRole.parent ? (s['parent_contact'] ?? '') : (s['contact_number'] ?? '')),
    );
    final addressCtrl = TextEditingController(
      text: widget.role == UserRole.admin ? _adminAddress : (s['address'] ?? ''),
    );

    // Teacher specific
    final specializationCtrl = TextEditingController(text: s['specialization'] ?? '');

    String? selectedGender = ['Male', 'Female', 'Other'].contains(s['gender']) ? s['gender'] : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          backgroundColor: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: theme.cardGradient,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Profile Details',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Update your personal & contact information',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Form Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Avatar Edit with Camera Action (Only visible when editing profile)
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: theme.primary.withValues(alpha: 0.3), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.primaryDark.withValues(alpha: 0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: AvatarUtils.buildAvatar(
                                      photo: _profilePicturePath,
                                      name: widget.role == UserRole.admin
                                          ? _adminName
                                          : (widget.role == UserRole.parent
                                              ? (s['parent_name'] ?? widget.username)
                                              : (s['name'] ?? widget.username)),
                                      radius: 40,
                                      foregroundColor: theme.primary,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: InkWell(
                                      onTap: () async {
                                        await _pickProfilePicture();
                                        setDialogState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: theme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
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
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: () async {
                                  await _pickProfilePicture();
                                  setDialogState(() {});
                                },
                                icon: Icon(Icons.camera_alt_rounded, size: 15, color: theme.primary),
                                label: Text(
                                  'Change Photo',
                                  style: TextStyle(
                                    color: theme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 18),
                        if (widget.role == UserRole.admin) ...[
                          _buildSectionTitle('Administrator Identity'),
                          const SizedBox(height: 12),
                          _dialogField('Full Name', adminNameCtrl, icon: Icons.person_outline_rounded),
                          const SizedBox(height: 14),
                          _dialogField('Admin ID', adminIdCtrl, icon: Icons.badge_outlined),
                          const SizedBox(height: 14),
                          _dialogField('Official Email', emailCtrl,
                              icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                          _dialogField('Department', departmentCtrl, icon: Icons.business_outlined),
                          const SizedBox(height: 20),
                          _buildSectionTitle('Contact Details'),
                          const SizedBox(height: 12),
                          _dialogField('Contact Number', contactCtrl,
                              icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 14),
                          _dialogField('Office / Residential Address', addressCtrl,
                              icon: Icons.location_on_outlined, maxLines: 2),
                        ] else ...[
                          _buildSectionTitle('Personal Information'),
                          const SizedBox(height: 12),
                          _dialogField('Full Name', nameCtrl, icon: Icons.person_outline_rounded),
                          const SizedBox(height: 14),
                          _dialogLabel('Gender'),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedGender,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                                hint: const Text('Select gender',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                                items: ['Male', 'Female', 'Other']
                                    .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (val) => setDialogState(() => selectedGender = val),
                              ),
                            ),
                          ),
                          if (widget.role == UserRole.teacher) ...[
                            const SizedBox(height: 14),
                            _dialogField('Specialization / Subject Focus', specializationCtrl,
                                icon: Icons.school_outlined),
                          ],
                          const SizedBox(height: 20),
                          _buildSectionTitle('Contact Details'),
                          const SizedBox(height: 12),
                          _dialogField('Contact Number', contactCtrl,
                              icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 14),
                          _dialogField('Residential Address', addressCtrl,
                              icon: Icons.home_outlined, maxLines: 2),
                        ],
                      ],
                    ),
                  ),
                ),

                // Actions Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Save Changes',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                        onPressed: () async {
                          if (widget.role == UserRole.admin) {
                            final newName = adminNameCtrl.text.trim().isEmpty ? _adminName : adminNameCtrl.text.trim();
                            final newId = adminIdCtrl.text.trim().isEmpty ? _adminId : adminIdCtrl.text.trim();
                            final newEmail = emailCtrl.text.trim().isEmpty ? _adminEmail : emailCtrl.text.trim();
                            final newDept = departmentCtrl.text.trim().isEmpty ? _adminDepartment : departmentCtrl.text.trim();
                            final newContact = contactCtrl.text.trim();
                            final newAddress = addressCtrl.text.trim();

                            try {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('admin_name_$newEmail', newName);
                              await prefs.setString('admin_id_$newEmail', newId);
                              await prefs.setString('admin_dept_$newEmail', newDept);
                              await prefs.setString('admin_contact_$newEmail', newContact);
                              await prefs.setString('admin_address_$newEmail', newAddress);
                            } catch (_) {}

                            setState(() {
                              _adminName = newName;
                              _adminId = newId;
                              _adminEmail = newEmail;
                              _adminDepartment = newDept;
                              _adminContact = newContact;
                              _adminAddress = newAddress;
                            });
                          } else if (widget.role == UserRole.teacher && _userData != null) {
                            if (nameCtrl.text.trim().isEmpty) return;
                            await DatabaseHelper().updateTeacher(
                              _userData!['id'],
                              name: nameCtrl.text.trim(),
                              gender: selectedGender,
                              contactNumber: contactCtrl.text.trim(),
                              address: addressCtrl.text.trim(),
                              specialization: specializationCtrl.text.trim(),
                            );
                          } else if (widget.role == UserRole.student && _userData != null) {
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
                              message: 'Your profile details have been successfully saved.',
                            );
                          }
                        },
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF64748B),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _dialogField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final theme = _getRoleTheme();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.primary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dialogLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[dt.month - 1];
    final day = dt.day;
    final year = dt.year;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year at $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getRoleTheme();

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.primary, strokeWidth: 3),
            const SizedBox(height: 16),
            const Text(
              'Loading profile information...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    String displayName = '';
    String displayEmail = '';
    String displayRole = '';
    String roleKey = 'admin';
    String idLabel = 'ID';
    String idValue = 'N/A';
    String departmentOrSection = '';
    String departmentOrSectionLabel = '';
    String contactNumber = '';
    String address = '';
    String gender = '';
    String extraHighlight = '';

    if (widget.role == UserRole.admin) {
      roleKey = widget.adminRoleTitle?.toLowerCase() ?? 'admin';
      displayName = _adminName;
      displayEmail = _adminEmail;
      displayRole = widget.adminRoleTitle != null && widget.adminRoleTitle!.isNotEmpty
          ? widget.adminRoleTitle!.toUpperCase()
          : 'Super Admin';
      idLabel = 'Admin ID';
      idValue = _adminId;
      departmentOrSectionLabel = 'Department';
      departmentOrSection = _adminDepartment;
      contactNumber = _adminContact;
      address = _adminAddress;
      extraHighlight = 'Full Root Clearance';
    } else if (widget.role == UserRole.teacher) {
      roleKey = 'teacher';
      displayName = _userData?['name']?.toString() ?? 'Faculty Teacher';
      displayEmail = _userData?['email']?.toString() ?? widget.username;
      displayRole = 'Faculty Teacher';
      idLabel = 'Teacher ID';
      idValue = _userData?['teacher_id']?.toString() ?? (_userData?['id']?.toString() ?? 'N/A');
      departmentOrSectionLabel = 'Department';
      departmentOrSection = _userData?['department']?.toString() ?? 'Academics';
      contactNumber = _userData?['contact_number']?.toString() ?? '';
      address = _userData?['address']?.toString() ?? '';
      gender = _userData?['gender']?.toString() ?? '';
      extraHighlight = _userData?['specialization']?.toString() ?? 'General Instruction';
    } else if (widget.role == UserRole.student) {
      roleKey = 'student';
      displayName = _userData?['name']?.toString() ?? 'Enrolled Student';
      displayEmail = _userData?['email']?.toString() ?? widget.username;
      displayRole = 'Student';
      idLabel = 'LRN / Student ID';
      idValue = _userData?['student_id']?.toString() ?? 'N/A';
      departmentOrSectionLabel = 'Grade & Section';
      final grade = _userData?['grade_level']?.toString() ?? '';
      final sec = _userData?['section']?.toString() ?? '';
      departmentOrSection = (grade.isNotEmpty || sec.isNotEmpty) ? '$grade • $sec' : 'Unassigned';
      contactNumber = _userData?['contact_number']?.toString() ?? '';
      address = _userData?['address']?.toString() ?? '';
      gender = _userData?['gender']?.toString() ?? '';
      extraHighlight = 'Regular Good Standing';
    } else if (widget.role == UserRole.parent) {
      roleKey = 'parent';
      displayName = _userData?['parent_name']?.toString() ?? 'Parent / Guardian';
      displayEmail = widget.username;
      displayRole = 'Parent Guardian';
      idLabel = 'Account Email';
      idValue = widget.username;
      departmentOrSectionLabel = 'Linked Children';
      departmentOrSection = '${_extraDataList.length} Student(s)';
      contactNumber = _userData?['parent_contact']?.toString() ?? '';
      extraHighlight = 'Parent Portal';
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Modern Hero Cover Banner & Avatar ──────────────────
                _buildHeroBanner(
                  theme: theme,
                  roleKey: roleKey,
                  displayName: displayName,
                  displayEmail: displayEmail,
                  displayRole: displayRole,
                  idLabel: idLabel,
                  idValue: idValue,
                  departmentLabel: departmentOrSectionLabel,
                  departmentValue: departmentOrSection,
                  contactNumber: contactNumber,
                  address: address,
                ),

                const SizedBox(height: 20),

                // ─── Stat Highlights Bar ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildQuickMetricsBar(
                    theme: theme,
                    displayRole: displayRole,
                    departmentValue: departmentOrSection,
                    extraHighlight: extraHighlight,
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Main Content Panels ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      // Role specific modules / classes / subjects
                      _buildRoleSpecificCard(theme),
                      const SizedBox(height: 20),

                      // Personal & Contact Information Card
                      _buildPersonalInfoCard(
                        theme: theme,
                        displayName: displayName,
                        displayEmail: displayEmail,
                        contactNumber: contactNumber,
                        address: address,
                        gender: gender,
                        idLabel: idLabel,
                        idValue: idValue,
                        deptLabel: departmentOrSectionLabel,
                        deptValue: departmentOrSection,
                      ),
                      const SizedBox(height: 20),

                      // Account Status & Security Card
                      _buildSecurityStatusCard(theme),
                      const SizedBox(height: 36),
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

  // ─── Hero Cover Banner with Overlapping Avatar Card ─────────────────────
  Widget _buildHeroBanner({
    required RoleColorScheme theme,
    required String roleKey,
    required String displayName,
    required String displayEmail,
    required String displayRole,
    required String idLabel,
    required String idValue,
    required String departmentLabel,
    required String departmentValue,
    required String contactNumber,
    required String address,
  }) {
    return Column(
      children: [
        // Top Gradient Cover
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: theme.appBarGradient,
            boxShadow: [
              BoxShadow(
                color: theme.primaryDark.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Ambient Decorative Circles
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 44),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: 140,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),

              // Banner Top Bar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Institutional Portal Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'OFFICIAL ACADEMIC PROFILE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit Profile Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showEditDialog,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Overlapping Identity Card
        Transform.translate(
          offset: const Offset(0, -42),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F0F172A),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;
                  return isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAvatarWidget(theme, displayName),
                            const SizedBox(height: 16),
                            _buildIdentityDetails(
                              theme: theme,
                              roleKey: roleKey,
                              displayName: displayName,
                              displayEmail: displayEmail,
                              displayRole: displayRole,
                              idLabel: idLabel,
                              idValue: idValue,
                              departmentLabel: departmentLabel,
                              departmentValue: departmentValue,
                              contactNumber: contactNumber,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAvatarWidget(theme, displayName),
                            const SizedBox(width: 22),
                            Expanded(
                              child: _buildIdentityDetails(
                                theme: theme,
                                roleKey: roleKey,
                                displayName: displayName,
                                displayEmail: displayEmail,
                                displayRole: displayRole,
                                idLabel: idLabel,
                                idValue: idValue,
                                departmentLabel: departmentLabel,
                                departmentValue: departmentValue,
                                contactNumber: contactNumber,
                              ),
                            ),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWidget(RoleColorScheme theme, String displayName) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.primaryDark.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AvatarUtils.buildAvatar(
            photo: _profilePicturePath,
            name: displayName,
            radius: 48,
            foregroundColor: theme.primary,
            backgroundColor: const Color(0xFFF1F5F9),
          ),
        ),
        // Verified Status Badge
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityDetails({
    required RoleColorScheme theme,
    required String roleKey,
    required String displayName,
    required String displayEmail,
    required String displayRole,
    required String idLabel,
    required String idValue,
    required String departmentLabel,
    required String departmentValue,
    required String contactNumber,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name & Role Badge Row
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            RoleTheme.buildRoleBadge(
              roleKey,
              fontSize: 10.5,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Metadata Chips Row (ID, Department, Active)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // ID Chip with Copy
            _buildInteractiveChip(
              icon: Icons.badge_outlined,
              label: '$idLabel: $idValue',
              theme: theme,
              onTap: () => _copyToClipboard(idValue, idLabel),
              tooltip: 'Click to copy $idLabel',
            ),

            // Department / Section Chip
            if (departmentValue.isNotEmpty && departmentValue != 'N/A')
              _buildStaticChip(
                icon: Icons.domain_rounded,
                label: '$departmentLabel: $departmentValue',
              ),

            // Active Account Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Text(
                    'Active & Verified',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Contact info quick row
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            InkWell(
              onTap: () => _copyToClipboard(displayEmail, 'Email'),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Text(
                    displayEmail,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (contactNumber.isNotEmpty)
              InkWell(
                onTap: () => _copyToClipboard(contactNumber, 'Phone'),
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      contactNumber,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractiveChip({
    required IconData icon,
    required String label,
    required RoleColorScheme theme,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: const Color(0xFF475569)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded, size: 11, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaticChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat Highlights Bar ────────────────────────────────────────────────
  Widget _buildQuickMetricsBar({
    required RoleColorScheme theme,
    required String displayRole,
    required String departmentValue,
    required String extraHighlight,
  }) {
    List<Map<String, dynamic>> stats = [];

    if (widget.role == UserRole.admin) {
      stats = [
        {
          'icon': Icons.security_rounded,
          'color': const Color(0xFF0284C7),
          'title': 'System Role',
          'value': displayRole,
          'subtitle': 'Executive Level',
        },
        {
          'icon': Icons.hub_rounded,
          'color': const Color(0xFF6366F1),
          'title': 'Clearance',
          'value': 'Full Clearance',
          'subtitle': 'All School Modules',
        },
        {
          'icon': Icons.domain_rounded,
          'color': const Color(0xFF059669),
          'title': 'Department',
          'value': departmentValue.isEmpty ? 'IT & Admin' : departmentValue,
          'subtitle': 'Institutional Control',
        },
        {
          'icon': Icons.lock_clock_rounded,
          'color': const Color(0xFFD97706),
          'title': 'Session State',
          'value': 'Active',
          'subtitle': 'Encrypted Portal',
        },
      ];
    } else if (widget.role == UserRole.teacher) {
      stats = [
        {
          'icon': Icons.class_rounded,
          'color': const Color(0xFF1E40AF),
          'title': 'Teaching Load',
          'value': '${_extraDataList.length} Classes',
          'subtitle': 'Current Semester',
        },
        {
          'icon': Icons.domain_rounded,
          'color': const Color(0xFF0284C7),
          'title': 'Department',
          'value': departmentValue,
          'subtitle': 'Academic Faculty',
        },
        {
          'icon': Icons.military_tech_rounded,
          'color': const Color(0xFF6366F1),
          'title': 'Specialization',
          'value': extraHighlight,
          'subtitle': 'Subject Focus',
        },
        {
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF059669),
          'title': 'Faculty Status',
          'value': 'Active Teacher',
          'subtitle': 'Authorized Instructor',
        },
      ];
    } else if (widget.role == UserRole.student) {
      stats = [
        {
          'icon': Icons.menu_book_rounded,
          'color': const Color(0xFF0096C7),
          'title': 'Enrolled Subjects',
          'value': '${_extraDataList.length} Subjects',
          'subtitle': 'Active Term',
        },
        {
          'icon': Icons.groups_rounded,
          'color': const Color(0xFF059669),
          'title': 'Section',
          'value': departmentValue,
          'subtitle': 'Assigned Cohort',
        },
        {
          'icon': Icons.verified_rounded,
          'color': const Color(0xFF6366F1),
          'title': 'Academic Status',
          'value': extraHighlight,
          'subtitle': 'Good Standing',
        },
        {
          'icon': Icons.lock_rounded,
          'color': const Color(0xFFD97706),
          'title': 'Student Portal',
          'value': 'Verified',
          'subtitle': 'Portal Ready',
        },
      ];
    } else {
      stats = [
        {
          'icon': Icons.family_restroom_rounded,
          'color': const Color(0xFF2B81B7),
          'title': 'Linked Children',
          'value': '${_extraDataList.length} Student(s)',
          'subtitle': 'Family Account',
        },
        {
          'icon': Icons.mark_email_read_rounded,
          'color': const Color(0xFF059669),
          'title': 'Notifications',
          'value': 'Real-time SMS/App',
          'subtitle': 'Grade Alerts Active',
        },
        {
          'icon': Icons.verified_user_rounded,
          'color': const Color(0xFF6366F1),
          'title': 'Guardian Status',
          'value': 'Verified Parent',
          'subtitle': 'Authorized Family',
        },
      ];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 600
            ? 1
            : (constraints.maxWidth < 950 ? 2 : stats.length);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 1 ? 4.5 : (crossAxisCount == 2 ? 3.0 : 2.4),
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final s = stats[index];
            final Color iconColor = s['color'] as Color;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x050F172A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(s['icon'] as IconData, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['title'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s['value'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          s['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF94A3B8),
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
          },
        );
      },
    );
  }

  // ─── Role Specific Card (Modules / Classes / Subjects) ──────────────────
  Widget _buildRoleSpecificCard(RoleColorScheme theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.role == UserRole.admin
                        ? Icons.shield_rounded
                        : (widget.role == UserRole.teacher ? Icons.school_rounded : Icons.menu_book_rounded),
                    color: theme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getRoleSpecificTitle(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getRoleSpecificSubtitle(),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.role == UserRole.admin ? '5 Modules' : '${_extraDataList.length} Items',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildRoleContent(theme),
          ),
        ],
      ),
    );
  }

  String _getRoleSpecificTitle() {
    switch (widget.role) {
      case UserRole.admin:
        return 'System Privileges & Managed Modules';
      case UserRole.teacher:
        return 'Assigned Classes & Academic Workload';
      case UserRole.student:
        return 'Enrolled Subjects & Class Schedule';
      case UserRole.parent:
        return 'Linked Students & Academic Overview';
    }
  }

  String _getRoleSpecificSubtitle() {
    switch (widget.role) {
      case UserRole.admin:
        return 'Authorized modules and administrative governance scope';
      case UserRole.teacher:
        return 'Active teaching schedule and class roster allocations';
      case UserRole.student:
        return 'Registered course curriculum and timetable schedule';
      case UserRole.parent:
        return 'Enrolled children and real-time attendance records';
    }
  }

  Widget _buildRoleContent(RoleColorScheme theme) {
    if (widget.role == UserRole.admin) {
      final modules = [
        {
          'icon': Icons.people_alt_rounded,
          'title': 'Student Information Management',
          'desc': 'Enrollment, personal profiles, academic history & document archival',
          'access': 'FULL ACCESS',
          'isFull': true,
        },
        {
          'icon': Icons.co_present_rounded,
          'title': 'Teacher Profiles & Assignments',
          'desc': 'Faculty directory, subject assignments, workload & advisory sections',
          'access': 'FULL ACCESS',
          'isFull': true,
        },
        {
          'icon': Icons.calendar_month_rounded,
          'title': 'Subject & Curriculum Scheduling',
          'desc': 'Timetable coordination, room allocation, course catalog & term calendars',
          'access': 'READ / WRITE',
          'isFull': false,
        },
        {
          'icon': Icons.insights_rounded,
          'title': 'Academic Evaluations & Analytics',
          'desc': 'Grade book oversight, mastery ratings, attendance trends & performance metrics',
          'access': 'READ / WRITE',
          'isFull': false,
        },
        {
          'icon': Icons.mark_email_read_rounded,
          'title': 'System Reports & Parent Notifications',
          'desc': 'Automated grade notifications, administrative audit logs & announcement broadcasting',
          'access': 'FULL ACCESS',
          'isFull': true,
        },
      ];

      return Column(
        children: modules.map((m) {
          final isFull = m['isFull'] as bool;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isFull
                        ? const Color(0xFFECFDF5)
                        : theme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    m['icon'] as IconData,
                    size: 20,
                    color: isFull ? const Color(0xFF059669) : theme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['title'] as String,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m['desc'] as String,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFull ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFull ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Text(
                    m['access'] as String,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isFull ? const Color(0xFF065F46) : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (widget.role == UserRole.teacher) {
      if (_extraDataList.isEmpty) {
        return _buildEmptyState(
          icon: Icons.school_outlined,
          title: 'No classes assigned yet',
          subtitle: 'Assigned subject sections and schedules will appear here.',
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final isMultiCol = constraints.maxWidth >= 650;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _extraDataList.map((c) {
              final subject = c['subject_name']?.toString() ?? 'Subject';
              final grade = c['grade_level']?.toString() ?? 'Grade';
              final section = c['section_name']?.toString() ?? 'Section';

              return Container(
                width: isMultiCol ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.menu_book_rounded, color: theme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  '$grade • $section',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Text(
                        'Active Class',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      );
    }

    if (widget.role == UserRole.student) {
      if (_extraDataList.isEmpty) {
        return _buildEmptyState(
          icon: Icons.menu_book_outlined,
          title: 'No subjects enrolled yet',
          subtitle: 'Your enrolled subjects and schedules will be displayed here.',
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final isMultiCol = constraints.maxWidth >= 650;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _extraDataList.map((s) {
              final subject = s['subject_name']?.toString() ?? 'Subject';
              final time = s['time']?.toString() ?? 'Schedule TBA';
              final room = s['room']?.toString() ?? 'Room TBA';

              return Container(
                width: isMultiCol ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.bookmark_rounded, color: theme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.meeting_room_outlined, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Text(room, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'Enrolled',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      );
    }

    if (widget.role == UserRole.parent) {
      if (_extraDataList.isEmpty) {
        return _buildEmptyState(
          icon: Icons.family_restroom_rounded,
          title: 'No linked children',
          subtitle: 'Students linked to your email address will appear here.',
        );
      }

      return Column(
        children: _extraDataList.map((child) {
          final name = child['name']?.toString() ?? 'Student';
          final id = child['student_id']?.toString() ?? 'LRN-TBA';
          final grade = child['grade_level']?.toString() ?? '';
          final sec = child['section']?.toString() ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                AvatarUtils.buildAvatar(
                  photo: child['profile_picture']?.toString(),
                  name: name,
                  radius: 20,
                  foregroundColor: theme.primary,
                  backgroundColor: const Color(0xFFE2E8F0),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('LRN: $id • Grade $grade - $sec', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Text('Enrolled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return const SizedBox();
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ─── Personal & Contact Information Card ────────────────────────────────
  Widget _buildPersonalInfoCard({
    required RoleColorScheme theme,
    required String displayName,
    required String displayEmail,
    required String contactNumber,
    required String address,
    required String gender,
    required String idLabel,
    required String idValue,
    required String deptLabel,
    required String deptValue,
  }) {
    final infoItems = [
      {
        'icon': Icons.person_outline_rounded,
        'label': 'Full Legal Name',
        'value': displayName,
      },
      {
        'icon': Icons.alternate_email_rounded,
        'label': 'Email Address',
        'value': displayEmail,
        'isVerified': true,
      },
      {
        'icon': Icons.badge_outlined,
        'label': idLabel,
        'value': idValue,
        'canCopy': true,
      },
      {
        'icon': Icons.business_outlined,
        'label': deptLabel,
        'value': deptValue.isEmpty ? 'Not assigned' : deptValue,
      },
      {
        'icon': Icons.phone_outlined,
        'label': 'Contact Number',
        'value': contactNumber.isEmpty ? 'Not provided' : contactNumber,
        'canCopy': contactNumber.isNotEmpty,
      },
      {
        'icon': Icons.home_outlined,
        'label': 'Residential / Office Address',
        'value': address.isEmpty ? 'Not specified' : address,
      },
      if (gender.isNotEmpty)
        {
          'icon': Icons.wc_rounded,
          'label': 'Gender',
          'value': gender,
        },
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.badge_rounded, color: theme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal & Contact Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Verified identity credentials and communication records',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Info Tiles Grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMultiCol = constraints.maxWidth >= 650;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: infoItems.map((item) {
                    final canCopy = item['canCopy'] == true;
                    final isVerified = item['isVerified'] == true;
                    final val = item['value'] as String;
                    final lbl = item['label'] as String;

                    return Container(
                      width: isMultiCol ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Icon(item['icon'] as IconData, size: 18, color: const Color(0xFF475569)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lbl,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        val,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isVerified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (canCopy)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF94A3B8)),
                              onPressed: () => _copyToClipboard(val, lbl),
                              tooltip: 'Copy $lbl',
                              splashRadius: 18,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Security & Account Activity Card ───────────────────────────────────
  Widget _buildSecurityStatusCard(RoleColorScheme theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security & Account Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Session telemetry and authentication integrity status',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Status Tiles
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMultiCol = constraints.maxWidth >= 650;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    // Account Status Tile
                    Container(
                      width: isMultiCol ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFECFDF5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 16),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Account Clearance',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              CircleAvatar(radius: 4, backgroundColor: Color(0xFF059669)),
                              SizedBox(width: 8),
                              Text(
                                'Active and verified',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Supabase Encrypted Cloud Auth • SHA-256 Protected',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                    // Last Access Telemetry Tile
                    Container(
                      width: isMultiCol ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.history_rounded, color: theme.primary, size: 16),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Last Access Telemetry',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatDateTime(_lastAccessTime),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Academic Management Portal • Secure Session',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
