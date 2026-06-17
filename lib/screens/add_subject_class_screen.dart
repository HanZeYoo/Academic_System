import 'package:flutter/material.dart';
import '../database_helper.dart';

class AddSubjectClassScreen extends StatefulWidget {
  final Map<String, dynamic>? subjectClassToEdit;
  const AddSubjectClassScreen({super.key, this.subjectClassToEdit});

  @override
  State<AddSubjectClassScreen> createState() => _AddSubjectClassScreenState();
}

class _AddSubjectClassScreenState extends State<AddSubjectClassScreen> {
  String? _selectedDepartment;
  String? _selectedGradeLevel;
  String? _selectedSemester;
  String? _selectedTeacher;
  String? _selectedClassType;
  String? _selectedStatus;

  final TextEditingController _subjectCodeController = TextEditingController();
  final TextEditingController _subjectNameController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
  
  String? _selectedSectionName;
  final TextEditingController _scheduleController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  List<Map<String, dynamic>> _teachersList = [];
  bool _isLoadingTeachers = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    if (widget.subjectClassToEdit != null) {
      final data = widget.subjectClassToEdit!;
      _subjectCodeController.text = data['subject_code']?.toString() ?? '';
      _subjectNameController.text = data['subject_name']?.toString() ?? '';

      _descriptionController.text = data['description']?.toString() ?? '';
      _selectedSectionName = data['section_name']?.toString().isNotEmpty == true ? data['section_name'].toString() : null;
      _scheduleController.text = data['schedule']?.toString() ?? '';
      _timeController.text = data['time']?.toString() ?? '';
      _roomController.text = data['room']?.toString() ?? '';
      _capacityController.text = data['capacity']?.toString() ?? '';
      
      _selectedDepartment = data['department']?.toString().isNotEmpty == true ? data['department'].toString() : null;
      _selectedGradeLevel = data['grade_level']?.toString().isNotEmpty == true ? data['grade_level'].toString() : null;
      _selectedSemester = data['semester']?.toString().isNotEmpty == true ? data['semester'].toString() : null;
      _selectedTeacher = data['assigned_teacher']?.toString().isNotEmpty == true ? data['assigned_teacher'].toString() : null;
      _selectedClassType = data['class_type']?.toString().isNotEmpty == true ? data['class_type'].toString() : null;
      _selectedStatus = data['status']?.toString().isNotEmpty == true ? data['status'].toString() : null;
    }
  }

  Future<void> _loadTeachers() async {
    final teachers = await DatabaseHelper().getTeachers();
    setState(() {
      _teachersList = teachers;
      _isLoadingTeachers = false;
    });
  }

  Future<void> _saveSubjectClass() async {
    if (_subjectCodeController.text.isEmpty ||
        _subjectNameController.text.isEmpty ||
        (_selectedSectionName == null || _selectedSectionName!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    Map<String, dynamic> data = {
      'subject_code': _subjectCodeController.text,
      'subject_name': _subjectNameController.text,
      'department': _selectedDepartment ?? '',
      'grade_level': _selectedGradeLevel ?? '',
      'semester': _selectedSemester ?? '',
      'units': '',
      'description': _descriptionController.text,
      'section_name': _selectedSectionName ?? '',
      'assigned_teacher': _selectedTeacher ?? '',
      'schedule': _scheduleController.text,
      'time': _timeController.text,
      'room': _roomController.text,
      'capacity': _capacityController.text,
      'class_type': _selectedClassType ?? '',
      'status': _selectedStatus ?? '',
    };

    if (widget.subjectClassToEdit != null) {
      await DatabaseHelper().updateSubjectClass(widget.subjectClassToEdit!['id'] as int, data);
    } else {
      await DatabaseHelper().addSubjectClass(data);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject and Class saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true to indicate success
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject & Class'),
        content: Text('Are you sure you want to delete ${widget.subjectClassToEdit!['subject_name']}? This record will be hidden from the active lists.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper().softDeleteSubjectClass(widget.subjectClassToEdit!['id']);
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
    List<String> teacherNames = _teachersList.map((t) => t['name'].toString()).toList();

    List<String> termOptions;
    if (_selectedGradeLevel == 'Grade 11' || _selectedGradeLevel == 'Grade 12') {
      termOptions = ['1st Semester', '2nd Semester'];
    } else if (_selectedGradeLevel != null) {
      termOptions = ['1st Quarter', '2nd Quarter', '3rd Quarter', '4th Quarter'];
    } else {
      termOptions = [
        '1st Quarter',
        '2nd Quarter',
        '3rd Quarter',
        '4th Quarter',
        '1st Semester',
        '2nd Semester'
      ];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F52BA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.subjectClassToEdit != null)
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
                widget.subjectClassToEdit != null ? 'Edit Subject / Class' : 'Add Subject / Class',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subjectClassToEdit != null ? 'Update existing subject and class record' : 'Create a new subject and class record',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 24),

              // Subject Information Section
              _buildSectionContainer(
                icon: Icons.menu_book,
                title: 'Subject Information',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Subject Code',
                            hint: 'e.g., MATH101',
                            isRequired: true,
                            prefixIcon: Icons.tag,
                            controller: _subjectCodeController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Subject Name',
                            hint: 'e.g., Mathematics I',
                            isRequired: true,
                            prefixIcon: Icons.book_outlined,
                            controller: _subjectNameController,
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
                            prefixIcon: Icons.account_balance_outlined,
                            value: const ['Math', 'Science', 'English', 'IT'].contains(_selectedDepartment) ? _selectedDepartment : null,
                            items: const ['Math', 'Science', 'English', 'IT'],
                            onChanged: (val) => setState(() => _selectedDepartment = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown(
                            label: 'Grade Level',
                            hint: 'Select grade level',
                            isRequired: true,
                            prefixIcon: Icons.school_outlined,
                            value: const ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'].contains(_selectedGradeLevel) ? _selectedGradeLevel : null,
                            items: const ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'],
                            onChanged: (val) {
                              setState(() {
                                _selectedGradeLevel = val;
                                if (val == 'Grade 11' || val == 'Grade 12') {
                                  if (!['1st Semester', '2nd Semester'].contains(_selectedSemester)) {
                                    _selectedSemester = null;
                                  }
                                } else if (val != null) {
                                  if (!['1st Quarter', '2nd Quarter', '3rd Quarter', '4th Quarter'].contains(_selectedSemester)) {
                                    _selectedSemester = null;
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Term / Duration',
                            hint: 'Select term',
                            isRequired: true,
                            prefixIcon: Icons.calendar_today_outlined,
                            value: termOptions.contains(_selectedSemester) ? _selectedSemester : null,
                            items: termOptions,
                            onChanged: (val) => setState(() => _selectedSemester = val),
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Description',
                      hint: 'Enter subject description',
                      prefixIcon: Icons.format_align_left_outlined,
                      maxLines: 3,
                      controller: _descriptionController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Class Assignment Section
              _buildSectionContainer(
                icon: Icons.event_note,
                title: 'Class Assignment',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Section / Class Name',
                            hint: 'Select Section',
                            isRequired: true,
                            prefixIcon: Icons.people_outline,
                            value: const ['Section A', 'Section B', 'Section C', 'Section D', 'Section E'].contains(_selectedSectionName) ? _selectedSectionName : null,
                            items: const ['Section A', 'Section B', 'Section C', 'Section D', 'Section E'],
                            onChanged: (val) => setState(() => _selectedSectionName = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isLoadingTeachers
                              ? const Center(child: CircularProgressIndicator())
                              : _buildDropdown(
                                  label: 'Assigned Teacher',
                                  hint: teacherNames.isEmpty ? 'No teachers found' : 'Select teacher',
                                  isRequired: true,
                                  prefixIcon: Icons.person_outline,
                                  value: teacherNames.contains(_selectedTeacher) ? _selectedTeacher : null,
                                  items: teacherNames,
                                  onChanged: (val) => setState(() => _selectedTeacher = val),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Schedule (Days)',
                            hint: 'e.g., Mon, Wed, Fri',
                            isRequired: true,
                            prefixIcon: Icons.calendar_today_outlined,
                            controller: _scheduleController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Time',
                            hint: 'e.g., 9:00 AM - 10:30 AM',
                            isRequired: true,
                            prefixIcon: Icons.access_time,
                            controller: _timeController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Room',
                            hint: 'e.g., Room 201',
                            isRequired: true,
                            prefixIcon: Icons.door_front_door_outlined,
                            controller: _roomController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Capacity',
                            hint: 'e.g., 40',
                            isRequired: true,
                            prefixIcon: Icons.people_outline,
                            controller: _capacityController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Class Type',
                            hint: 'Select class type',
                            isRequired: true,
                            prefixIcon: Icons.school_outlined,
                            value: const ['Regular', 'Elective'].contains(_selectedClassType) ? _selectedClassType : null,
                            items: const ['Regular', 'Elective'],
                            onChanged: (val) => setState(() => _selectedClassType = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown(
                            label: 'Status',
                            hint: 'Select status',
                            isRequired: true,
                            prefixIcon: Icons.check_circle_outline,
                            value: const ['Active', 'Inactive'].contains(_selectedStatus) ? _selectedStatus : null,
                            items: const ['Active', 'Inactive'],
                            onChanged: (val) => setState(() => _selectedStatus = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info, color: Color(0xFF0F52BA), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Students can be assigned after saving the class.',
                              style: TextStyle(
                                color: Color(0xFF0F52BA),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                      onPressed: _isSaving ? null : _saveSubjectClass,
                      icon: _isSaving 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Icon(Icons.save, size: 20),
                      label: Text(
                        _isSaving ? 'Saving...' : (widget.subjectClassToEdit != null ? 'Update Subject' : 'Save Subject'),
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

  Widget _buildSectionContainer({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Icon(icon, color: const Color(0xFF0F52BA), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
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
    IconData? prefixIcon,
    int maxLines = 1,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 14,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 20)
                : null,
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
    required IconData prefixIcon,
    required List<String> items,
    String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 20),
              const SizedBox(width: 12),
              Expanded(
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
          ),
        ),
      ],
    );
  }
}
