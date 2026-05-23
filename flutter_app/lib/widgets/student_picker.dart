import 'package:flutter/material.dart';

import '../services/auth_session.dart';

class StudentPicker extends StatelessWidget {
  const StudentPicker({
    super.key,
    required this.authSession,
    this.onChanged,
  });

  final AuthSession authSession;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final students = authSession.linkedStudents;
    if (students.isEmpty) {
      return const SizedBox.shrink();
    }

    return DropdownButtonFormField<String>(
      initialValue: authSession.viewAsStudentId ?? students.first.id,
      decoration: InputDecoration(
        labelText: '학생 선택',
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        for (final student in students)
          DropdownMenuItem(
            value: student.id,
            child: Text('${student.displayName} (${student.studentCode})'),
          ),
      ],
      onChanged: (value) async {
        await authSession.setViewAsStudentId(value);
        onChanged?.call();
      },
    );
  }
}
