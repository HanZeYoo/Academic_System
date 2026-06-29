import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';

class AddTeacherScreen extends StatefulWidget {
  final Map<String, dynamic>? teacherToEdit;
  const AddTeacherScreen({super.key, this.teacherToEdit});

  @override
  State<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends State<AddTeacherScreen> {
  bool _sendCredentials = true;
  
  final TextEditingController _teacherIdController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();
  
  String? _selectedGender;
  String? _selectedDepartment;
  String? _selectedSubjectSpecialization;
  String? _selectedEmploymentStatus;
  String? _selectedAssignedSection;

  DateTime? _birthdate;
  DateTime? _hiringDate;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.teacherToEdit != null) {
      final data = widget.teacherToEdit!;
      _teacherIdController.text = data['teacher_id']?.toString() ?? '';
      _emailController.text = data['email']?.toString() ?? '';
      
      final names = data['name']?.toString().split(' ') ?? [];
      _firstNameController.text = names.isNotEmpty ? names.first : '';
      if (names.length > 1) {
        _lastNameController.text = names.sublist(1).join(' ');
      }
      
      if (const [
        'Mathematics Department',
        'Science Department',
        'English Department',
        'Filipino Department',
        'Araling Panlipunan (Social Studies)',
        'MAPEH Department',
        'TLE Department',
        'EsP Department',
        'SHS Core Subjects',
        'SHS Applied/Specialized'
      ].contains(data['department'])) _selectedDepartment = data['department'];
      if (['Male', 'Female', 'Other'].contains(data['gender'])) _selectedGender = data['gender'];
      if (['Mathematics', 'Science', 'English', 'History'].contains(data['specialization'])) _selectedSubjectSpecialization = data['specialization'];
      if (['Full-time', 'Part-time', 'Contract'].contains(data['employment_status'])) _selectedEmploymentStatus = data['employment_status'];
      if (['Section A', 'Section B', 'Section C', 'Section D'].contains(data['assigned_section'])) _selectedAssignedSection = data['assigned_section'];
      
      _contactNumberController.text = data['contact_number']?.toString() ?? '';
      _homeAddressController.text = data['address']?.toString() ?? '';
      
      if (data['birthdate'] != null && data['birthdate'].toString().isNotEmpty) {
        try {
          final parts = data['birthdate'].toString().split('/');
          if (parts.length == 3) {
            _birthdate = DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
          }
        } catch (e) {
          // Ignore parse errors
        }
      }
      
      if (data['hiring_date'] != null && data['hiring_date'].toString().isNotEmpty) {
        try {
          final parts = data['hiring_date'].toString().split('/');
          if (parts.length == 3) {
            _hiringDate = DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
          }
        } catch (e) {
          // Ignore parse errors
        }
      }
    } else {
      _generateAndSetTeacherId();
    }
  }

  Future<void> _generateAndSetTeacherId() async {
    try {
      final nextId = await DatabaseHelper().generateNextTeacherId();
      setState(() {
        _teacherIdController.text = nextId;
      });
    } catch (e) {
      setState(() {
        _teacherIdController.text = 'TCH-000001';
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isBirthdate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F52BA), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF1E293B), // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isBirthdate) {
          _birthdate = picked;
        } else {
          _hiringDate = picked;
        }
      });
    }
  }

  Future<void> _saveTeacher() async {
    if (_teacherIdController.text.isEmpty) {
      try {
        final nextId = await DatabaseHelper().generateNextTeacherId();
        _teacherIdController.text = nextId;
      } catch (e) {
        _teacherIdController.text = 'TCH-000001';
      }
    }

    if (_teacherIdController.text.isEmpty || _firstNameController.text.isEmpty || _lastNameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
      return;
    }

    final emailToCheck = _emailController.text.trim();
    if (emailToCheck.isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailToCheck)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address.')));
        return;
      }
      final existingUser = await DatabaseHelper().getUserByUsername(emailToCheck);
      if (existingUser != null && (widget.teacherToEdit == null || widget.teacherToEdit!['email'] != emailToCheck)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email already exists! Please use a different email.')));
        return;
      }
    }

    setState(() => _isLoading = true);
    
    final fullName = '${_firstNameController.text} ${_lastNameController.text}';
    
    if (widget.teacherToEdit != null) {
      await DatabaseHelper().updateTeacher(
        widget.teacherToEdit!['id'] as int,
        oldEmail: widget.teacherToEdit!['email']?.toString(),
        teacherId: _teacherIdController.text,
        name: fullName,
        department: _selectedDepartment ?? 'Unknown Department',
        email: _emailController.text,
        gender: _selectedGender,
        birthdate: _birthdate != null ? '${_birthdate!.month}/${_birthdate!.day}/${_birthdate!.year}' : null,
        contactNumber: _contactNumberController.text,
        address: _homeAddressController.text,
        specialization: _selectedSubjectSpecialization,
        employmentStatus: _selectedEmploymentStatus,
        hiringDate: _hiringDate != null ? '${_hiringDate!.month}/${_hiringDate!.day}/${_hiringDate!.year}' : null,
        assignedSection: _selectedAssignedSection,
      );
    } else {
      await DatabaseHelper().addTeacher(
        teacherId: _teacherIdController.text,
        name: fullName,
        department: _selectedDepartment ?? 'Unknown Department',
        email: _emailController.text,
        gender: _selectedGender,
        birthdate: _birthdate != null ? '${_birthdate!.month}/${_birthdate!.day}/${_birthdate!.year}' : null,
        contactNumber: _contactNumberController.text,
        address: _homeAddressController.text,
        specialization: _selectedSubjectSpecialization,
        employmentStatus: _selectedEmploymentStatus,
        hiringDate: _hiringDate != null ? '${_hiringDate!.month}/${_hiringDate!.day}/${_hiringDate!.year}' : null,
        assignedSection: _selectedAssignedSection,
      );
    }
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher saved successfully!'), backgroundColor: Colors.green));
      Navigator.pop(context, true); // Return true to refresh list
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Teacher'),
        content: Text('Are you sure you want to delete ${widget.teacherToEdit!['name']}? This record will be hidden from the active lists.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper().softDeleteTeacher(widget.teacherToEdit!['id']);
              if (mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F9), // Light blue-gray background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F52BA), // App blue color
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.teacherToEdit != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _confirmDelete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: const Icon(Icons.person, color: Color(0xFF0F52BA), size: 20),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.teacherToEdit != null ? 'Edit Teacher' : 'Add Teacher',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.teacherToEdit != null ? 'Update existing teacher record' : 'Create a new teacher record',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 24),

              // Upload Photo Section
              _buildSectionContainer(
                child: Row(
                  children: [
                    CustomPaint(
                      painter: _DashedCirclePainter(
                        color: const Color(0xFF93C5FD),
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo, color: Color(0xFF0F52BA), size: 28),
                            SizedBox(height: 4),
                            Text(
                              'Upload Photo',
                              style: TextStyle(
                                color: Color(0xFF0F52BA),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add a photo to personalize',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'JPG, PNG up to 2MB.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Teacher Information Section
              _buildSectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.person, color: Color(0xFF0F52BA), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Teacher Information',
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
                            label: 'Teacher ID',
                            hint: 'e.g., TCH-000123',
                            isRequired: true,
                            enabled: false,
                            controller: _teacherIdController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()), // Empty space to match design (half width)
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'First Name',
                            hint: 'Enter first name',
                            isRequired: true,
                            controller: _firstNameController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Middle Name',
                            hint: 'Enter middle name',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Last Name',
                            hint: 'Enter last name',
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
                            onTap: () => _selectDate(context, true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Department',
                            hint: 'Select department',
                            isRequired: true,
                            value: _selectedDepartment,
                            items: const [
                              'Mathematics Department',
                              'Science Department',
                              'English Department',
                              'Filipino Department',
                              'Araling Panlipunan (Social Studies)',
                              'MAPEH Department',
                              'TLE Department',
                              'EsP Department',
                              'SHS Core Subjects',
                              'SHS Applied/Specialized'
                            ],
                            onChanged: (val) => setState(() => _selectedDepartment = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown(
                            label: 'Subject Specialization',
                            hint: 'Select subject specialization',
                            isRequired: true,
                            value: _selectedSubjectSpecialization,
                            items: const ['Algebra', 'Biology', 'Literature', 'World History', 'Filipino'],
                            onChanged: (val) => setState(() => _selectedSubjectSpecialization = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email Address',
                      hint: 'Enter email address',
                      isRequired: true,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(text: newValue.text.toLowerCase())),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Contact Number',
                      hint: 'Enter contact number',
                      isRequired: true,
                      controller: _contactNumberController,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Employment Status',
                            hint: 'Select employment status',
                            isRequired: true,
                            value: _selectedEmploymentStatus,
                            items: const ['Full-Time', 'Part-Time', 'Contract'],
                            onChanged: (val) => setState(() => _selectedEmploymentStatus = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDatePicker(
                            label: 'Hiring Date',
                            hint: _hiringDate != null 
                                ? '${_hiringDate!.month}/${_hiringDate!.day}/${_hiringDate!.year}' 
                                : 'Select hiring date',
                            isRequired: true,
                            onTap: () => _selectDate(context, false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Assigned Section/Class',
                      hint: 'Select section or class',
                      value: _selectedAssignedSection,
                      items: const ['Section A', 'Section B', 'Section C'],
                      onChanged: (val) => setState(() => _selectedAssignedSection = val),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Home Address',
                      hint: 'Enter complete home address',
                      isRequired: true,
                      maxLines: 3,
                      controller: _homeAddressController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Account Setup Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Color(0xFF0F52BA),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Account Setup',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Credentials are created automatically for the teacher.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: Color(0xFFDBEAFE),
                              child: Icon(Icons.mail_outline, color: Color(0xFF0F52BA)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Login / Username',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Teacher Email',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Used to sign in to the system',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(color: Color(0xFFBFDBFE), thickness: 1, height: 1),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: Color(0xFFDBEAFE),
                              child: Icon(Icons.lock_outline, color: Color(0xFF0F52BA)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Default Password',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'teacher123',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Change after first login',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        value: _sendCredentials,
                        onChanged: (value) {
                          setState(() {
                            _sendCredentials = value;
                          });
                        },
                        activeColor: const Color(0xFF0F52BA),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Send credentials via email',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF0F52BA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF0F52BA),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveTeacher,
                      icon: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save, size: 20),
                      label: Text(
                        _isLoading ? 'Saving...' : (widget.teacherToEdit != null ? 'Update Teacher' : 'Save Teacher'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF0F52BA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
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
            color: Colors.black.withOpacity(0.02),
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          children: [
            if (suffix != null)
              TextSpan(
                text: suffix,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF64748B),
                ),
              ),
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
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
    IconData? suffixIcon,
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
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, color: const Color(0xFF94A3B8), size: 20)
                : null,
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
              hint: Text(
                hint,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
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
    VoidCallback? onTap,
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
                      color: hint.contains('/') ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today_outlined, color: Color(0xFF94A3B8), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  _DashedCirclePainter({
    required this.color,
    this.strokeWidth = 1,
    this.dashWidth = 4,
    this.dashSpace = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double radius = size.width / 2;
    final double circumference = 2 * 3.141592653589793 * radius;
    final int dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; ++i) {
      final double startAngle = (i * (dashWidth + dashSpace)) / radius;
      final double sweepAngle = dashWidth / radius;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
