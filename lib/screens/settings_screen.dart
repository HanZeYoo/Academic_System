import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'school_year_rollover_screen.dart';

const List<String> _kQuarters = [
  '1st Term',
  '2nd Term',
  '3rd Term',
];

class SettingsScreen extends StatefulWidget {
  final String username;
  const SettingsScreen({super.key, this.username = 'admin'});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Grading Deadlines state
  bool _deadlinesLoading = true;
  bool _deadlinesSaving = false;
  List<Map<String, dynamic>> _deadlines = [];
  // Local editable values: quarter -> {startDate, endDate, extendedUntil}
  final Map<String, Map<String, String?>> _deadlineEdits = {};

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDeadlines();
  }

  Future<void> _loadDeadlines() async {
    setState(() => _deadlinesLoading = true);
    final data = await DatabaseHelper().getGradingDeadlines();
    // Seed local edits from DB
    for (final q in _kQuarters) {
      final found = data.where((d) => d['quarter'] == q).firstOrNull;
      _deadlineEdits[q] = {
        'start_date': found?['start_date']?.toString(),
        'end_date': found?['end_date']?.toString(),
        'extended_until': found?['extended_until']?.toString(),
      };
    }
    setState(() {
      _deadlines = data;
      _deadlinesLoading = false;
    });
  }

  Future<void> _saveDeadline(String quarter) async {
    final edit = _deadlineEdits[quarter];
    if (edit == null || edit['start_date'] == null || edit['end_date'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both start and end dates.')),
      );
      return;
    }
    setState(() => _deadlinesSaving = true);
    try {
      await DatabaseHelper().saveGradingDeadline(
        quarter: quarter,
        startDate: edit['start_date']!,
        endDate: edit['end_date']!,
        extendedUntil: edit['extended_until'],
      );
      await _loadDeadlines();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$quarter deadline saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _deadlinesSaving = false);
  }

  Future<DateTime?> _pickDate(BuildContext context, {DateTime? initial}) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1E66B4)),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields.')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirm password do not match!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Verify current password first
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.login(widget.username, currentPassword);

    if (user == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect current password!'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Update to new password
    await dbHelper.updatePassword(widget.username, newPassword);

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
      );
      
      // Clear fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSecurityCard(),
          const SizedBox(height: 24),
          _buildGradingDeadlinesCard(),
          const SizedBox(height: 24),
          _buildExtraSettingsCard(),
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
          child: const Icon(Icons.settings, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E66B4),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, color: Color(0xFF1E66B4)),
                  const SizedBox(width: 8),
                  const Text(
                    'Security & Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'User: ${widget.username}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Ensure your account is using a long, random password to stay secure.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildPasswordField(
            label: 'Current Password',
            hint: 'Enter your current password',
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            onToggleVisibility: () {
              setState(() {
                _obscureCurrent = !_obscureCurrent;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            label: 'New Password',
            hint: 'Enter your new password',
            controller: _newPasswordController,
            obscureText: _obscureNew,
            onToggleVisibility: () {
              setState(() {
                _obscureNew = !_obscureNew;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            label: 'Confirm New Password',
            hint: 'Re-enter your new password',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            onToggleVisibility: () {
              setState(() {
                _obscureConfirm = !_obscureConfirm;
              });
            },
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66B4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Text(
                    'Change Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1E66B4)),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradingDeadlinesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lock_clock, color: Color(0xFF1E66B4)),
              SizedBox(width: 8),
              Text(
                'Grading Deadlines',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Set the encoding period for each quarter. Teachers can only encode scores within the set dates.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (_deadlinesLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ))
          else
            ...(_kQuarters.map((quarter) => _buildQuarterDeadlineTile(quarter))),
        ],
      ),
    );
  }

  Widget _buildQuarterDeadlineTile(String quarter) {
    final edit = _deadlineEdits[quarter] ?? {};
    final startStr = edit['start_date'];
    final endStr = edit['end_date'];
    final extStr = edit['extended_until'];

    DateTime? startDt = startStr != null ? DateTime.tryParse(startStr) : null;
    DateTime? endDt = endStr != null ? DateTime.tryParse(endStr) : null;
    DateTime? extDt = extStr != null ? DateTime.tryParse(extStr) : null;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Determine status
    String status = 'Not Set';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.circle_outlined;

    if (startDt != null && endDt != null) {
      final s = DateTime(startDt.year, startDt.month, startDt.day);
      final e = DateTime(endDt.year, endDt.month, endDt.day);
      if (todayDate.isAfter(s.subtract(const Duration(days: 1))) &&
          todayDate.isBefore(e.add(const Duration(days: 1)))) {
        status = 'Open';
        statusColor = Colors.green;
        statusIcon = Icons.lock_open;
      } else if (todayDate.isBefore(s)) {
        status = 'Not Yet Started';
        statusColor = Colors.blueGrey;
        statusIcon = Icons.hourglass_empty;
      } else {
        // Check extension
        if (extDt != null) {
          final ext = DateTime(extDt.year, extDt.month, extDt.day);
          if (todayDate.isBefore(ext.add(const Duration(days: 1)))) {
            status = 'Extended';
            statusColor = Colors.orange;
            statusIcon = Icons.update;
          } else {
            status = 'Closed';
            statusColor = Colors.red;
            statusIcon = Icons.lock;
          }
        } else {
          status = 'Closed';
          statusColor = Colors.red;
          statusIcon = Icons.lock;
        }
      }
    }

    String _fmt(DateTime? dt) => dt == null
        ? 'Not set'
        : '${dt.month}/${dt.day}/${dt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                quarter,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDateTile(
                  label: 'Start Date',
                  value: _fmt(startDt),
                  icon: Icons.calendar_today,
                  onTap: () async {
                    final picked = await _pickDate(context, initial: startDt);
                    if (picked != null) {
                      setState(() {
                        _deadlineEdits[quarter]!['start_date'] =
                            picked.toIso8601String().split('T').first;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateTile(
                  label: 'Deadline',
                  value: _fmt(endDt),
                  icon: Icons.event_busy,
                  onTap: () async {
                    final picked = await _pickDate(context, initial: endDt);
                    if (picked != null) {
                      setState(() {
                        _deadlineEdits[quarter]!['end_date'] =
                            picked.toIso8601String().split('T').first;
                        // Clear extension if new end_date is set
                        _deadlineEdits[quarter]!['extended_until'] = null;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          if (extStr != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.update, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Extended until: ${_fmt(extDt)}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _deadlineEdits[quarter]!['extended_until'] = null;
                    });
                  },
                  child: const Text('Remove',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (startDt != null && endDt != null && status == 'Closed') ...[
                OutlinedButton.icon(
                  onPressed: _deadlinesSaving
                      ? null
                      : () async {
                          final picked = await _pickDate(context,
                              initial: DateTime.now().add(const Duration(days: 1)));
                          if (picked != null) {
                            setState(() {
                              _deadlineEdits[quarter]!['extended_until'] =
                                  picked.toIso8601String().split('T').first;
                            });
                            await _saveDeadline(quarter);
                          }
                        },
                  icon: const Icon(Icons.update, size: 16),
                  label: const Text('Extend'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: _deadlinesSaving ? null : () => _saveDeadline(quarter),
                icon: _deadlinesSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E66B4),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF1E66B4)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.edit, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraSettingsCard() {

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.notifications_active,
              color: Color(0xFF1E66B4),
            ),
            title: const Text('Notification Preferences'),
            subtitle: const Text('Manage alerts & email notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.dark_mode, color: Color(0xFF1E66B4)),
            title: const Text('Theme Options'),
            subtitle: const Text('Light mode active'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.update, color: Colors.orange.shade700),
            title: const Text('End of School Year Rollover',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Promote students & start new school year'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SchoolYearRolloverScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}


