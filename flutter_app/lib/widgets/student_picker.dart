import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_session.dart';
import '../theme/app_design_system.dart';
import 'linked_children_panel.dart';
import 'student_link_guide.dart';

class StudentPicker extends StatelessWidget {
  const StudentPicker({
    super.key,
    required this.authSession,
    this.apiClient,
    this.onChanged,
  });

  final AuthSession authSession;
  final ApiClient? apiClient;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final students = authSession.linkedStudents;
    if (students.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: authSession.viewAsStudentId ?? students.first.id,
                decoration: InputDecoration(
                  labelText: '학생 선택',
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    borderSide: const BorderSide(color: AppColors.border),
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
              ),
            ),
            if (apiClient != null) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: '자녀 추가',
                onPressed: () => _showAddChildSheet(context),
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showAddChildSheet(BuildContext context) {
    final client = apiClient;
    if (client == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
            top: AppSpacing.md,
          ),
          child: ListenableBuilder(
            listenable: client.authSession,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinkedChildrenPanel(
                    apiClient: client,
                    linkedStudents: client.authSession.linkedStudents,
                    compact: true,
                    onChanged: onChanged,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  StudentLinkGuide(role: client.authSession.user?.role),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
