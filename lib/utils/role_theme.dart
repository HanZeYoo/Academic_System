import 'package:flutter/material.dart';

/// Defines the distinct shade of blue and styling tokens for a specific user role.
class RoleColorScheme {
  final String roleKey;
  final String displayName;
  final String badgeText;

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

  /// Icon representing this user role
  final IconData icon;

  const RoleColorScheme({
    required this.roleKey,
    required this.displayName,
    required this.badgeText,
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
    required this.icon,
  });
}

/// Central design system managing distinct shades of blue for every user role.
class RoleTheme {
  RoleTheme._();

  // 1. Super Admin: Deep Midnight Navy Blue (Commanding, Secure, Authoritative)
  static const RoleColorScheme adminTheme = RoleColorScheme(
    roleKey: 'admin',
    displayName: 'Super Admin',
    badgeText: 'SUPER ADMIN',
    primary: Color(0xFF1E3A8A), // Midnight Navy Blue (Tailwind Blue 900)
    primaryDark: Color(0xFF0F1E36),
    drawerBackground: Color(0xFF0F1E36), // Deep Midnight Navy Drawer
    drawerHeader: Color(0xFF17294A),
    drawerSelected: Color(0xFF2563EB), // Vibrant Royal Navy highlight
    badgeBackground: Color(0x3360A5FA),
    badgeTextColor: Color(0xFF93C5FD), // Ice Blue
    scaffoldBackground: Color(0xFFEFF4F9),
    cardGradient: LinearGradient(
      colors: [Color(0xFF1E3A8A), Color(0xFF0F1E36)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    icon: Icons.admin_panel_settings,
  );

  // 2. Principal: Imperial Indigo-Navy Blue (Executive Leadership, Prestigious)
  static const RoleColorScheme principalTheme = RoleColorScheme(
    roleKey: 'principal',
    displayName: 'Principal',
    badgeText: 'PRINCIPAL',
    primary: Color(0xFF1D4ED8), // Royal Indigo Blue (Tailwind Blue 700)
    primaryDark: Color(0xFF132247),
    drawerBackground: Color(0xFF132247), // Deep Imperial Indigo-Navy Drawer
    drawerHeader: Color(0xFF1C2F5E),
    drawerSelected: Color(0xFF3B82F6),
    badgeBackground: Color(0x33818CF8),
    badgeTextColor: Color(0xFFA5B4FC), // Lavender Blue
    scaffoldBackground: Color(0xFFF0F4FA),
    cardGradient: LinearGradient(
      colors: [Color(0xFF1D4ED8), Color(0xFF132247)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    icon: Icons.workspace_premium,
  );

  // 3. Registrar: Steel Ocean Blue (Administrative Records, Precision)
  static const RoleColorScheme registrarTheme = RoleColorScheme(
    roleKey: 'registrar',
    displayName: 'Registrar',
    badgeText: 'REGISTRAR',
    primary: Color(0xFF0284C7), // Steel Ocean Blue (Tailwind Sky 600)
    primaryDark: Color(0xFF0C2D48),
    drawerBackground: Color(0xFF0C2D48), // Deep Steel Ocean Blue Drawer
    drawerHeader: Color(0xFF133E63),
    drawerSelected: Color(0xFF0EA5E9),
    badgeBackground: Color(0x3338BDF8),
    badgeTextColor: Color(0xFF7DD3FC), // Sky Blue
    scaffoldBackground: Color(0xFFF0F6FA),
    cardGradient: LinearGradient(
      colors: [Color(0xFF0284C7), Color(0xFF0C2D48)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    icon: Icons.badge_outlined,
  );

  // 4. Teacher: Classic Scholastic Sapphire Blue (Guiding, Scholarly, Trusted)
  static const RoleColorScheme teacherTheme = RoleColorScheme(
    roleKey: 'teacher',
    displayName: 'Teacher',
    badgeText: 'TEACHER',
    primary: Color(0xFF1565C0), // Classic Scholastic Sapphire (Material Blue 800)
    primaryDark: Color(0xFF0D47A1),
    drawerBackground: Color(0xFF0E2A47), // Rich Sapphire Navy Drawer
    drawerHeader: Color(0xFF163C63),
    drawerSelected: Color(0xFF1976D2), // Sapphire Blue highlight
    badgeBackground: Color(0x3364B5F6),
    badgeTextColor: Color(0xFF90CAF9), // Soft Sapphire Blue
    scaffoldBackground: Color(0xFFF0F5FA),
    cardGradient: LinearGradient(
      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    icon: Icons.co_present,
  );

  // 5. Student: Vibrant Cerulean & Sky Blue (Youthful, Energetic, Inspiring)
  static const RoleColorScheme studentTheme = RoleColorScheme(
    roleKey: 'student',
    displayName: 'Student',
    badgeText: 'STUDENT',
    primary: Color(0xFF0288D1), // Electric Sky Blue (Light Blue 700)
    primaryDark: Color(0xFF01579B),
    drawerBackground: Color(0xFF0B3354), // Deep Cerulean Ocean Drawer
    drawerHeader: Color(0xFF104672),
    drawerSelected: Color(0xFF039BE5), // Electric Sky Blue highlight
    badgeBackground: Color(0x334FC3F7),
    badgeTextColor: Color(0xFF81D4FA), // Bright Sky Blue
    scaffoldBackground: Color(0xFFEDF7FC),
    cardGradient: LinearGradient(
      colors: [Color(0xFF0288D1), Color(0xFF01579B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    icon: Icons.school,
  );

  // 6. Parent: Twilight Marine Slate Blue (Supportive, Calm, Family Guardian)
  static const RoleColorScheme parentTheme = RoleColorScheme(
    roleKey: 'parent',
    displayName: 'Parent',
    badgeText: 'PARENT',
    primary: Color(0xFF316395), // Warm Twilight Marine Blue
    primaryDark: Color(0xFF1E3A5F),
    drawerBackground: Color(0xFF1B2E48), // Twilight Slate Navy Drawer
    drawerHeader: Color(0xFF263F61),
    drawerSelected: Color(0xFF3B72A8), // Twilight Slate highlight
    badgeBackground: Color(0x3390CAF9),
    badgeTextColor: Color(0xFFBBDEFB), // Periwinkle Tint
    scaffoldBackground: Color(0xFFF2F6FA),
    cardGradient: LinearGradient(
      colors: [Color(0xFF316395), Color(0xFF1E3A5F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    icon: Icons.family_restroom,
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
