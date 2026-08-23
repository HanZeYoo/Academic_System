import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../services/email_service.dart';
import 'student_dashboard_screen.dart';

class StudentProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;
  const StudentProfileSetupScreen({super.key, required this.studentData});

  @override
  State<StudentProfileSetupScreen> createState() => _StudentProfileSetupScreenState();
}

class _StudentProfileSetupScreenState extends State<StudentProfileSetupScreen> {
  bool _isLoading = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _parentContactController = TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();

  String? _selectedGender;
  DateTime? _birthdate;

  @override
  void initState() {
    super.initState();
    final fullName = widget.studentData['name']?.toString() ?? '';
    final nameParts = fullName.split(' ');
    if (nameParts.length > 1) {
      _lastNameController.text = nameParts.last;
      _firstNameController.text = nameParts.sublist(0, nameParts.length - 1).join(' ');
    } else {
      _firstNameController.text = fullName;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F52BA),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _birthdate = picked);
    }
  }

  Future<void> _submitProfile() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _selectedGender == null ||
        _birthdate == null ||
        _contactNumberController.text.isEmpty ||
        _homeAddressController.text.isEmpty ||
        _parentNameController.text.isEmpty ||
        _parentContactController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    final parentEmailToCheck = _parentEmailController.text.trim();
    if (parentEmailToCheck.isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(parentEmailToCheck)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid parent email address.')));
        return;
      }
      if (!parentEmailToCheck.endsWith('.com') && !parentEmailToCheck.endsWith('.ph')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parent email must end with .com or .ph')));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final studentEmail = widget.studentData['email'] ?? '';
      
      final middleInitial = _middleNameController.text.isNotEmpty ? ' ${_middleNameController.text}' : '';
      final fullName = '${_firstNameController.text}$middleInitial ${_lastNameController.text}';
      
      await DatabaseHelper().completeStudentProfile(
        studentEmail,
        name: fullName,
        gender: _selectedGender!,
        birthdate: '${_birthdate!.month}/${_birthdate!.day}/${_birthdate!.year}',
        contactNumber: _contactNumberController.text,
        parentName: _parentNameController.text,
        parentContact: _parentContactController.text,
        parentEmail: _parentEmailController.text,
        address: _homeAddressController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile setup complete! Welcome.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => StudentDashboardScreen(username: studentEmail)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = widget.studentData['name'] ?? 'Student';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F52BA),
        elevation: 0,
        title: const Text('Complete Your Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, // Prevent going back to login without setting up
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $studentName!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Before you can access your dashboard, please complete your profile information.',
                style: TextStyle(fontSize: 15, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 24),

              _buildSectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.person, color: Color(0xFF0F52BA), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Personal Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'First Name',
                            hint: 'First name',
                            isRequired: true,
                            controller: _firstNameController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Middle Name',
                            hint: 'Middle name',
                            controller: _middleNameController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Last Name',
                            hint: 'Last name',
                            isRequired: true,
                            controller: _lastNameController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Gender',
                            hint: 'Select gender',
                            isRequired: true,
                            value: _selectedGender,
                            items: const ['Male', 'Female', 'Other'],
                            onChanged: (val) => setState(() => _selectedGender = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDatePicker(
                            label: 'Birthdate',
                            hint: _birthdate != null
                                ? '${_birthdate!.month}/${_birthdate!.day}/${_birthdate!.year}'
                                : 'Select birthdate',
                            isRequired: true,
                            onTap: _selectDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Contact Number',
                      hint: 'Enter your contact number',
                      isRequired: true,
                      controller: _contactNumberController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Home Address',
                      hint: 'Enter your complete home address',
                      isRequired: true,
                      maxLines: 3,
                      controller: _homeAddressController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildSectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.family_restroom, color: Color(0xFF0F52BA), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Parent/Guardian Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Name',
                            hint: 'Parent/guardian name',
                            isRequired: true,
                            controller: _parentNameController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Contact Number',
                            hint: 'Parent contact number',
                            isRequired: true,
                            controller: _parentContactController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Parent Email Address',
                      hint: 'Enter parent email (Optional)',
                      labelSuffix: '(For Parent Portal Access)',
                      controller: _parentEmailController,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(text: newValue.text.toLowerCase())),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitProfile,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isLoading ? 'Saving...' : 'Complete Setup',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF0F52BA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false, String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          children: [
            if (suffix != null)
              TextSpan(
                text: ' $suffix',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF64748B)),
              ),
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    bool isRequired = false,
    String? labelSuffix,
    bool enabled = true,
    int maxLines = 1,
    TextEditingController? controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired, suffix: labelSuffix),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    bool isRequired = false,
    required List<String> items,
    String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text(hint, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required String hint,
    bool isRequired = false,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(
                      color: hint.contains('Select') ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today, color: Color(0xFF94A3B8), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
