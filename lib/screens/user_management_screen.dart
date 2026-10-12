import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../services/email_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedTab = 'all';

  final List<Map<String, dynamic>> _tabs = [
    {'key': 'all', 'label': 'All Users', 'icon': Icons.people},
    {'key': 'admin', 'label': 'Admins & Staff', 'icon': Icons.admin_panel_settings},
    {'key': 'teacher', 'label': 'Teachers', 'icon': Icons.co_present},
    {'key': 'student', 'label': 'Students', 'icon': Icons.school},
    {'key': 'parent', 'label': 'Parents', 'icon': Icons.family_restroom},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabs[_tabController.index]['key'];
          _applyFilters();
        });
      }
    });
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await DatabaseHelper().getAllUsers();
      setState(() {
        _allUsers = users;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _allUsers;

    if (_selectedTab != 'all') {
      if (_selectedTab == 'admin') {
        filtered = filtered.where((u) {
          final r = (u['role'] ?? '').toString().toLowerCase();
          return r == 'admin' || r == 'principal' || r == 'registrar';
        }).toList();
      } else {
        filtered = filtered.where((u) => (u['role'] ?? '').toString().toLowerCase() == _selectedTab).toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((u) {
        final username = (u['username'] ?? '').toString().toLowerCase();
        final role = (u['role'] ?? '').toString().toLowerCase();
        return username.contains(q) || role.contains(q);
      }).toList();
    }

    _filteredUsers = filtered;
  }

  void _showAddAdminDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'admin';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String getRoleDescription() {
            switch (selectedRole) {
              case 'principal':
                return 'Principal Portal: Access to Overview Dashboard, Faculty & Classes, Academics & Failure Analytics, Announcements, and Reports.';
              case 'registrar':
                return 'Registrar Portal: Access to Student Records, Enrollment Status, Subjects & Classes Rosters, Official Reports, and Records Archive.';
              case 'admin':
              default:
                return 'Super Admin Portal: Full unrestricted access to all modules, User Management, and System Settings.';
            }
          }

          String getRoleTitle() {
            switch (selectedRole) {
              case 'principal':
                return 'Principal';
              case 'registrar':
                return 'Registrar';
              case 'admin':
              default:
                return 'Super Admin';
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.admin_panel_settings, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Text('Create Admin / Staff Account'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the administrative role to grant specific access privileges:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role / Privilege Level',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Super Admin (Full System Access)'),
                      ),
                      DropdownMenuItem(
                        value: 'principal',
                        child: Text('Principal / Vice Principal'),
                      ),
                      DropdownMenuItem(
                        value: 'registrar',
                        child: Text('School Registrar'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            getRoleDescription(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF4C1D95)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (oldVal, newVal) => newVal.copyWith(text: newVal.text.toLowerCase()),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      helperText: 'Minimum 8 characters',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        final password = passwordController.text;

                        if (email.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill in all fields.')),
                          );
                          return;
                        }
                        if (password.length < 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password must be at least 8 characters.')),
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);
                        try {
                          await DatabaseHelper().createAdminAccount(email, password, role: selectedRole);
                          final roleLabel = getRoleTitle();
                          await EmailService.sendEmail(
                            toEmail: email,
                            subject: '$roleLabel Account Created - Academic System',
                            messageText:
                                'Hello,<br><br>Your <b>$roleLabel</b> account for the Academic Management System has been created.<br><br><b>Role:</b> $roleLabel<br><b>Email:</b> $email<br><b>Password:</b> $password<br><br>Please log in and change your password upon initial sign-in.',
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$roleLabel account created and credentials sent!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadUsers();
                          }
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create & Send'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final role = user['role'] ?? 'user';
    final defaultPass = role == 'student'
        ? 'student123'
        : role == 'teacher'
            ? 'teacher123'
            : role == 'parent'
                ? 'parent123'
                : 'admin123';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Password'),
        content: Text(
            'This will reset the password for ${user['username']} to "$defaultPass". Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper().updatePassword(user['username'], defaultPass);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset to "$defaultPass" for ${user['username']}'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAdminDialog(Map<String, dynamic> user) {
    final role = (user['role'] ?? 'admin').toString().toLowerCase();
    final roleLabel = role == 'principal'
        ? 'Principal'
        : role == 'registrar'
            ? 'Registrar'
            : 'Admin';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete $roleLabel Account'),
          ],
        ),
        content: Text(
            'Are you sure you want to delete the $roleLabel account "${user['username']}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await DatabaseHelper().deleteUser(user['username']);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('$roleLabel account deleted.'), backgroundColor: Colors.red),
                  );
                  _loadUsers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return const Color(0xFF7C3AED);
      case 'principal':
        return const Color(0xFF4338CA);
      case 'registrar':
        return const Color(0xFF0D9488);
      case 'teacher':
        return const Color(0xFF0F52BA);
      case 'student':
        return const Color(0xFF10B981);
      case 'parent':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'principal':
        return Icons.workspace_premium;
      case 'registrar':
        return Icons.badge_outlined;
      case 'teacher':
        return Icons.co_present;
      case 'student':
        return Icons.school;
      case 'parent':
        return Icons.family_restroom;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminCount = _allUsers.where((u) {
      final r = (u['role'] ?? '').toString().toLowerCase();
      return r == 'admin' || r == 'principal' || r == 'registrar';
    }).length;
    final teacherCount = _allUsers.where((u) => u['role'] == 'teacher').length;
    final studentCount = _allUsers.where((u) => u['role'] == 'student').length;
    final parentCount = _allUsers.where((u) => u['role'] == 'parent').length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'User Management',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage all system accounts and access levels',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddAdminDialog,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add Admin / Staff'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard('Total Users', _allUsers.length.toString(), Icons.people,
                    const Color(0xFF0F52BA), const Color(0xFFDBEAFE)),
                const SizedBox(width: 10),
                _buildStatCard('Admins & Staff', adminCount.toString(), Icons.admin_panel_settings,
                    const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
                const SizedBox(width: 10),
                _buildStatCard('Teachers', teacherCount.toString(), Icons.co_present,
                    const Color(0xFF0F52BA), const Color(0xFFDBEAFE)),
                const SizedBox(width: 10),
                _buildStatCard('Students', studentCount.toString(), Icons.school,
                    const Color(0xFF10B981), const Color(0xFFD1FAE5)),
                const SizedBox(width: 10),
                _buildStatCard('Parents', parentCount.toString(), Icons.family_restroom,
                    const Color(0xFFF59E0B), const Color(0xFFFEF3C7)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search bar
          TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by email or role...',
              prefixIcon: const Icon(Icons.search, color: Colors.black54),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: const Color(0xFF0F52BA),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: _tabs
                  .map((t) => Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t['icon'] as IconData, size: 16),
                            const SizedBox(width: 6),
                            Text(t['label'] as String),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results found.'
                                  : 'No users in this category.',
                              style: const TextStyle(color: Colors.black38, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredUsers.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final user = _filteredUsers[i];
                          final role = user['role']?.toString() ?? '';
                          final username = user['username']?.toString() ?? '';
                          final roleColor = _roleColor(role);
                          final roleIcon = _roleIcon(role);

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: roleColor.withValues(alpha: 0.15),
                                child: Icon(roleIcon, color: roleColor, size: 22),
                              ),
                              title: Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        role == 'admin'
                                            ? 'SUPER ADMIN'
                                            : role == 'principal'
                                                ? 'PRINCIPAL'
                                                : role == 'registrar'
                                                    ? 'REGISTRAR'
                                                    : role.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: 'Reset Password',
                                    child: IconButton(
                                      icon: const Icon(Icons.lock_reset,
                                          color: Colors.orange, size: 20),
                                      onPressed: () => _showResetPasswordDialog(user),
                                    ),
                                  ),
                                  if (role == 'admin' || role == 'principal' || role == 'registrar')
                                    Tooltip(
                                      message: 'Delete Account',
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red, size: 20),
                                        onPressed: () => _showDeleteAdminDialog(user),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration:
                BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                Text(title,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
