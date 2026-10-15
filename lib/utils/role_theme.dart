import 'package:flutter/material.dart';

/// Defines the distinct shade of blue and styling tokens for a specific user role.
class RoleColorScheme {
  final String roleKey;
  final String displayName;
  final String badgeText;
  final String portalSubtitle;

  /// Primary blue shade (AppBar, primary actions, titles)
  final Color primary;

  /// Deepest tone of blue for gradients / shadows
  final Color primaryDark;

  /// Distinct shade of blue for the Navigation Drawer / Sidebar
  final Color drawerBackground;

  /// Header container background within the drawer
  final Color drawerHeader;

  /// Selected / active drawer item highlight color
  final Color drawerSelected;

  /// Text color for the selected drawer item
  final Color drawerSelectedText;

  /// Regular drawer text color
  final Color drawerText;

  /// Regular drawer icon color
  final Color drawerIcon;

  /// Drawer divider line color
  final Color drawerDivider;

  /// Role badge chip background
  final Color badgeBackground;

  /// Role badge chip text / border color
  final Color badgeTextColor;

  /// Harmonious light scaffold background tone
  final Color scaffoldBackground;

  /// Gradient for welcome banners or cards
  final LinearGradient cardGradient;

  /// LinearGradient for the Top AppBar
  final LinearGradient appBarGradient;

  /// Icon representing this user role
  final IconData icon;

  const RoleColorScheme({
    required this.roleKey,
    required this.displayName,
    required this.badgeText,
    this.portalSubtitle = '',
    required this.primary,
    required this.primaryDark,
    required this.drawerBackground,
    required this.drawerHeader,
    required this.drawerSelected,
    this.drawerSelectedText = Colors.white,
    this.drawerText = const Color(0xFFD1E3F8),
    this.drawerIcon = const Color(0xFFB0D0F4),
    this.drawerDivider = const Color(0x26FFFFFF),
    required this.badgeBackground,
    required this.badgeTextColor,
    required this.scaffoldBackground,
    required this.cardGradient,
    required this.appBarGradient,
    required this.icon,
  });
}

/// Central design system managing distinct shades of blue for every user role.
class RoleTheme {
  RoleTheme._();

  // 1. Super Admin: Superior Obsidian Midnight Navy (Executive, Sovereign, Commanding Authority)
  static const RoleColorScheme adminTheme = RoleColorScheme(
    roleKey: 'admin',
    displayName: 'Super Admin',
    badgeText: 'SUPER ADMIN',
    portalSubtitle: 'Supreme Executive Command',
    primary: Color(0xFF0A192F), // Obsidian Midnight Navy
    primaryDark: Color(0xFF050E1C),
    drawerBackground: Color(0xFF060F1E), // Deepest Sovereign Obsidian Drawer
    drawerHeader: Color(0xFF0B1B33),
    drawerSelected: Color(0xFF1D4ED8), // Royal Blue highlight
    drawerText: Color(0xFFCBD5E1),
    drawerIcon: Color(0xFF94A3B8),
    badgeBackground: Color(0x333B82F6),
    badgeTextColor: Color(0xFF93C5FD), // Ice-Diamond Blue
    scaffoldBackground: Color(0xFFEFF3F8),
    cardGradient: LinearGradient(
      colors: [Color(0xFF0A1E3F), Color(0xFF050E1C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    appBarGradient: LinearGradient(
      colors: [Color(0xFF060F1E), Color(0xFF0A192F), Color(0xFF0F264A)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    icon: Icons.admin_panel_settings,
  );

  // 2. Principal: Regal Imperial Indigo-Navy (Executive School Leadership, Prestigious)
  static const RoleColorScheme principalTheme = RoleColorScheme(
    roleKey: 'principal',
    displayName: 'Principal',
    badgeText: 'PRINCIPAL',
    portalSubtitle: 'Executive Leadership Portal',
    primary: Color(0xFF1E3A8A), // Regal Indigo-Navy
    primaryDark: Color(0xFF0E1E42),
    drawerBackground: Color(0xFF0A1938), // Imperial Indigo-Navy Drawer
    drawerHeader: Color(0xFF12244E),
    drawerSelected: Color(0xFF2563EB),
    drawerText: Color(0xFFD5DEE9),
    drawerIcon: Color(0xFFA5B4FC),
    badgeBackground: Color(0x33818CF8),
    badgeTextColor: Color(0xFFA5B4FC), // Lavender Blue
    scaffoldBackground: Color(0xFFF0F4FA),
    cardGradient: LinearGradient(
      colors: [Color(0xFF1E3A8A), Color(0xFF0E1E42)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    appBarGradient: LinearGradient(
      colors: [Color(0xFF0E1E42), Color(0xFF1E3A8A), Color(0xFF2563EB)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    icon: Icons.workspace_premium,
  );

  // 3. Registrar: Steel Slate Ocean Blue (Records Management, Administrative Precision)
  static const RoleColorScheme registrarTheme = RoleColorScheme(
    roleKey: 'registrar',
    displayName: 'Registrar',
    badgeText: 'REGISTRAR',
    portalSubtitle: 'Records & Enrollment Portal',
    primary: Color(0xFF0369A1), // Steel Ocean Slate
    primaryDark: Color(0xFF082F49),
    drawerBackground: Color(0xFF082842), // Deep Steel Ocean Drawer
    drawerHeader: Color(0xFF0E385C),
    drawerSelected: Color(0xFF0284C7),
    drawerText: Color(0xFFE0F2FE),
    drawerIcon: Color(0xFF7DD3FC),
    badgeBackground: Color(0x3338BDF8),
    badgeTextColor: Color(0xFF7DD3FC), // Sky Steel Blue
    scaffoldBackground: Color(0xFFF0F6FA),
    cardGradient: LinearGradient(
      colors: [Color(0xFF0369A1), Color(0xFF082F49)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    appBarGradient: LinearGradient(
      colors: [Color(0xFF082842), Color(0xFF0369A1), Color(0xFF0284C7)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    icon: Icons.badge_outlined,
  );

  // 4. Teacher: Classic Scholastic Sapphire Navy (Same institutional vibe, but lower authority / classroom-focused)
  static const RoleColorScheme teacherTheme = RoleColorScheme(
    roleKey: 'teacher',
    displayName: 'Teacher',
    badgeText: 'FACULTY TEACHER',
    portalSubtitle: 'Faculty & Classroom Instruction',
    primary: Color(0xFF1E40AF), // Scholastic Royal Sapphire (Tailwind Blue 800)
    primaryDark: Color(0xFF172554),
    drawerBackground: Color(0xFF112D4E), // Warm Academic Sapphire Navy Drawer
    drawerHeader: Color(0xFF1A3F6B),
    drawerSelected: Color(0xFF2563EB), // Sapphire Blue highlight
    drawerText: Color(0xFFD8E6F8),
    drawerIcon: Color(0xFFA5C9F3),
    badgeBackground: Color(0x3360A5FA),
    badgeTextColor: Color(0xFFBFDBFE), // Soft Sapphire Tint
    scaffoldBackground: Color(0xFFF1F5F9),
    cardGradient: LinearGradient(
      colors: [Color(0xFF1E40AF), Color(0xFF172554)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    appBarGradient: LinearGradient(
      colors: [Color(0xFF172554), Color(0xFF1E40AF), Color(0xFF2563EB)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    icon: Icons.co_present,
  );

  // 5. Student: Cheerful Electric Cerulean & Cyan-Sky Blue (Friendly, Youthful, Energetic, Inspiring)
  static const RoleColorScheme studentTheme = RoleColorScheme(
    roleKey: 'student',
    displayName: 'Student',
    badgeText: 'STUDENT PORTAL',
    portalSubtitle: 'Learning Journey & Growth',
    primary: Color(0xFF0096C7), // Bright Friendly Electric Cerulean (Vivid Sky Blue)
    primaryDark: Color(0xFF0077B6),
    drawerBackground: Color(0xFF075985), // Vibrant Bright Cerulean Ocean Drawer (Tailwind Sky 800)
    drawerHeader: Color(0xFF0369A1),
    drawerSelected: Color(0xFF0EA5E9), // Vivid Electric Cyan-Sky highlight
    drawerText: Color(0xFFF0F9FF),
    drawerIcon: Color(0xFFBAE6FD),
    badgeBackground: Color(0x3338BDF8),
    badgeTextColor: Color(0xFF67E8F9), // Electric Cyan
    scaffoldBackground: Color(0xFFF0F9FF), // Bright energizing sky tint
    cardGradient: LinearGradient(
      colors: [Color(0xFF0096C7), Color(0xFF0077B6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    appBarGradient: LinearGradient(
      colors: [Color(0xFF0077B6), Color(0xFF0096C7), Color(0xFF00B4D8)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    icon: Icons.school_rounded,
  );

  // 6. Parent: Soft Light Marine Sky Blue (More Lighter, Approachable, Calm, Family Guardian)
  static const RoleColorScheme parentTheme = RoleColorScheme(
    roleKey: 'parent',
    displayName: 'Parent',
    badgeText: 'PARENT PORTAL',
    portalSubtitle: 'Family & Home Collaboration',
    primary: Color(0xFF2B81B7), // Soft Light Marine Sky Blue
    primaryDark: Color(0xFF1C5982),
    drawerBackground: Color(0xFF1E4870), // Soft Lighter Twilight Marine Drawer (Visibly much lighter)
    drawerHeader: Color(0xFF2B5C8A),
    drawerSelected: Color(0xFF3892C8), // Soft Morning Sky highlight
    drawerText: Color(0xFFE6F2FA),
    drawerIcon: Color(0xFFBCE0F5),
    badgeBackground: Color(0x33BAE6FD),
    badgeTextColor: Color(0xFFBAE6FD), // Soft Morning Sky Tint
    scaffoldBackground: Color(0xFFF4F9FD), // Airy, welcoming, comforting sky tint
    cardGradient: LinearGradient(
      colors: [Color(0xFF358FC5), Color(0xFF1F5E87)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    appBarGradient: LinearGradient(
      colors: [Color(0xFF1F5E87), Color(0xFF2B81B7), Color(0xFF3A94CC)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    icon: Icons.family_restroom_rounded,
  );

  /// Returns the corresponding [RoleColorScheme] for any role string.
  static RoleColorScheme getRoleTheme(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'admin':
      case 'superadmin':
      case 'super_admin':
        return adminTheme;
      case 'principal':
        return principalTheme;
      case 'registrar':
        return registrarTheme;
      case 'teacher':
      case 'faculty':
        return teacherTheme;
      case 'student':
        return studentTheme;
      case 'parent':
      case 'guardian':
        return parentTheme;
      default:
        return adminTheme;
    }
  }

  /// Builds a prominent, polished role badge pill for use in drawers, headers, or lists.
  static Widget buildRoleBadge(
    String? role, {
    double fontSize = 10,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  }) {
    final theme = getRoleTheme(role);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.badgeBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.badgeTextColor.withValues(alpha: 0.6),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.icon, size: fontSize + 2, color: theme.badgeTextColor),
          const SizedBox(width: 4),
          Text(
            theme.badgeText,
            style: TextStyle(
              color: theme.badgeTextColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
