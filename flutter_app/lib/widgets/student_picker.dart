import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import '../theme/app_design_system.dart';
import 'linked_children_panel.dart';
import 'profile_avatar.dart';
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
    return ListenableBuilder(
      listenable: authSession,
      builder: (context, _) {
        final students = authSession.linkedStudents;
        if (students.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedId = authSession.viewAsStudentId ?? students.first.id;
        final selected = students.firstWhere(
          (s) => s.id == selectedId,
          orElse: () => students.first,
        );
        final canSwitch = students.length > 1;

        return Row(
          children: [
            Expanded(
              child: _StudentPickerChip(
                student: selected,
                apiBaseUrl: apiClient?.baseUrl,
                showChevron: canSwitch,
                onTap: canSwitch
                    ? () => _showStudentSheet(context, students, selectedId)
                    : null,
              ),
            ),
            if (apiClient != null) ...[
              const SizedBox(width: AppSpacing.sm),
              _AddChildButton(
                onPressed: () => _showAddChildSheet(context),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showStudentSheet(
    BuildContext context,
    List<LinkedStudent> students,
    String selectedId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < students.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.xs),
                  _StudentSheetTile(
                    student: students[i],
                    apiBaseUrl: apiClient?.baseUrl,
                    selected: students[i].id == selectedId,
                    onTap: () async {
                      await authSession.setViewAsStudentId(students[i].id);
                      onChanged?.call();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
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

class _StudentPickerChip extends StatelessWidget {
  const _StudentPickerChip({
    required this.student,
    required this.apiBaseUrl,
    required this.showChevron,
    this.onTap,
  });

  final LinkedStudent student;
  final String? apiBaseUrl;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: AppSizes.buttonHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          LinkedStudentAvatar(
            student: student,
            apiBaseUrl: apiBaseUrl,
            size: 34,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              student.labelForGuardian,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.2,
                color: AppColors.text,
              ),
            ),
          ),
          if (showChevron)
            const Icon(
              Icons.expand_more_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: content,
      ),
    );
  }
}

class _StudentSheetTile extends StatelessWidget {
  const _StudentSheetTile({
    required this.student,
    required this.apiBaseUrl,
    required this.selected,
    required this.onTap,
  });

  final LinkedStudent student;
  final String? apiBaseUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.success.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              LinkedStudentAvatar(
                student: student,
                apiBaseUrl: apiBaseUrl,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  student.labelForGuardian,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChildButton extends StatelessWidget {
  const _AddChildButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          width: AppSizes.buttonHeight,
          height: AppSizes.buttonHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.borderStrong),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: AppColors.success,
            size: 22,
          ),
        ),
      ),
    );
  }
}
