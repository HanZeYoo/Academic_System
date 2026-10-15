import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database_helper.dart';
import 'admin_overview_screen.dart';
import 'student_management_screen.dart';
import 'teacher_management_screen.dart';
import 'subject_class_screen.dart';
import 'academic_evaluation_screen.dart';
import 'performance_analytics_screen.dart';
import 'parent_notification_screen.dart';
import 'reports_generation_screen.dart';
import 'announcement_management_screen.dart';
import 'shared_profile_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'admin_archive_screen.dart';
import 'user_management_screen.dart';
import 'enrollment_management_screen.dart';
import '../utils/role_theme.dart';

class AdminDashboard extends StatefulWidget {
  final String username;
  final String adminRole;
  const AdminDashboard({super.key, this.username = 'admin', this.adminRole = 'admin'});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminTabItem {
  final String title;
  final IconData icon;
  const _AdminTabItem({required this.title, required this.icon});
}

class _DashboardMenuItem {
  final String key;
  final String title;
  final String appBarTitle;
  final IconData icon;
  final Widget Function() builder;

  const _DashboardMenuItem({
    required this.key,
    required this.title,
    required this.appBarTitle,
    required this.icon,
    required this.builder,
  });
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isProfileOpen = false;
  late String _currentRole;

  // Active sub-tab indices for tabbed modules
  int _studentsSubTab = 0;
  int _facultySubTab = 0;
  int _academicsSubTab = 0;
  int _commsSubTab = 0;
  int _systemSubTab = 0;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.adminRole;
    if (_currentRole == 'admin' && widget.username != 'admin') {
      _fetchUserRole();
    }
  }

  Future<void> _fetchUserRole() async {
    try {
      final u = await DatabaseHelper().getUserByUsername(widget.username);
      if (u != null && u['role'] != null && mounted) {
        final r = u['role'].toString();
        if (r != _currentRole) {
          setState(() {
            _currentRole = r;
          });
        }
      }
    } catch (_) {}
  }

  Future<bool> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _getPortalTitle() {
    final role = _currentRole.toLowerCase();
    if (role == 'principal') return 'Principal Portal';
    if (role == 'registrar') return 'Registrar Portal';
    return 'Admin Portal';
  }

  String _getRoleBadgeText() {
    final role = _currentRole.toLowerCase();
    if (role == 'principal') return 'PRINCIPAL';
    if (role == 'registrar') return 'REGISTRAR';
    return 'SUPER ADMIN';
  }

  Color _getRoleBadgeColor() {
    return RoleTheme.getRoleTheme(_currentRole).badgeTextColor;
  }

  String _getAppBarTitle(List<_DashboardMenuItem> menuItems) {
    if (_isProfileOpen) return 'My Profile';
    if (_selectedIndex >= 0 && _selectedIndex < menuItems.length) {
      return menuItems[_selectedIndex].appBarTitle;
    }
    return _getPortalTitle();
  }

  List<_DashboardMenuItem> _getMenuItems() {
    final role = _currentRole.toLowerCase();
    if (role == 'principal') {
      return [
        _DashboardMenuItem(
          key: 'dashboard',
          title: 'Dashboard',
          appBarTitle: 'Principal Dashboard Overview',
          icon: Icons.dashboard_rounded,
          builder: () => const AdminOverviewScreen(),
        ),
        _DashboardMenuItem(
          key: 'faculty',
          title: 'Faculty & Classes',
          appBarTitle: 'Faculty & Classes',
          icon: Icons.co_present_rounded,
          builder: () => _buildFacultyModule(),
        ),
        _DashboardMenuItem(
          key: 'academics',
          title: 'Academics & Grades',
          appBarTitle: 'Academics & Performance Analytics',
          icon: Icons.assignment_turned_in_rounded,
          builder: () => _buildAcademicsModule(),
        ),
        _DashboardMenuItem(
          key: 'communications',
          title: 'Communications',
          appBarTitle: 'School Communications',
          icon: Icons.campaign_rounded,
          builder: () => _buildCommunicationsModule(),
        ),
        _DashboardMenuItem(
          key: 'reports',
          title: 'Reports',
          appBarTitle: 'Reports & Academic Analytics',
          icon: Icons.pie_chart_rounded,
          builder: () => ReportsGenerationScreen(username: widget.username),
        ),
      ];
    } else if (role == 'registrar') {
      return [
        _DashboardMenuItem(
          key: 'dashboard',
          title: 'Dashboard',
          appBarTitle: 'Registrar Dashboard Overview',
          icon: Icons.dashboard_rounded,
          builder: () => const AdminOverviewScreen(),
        ),
        _DashboardMenuItem(
          key: 'students',
          title: 'Students & Enrollment',
          appBarTitle: 'Student Records & Enrollment',
          icon: Icons.people_alt_rounded,
          builder: () => _buildStudentsModule(),
        ),
        _DashboardMenuItem(
          key: 'classes',
          title: 'Subjects & Classes',
          appBarTitle: 'Subjects & Class Rosters',
          icon: Icons.menu_book_outlined,
          builder: () => const SubjectClassScreen(),
        ),
        _DashboardMenuItem(
          key: 'reports',
          title: 'Official Reports',
          appBarTitle: 'Official Reports & Records',
          icon: Icons.pie_chart_rounded,
          builder: () => ReportsGenerationScreen(username: widget.username),
        ),
        _DashboardMenuItem(
          key: 'archive',
          title: 'Records Archive',
          appBarTitle: 'Student & Records Archive',
          icon: Icons.archive_outlined,
          builder: () => const AdminArchiveScreen(),
        ),
      ];
    } else {
      // Super Admin (Full access to all 7 modules)
      return [
        _DashboardMenuItem(
          key: 'dashboard',
          title: 'Dashboard',
          appBarTitle: 'Dashboard Overview',
          icon: Icons.dashboard_rounded,
          builder: () => const AdminOverviewScreen(),
        ),
        _DashboardMenuItem(
          key: 'students',
          title: 'Students',
          appBarTitle: 'Student Management',
          icon: Icons.people_alt_rounded,
          builder: () => _buildStudentsModule(),
        ),
        _DashboardMenuItem(
          key: 'faculty',
          title: 'Faculty & Classes',
          appBarTitle: 'Faculty & Classes',
          icon: Icons.co_present_rounded,
          builder: () => _buildFacultyModule(),
        ),
        _DashboardMenuItem(
          key: 'academics',
          title: 'Academics & Grades',
          appBarTitle: 'Academics & Grades',
          icon: Icons.assignment_turned_in_rounded,
          builder: () => _buildAcademicsModule(),
        ),
        _DashboardMenuItem(
          key: 'communications',
          title: 'Communications',
          appBarTitle: 'Communications',
          icon: Icons.campaign_rounded,
          builder: () => _buildCommunicationsModule(),
        ),
        _DashboardMenuItem(
          key: 'reports',
          title: 'Reports',
          appBarTitle: 'Reports Generation',
          icon: Icons.pie_chart_rounded,
          builder: () => ReportsGenerationScreen(username: widget.username),
        ),
        _DashboardMenuItem(
          key: 'system',
          title: 'System Management',
          appBarTitle: 'System Administration',
          icon: Icons.admin_panel_settings_rounded,
          builder: () => _buildSystemModule(),
        ),
      ];
    }
  }

  Widget _buildStudentsModule() {
    return Column(
      children: [
        _buildSubTabBar(
          tabs: const [
            _AdminTabItem(title: 'Student Records', icon: Icons.people_outline),
            _AdminTabItem(title: 'Enrollment Status', icon: Icons.how_to_reg_outlined),
          ],
          activeIndex: _studentsSubTab,
          onTabSelected: (index) => setState(() => _studentsSubTab = index),
        ),
        Expanded(
          child: _studentsSubTab == 0
              ? const StudentManagementScreen()
              : const EnrollmentManagementScreen(),
        ),
      ],
    );
  }

  Widget _buildFacultyModule() {
    return Column(
      children: [
        _buildSubTabBar(
          tabs: const [
            _AdminTabItem(title: 'Teachers', icon: Icons.badge_outlined),
            _AdminTabItem(title: 'Subject & Classes', icon: Icons.menu_book_outlined),
          ],
          activeIndex: _facultySubTab,
          onTabSelected: (index) => setState(() => _facultySubTab = index),
        ),
        Expanded(
          child: _facultySubTab == 0
              ? const TeacherManagementScreen()
              : const SubjectClassScreen(),
        ),
      ],
    );
  }

  Widget _buildAcademicsModule() {
    return Column(
      children: [
        _buildSubTabBar(
          tabs: const [
            _AdminTabItem(title: 'Academic Evaluation', icon: Icons.assignment_turned_in_outlined),
            _AdminTabItem(title: 'Performance Analytics', icon: Icons.insights_outlined),
          ],
          activeIndex: _academicsSubTab,
          onTabSelected: (index) => setState(() => _academicsSubTab = index),
        ),
        Expanded(
          child: _academicsSubTab == 0
              ? AcademicEvaluationScreen(username: widget.username, role: _currentRole)
              : PerformanceAnalyticsScreen(username: widget.username),
        ),
      ],
    );
  }

  Widget _buildCommunicationsModule() {
    return Column(
      children: [
        _buildSubTabBar(
          tabs: const [
            _AdminTabItem(title: 'School Announcements', icon: Icons.campaign_outlined),
            _AdminTabItem(title: 'Parent Notices', icon: Icons.notifications_active_outlined),
          ],
          activeIndex: _commsSubTab,
          onTabSelected: (index) => setState(() => _commsSubTab = index),
        ),
        Expanded(
          child: _commsSubTab == 0
              ? AnnouncementManagementScreen(username: widget.username, role: _currentRole)
              : ParentNotificationScreen(username: widget.username),
        ),
      ],
    );
  }

  Widget _buildSystemModule() {
    return Column(
      children: [
        _buildSubTabBar(
          tabs: const [
            _AdminTabItem(title: 'User Accounts', icon: Icons.manage_accounts_outlined),
            _AdminTabItem(title: 'Archive & Bin', icon: Icons.archive_outlined),
            _AdminTabItem(title: 'System Settings', icon: Icons.settings_outlined),
          ],
          activeIndex: _systemSubTab,
          onTabSelected: (index) => setState(() => _systemSubTab = index),
        ),
        Expanded(
          child: _systemSubTab == 0
              ? const UserManagementScreen()
              : _systemSubTab == 1
                  ? const AdminArchiveScreen()
                  : SettingsScreen(username: widget.username, role: 'admin'),
        ),
      ],
    );
  }

  Widget _buildSubTabBar({
    required List<_AdminTabItem> tabs,
    required int activeIndex,
    required ValueChanged<int> onTabSelected,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: Colors.blueGrey.shade100, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final isSelected = activeIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () => onTabSelected(index),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2B81B7) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2B81B7) : Colors.grey.shade300,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF2B81B7).withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBody(List<_DashboardMenuItem> menuItems) {
    if (_isProfileOpen) {
      return SharedProfileScreen(username: widget.username, role: UserRole.admin);
    }
    if (_selectedIndex >= 0 && _selectedIndex < menuItems.length) {
      return menuItems[_selectedIndex].builder();
    }
    return const Center(child: Text('Screen not found.'));
  }

  Widget _buildMenuItem(
    int index,
    IconData icon,
    String title,
    Color hoveredColor,
    bool isDesktop,
  ) {
    bool isSelected = !_isProfileOpen && _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? hoveredColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: Colors.white, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _isProfileOpen = false;
          });
          if (!isDesktop) {
            Navigator.pop(context); // Close drawer on mobile
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleTheme = RoleTheme.getRoleTheme(_currentRole);
    final Color appBarColor = roleTheme.primary;
    final Color drawerColor = roleTheme.drawerBackground;
    final Color hoveredColor = roleTheme.drawerSelected;
    final Color backgroundColor = roleTheme.scaffoldBackground;
    const Color textWhite = Colors.white;

    final menuItems = _getMenuItems();
    if (_selectedIndex >= menuItems.length) {
      _selectedIndex = 0;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isProfileOpen) {
          setState(() {
            _isProfileOpen = false;
          });
          return;
        }
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }
        final shouldLogout = await _showLogoutDialog();
        if (!context.mounted) return;
        if (shouldLogout) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen(isLoggingOut: true)),
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;

          Widget drawerContent = Column(
            children: [
              Container(
                padding: const EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 16,
                  bottom: 20,
                ),
                decoration: BoxDecoration(
                  color: roleTheme.drawerHeader,
                  border: const Border(
                    bottom: BorderSide(color: Colors.white24, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 24,
                      width: 24,
                      color: textWhite,
                      colorBlendMode: BlendMode.srcIn,
                      errorBuilder: (_, _, _) => const Icon(Icons.school, color: textWhite, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getPortalTitle(),
                            style: const TextStyle(
                              color: textWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: roleTheme.badgeBackground,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: roleTheme.badgeTextColor.withValues(alpha: 0.7),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleTheme.icon, size: 11, color: roleTheme.badgeTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  _getRoleBadgeText(),
                                  style: TextStyle(
                                    color: roleTheme.badgeTextColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDesktop)
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: textWhite,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: List.generate(menuItems.length, (i) {
                    final item = menuItems[i];
                    return _buildMenuItem(i, item.icon, item.title, hoveredColor, isDesktop);
                  }),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white24, width: 0.5),
                  ),
                ),
                child: ListTile(
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Icon(Icons.logout, color: textWhite),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: textWhite, fontSize: 15),
                  ),
                  onTap: () async {
                    final logout = await _showLogoutDialog();
                    if (!context.mounted) return;
                    if (logout) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(isLoggingOut: true),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          );

          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              backgroundColor: appBarColor,
              elevation: 0,
              flexibleSpace: Container(
                decoration: BoxDecoration(gradient: roleTheme.appBarGradient),
              ),
              automaticallyImplyLeading: !isDesktop,
              iconTheme: const IconThemeData(color: textWhite),
              title: isDesktop
                  ? Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 24,
                          width: 24,
                          color: textWhite,
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (_, _, _) => const Icon(Icons.school, color: textWhite, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Academic Management System - ${_getAppBarTitle(menuItems)}',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _getAppBarTitle(menuItems),
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _isProfileOpen = true;
                      });
                    },
                    child: Tooltip(
                      message: 'My Profile',
                      child: CircleAvatar(
                        backgroundColor: _isProfileOpen ? Colors.amber : Colors.white,
                        child: const Icon(Icons.person, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            drawer: !isDesktop
                ? Drawer(
                    backgroundColor: drawerColor,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    child: SafeArea(child: drawerContent),
                  )
                : null,
            body: Row(
              children: [
                if (isDesktop)
                  Container(
                    width: 250,
                    color: drawerColor,
                    child: SafeArea(child: drawerContent),
                  ),
                Expanded(
                  child: _buildBody(menuItems),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
