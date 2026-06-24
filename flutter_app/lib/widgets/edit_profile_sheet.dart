import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/role_select_screen.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import '../utils/grade_options.dart';

Future<void> showEditProfileSheet({
  required BuildContext context,
  required ApiClient apiClient,
  required AppUser user,
  required VoidCallback onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (sheetContext) {
      return _EditProfileSheet(
        apiClient: apiClient,
        user: user,
        onUpdated: onSaved,
        onClose: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.apiClient,
    required this.user,
    required this.onUpdated,
    required this.onClose,
  });

  final ApiClient apiClient;
  final AppUser user;
  final VoidCallback onUpdated;
  final VoidCallback onClose;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  static const _fieldPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: 16,
  );

  static const _fieldTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  late final TextEditingController _nameController;
  late final TextEditingController _orgController;
  late String? _selectedGrade;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _orgController = TextEditingController(
      text: widget.user.organizationName ?? '',
    );
    _selectedGrade = widget.user.grade;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해 주세요.');
      return;
    }

    if (widget.user.isStudent &&
        (_selectedGrade == null || _selectedGrade!.trim().isEmpty)) {
      setState(() => _error = '학년을 선택해 주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.apiClient.updateProfile(
        displayName: name,
        grade: widget.user.isStudent ? _selectedGrade : null,
        organizationName: widget.user.isTeacher
            ? _orgController.text.trim()
            : null,
      );
      if (!mounted) return;
      widget.onClose();
      widget.onUpdated();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = '저장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRoleChange() async {
    if (_loading) return;

    final rootNav = Navigator.of(context, rootNavigator: true);
    final apiClient = widget.apiClient;
    final onUpdated = widget.onUpdated;
    final initialRole = widget.user.role;
    final initialGrade = widget.user.grade;

    widget.onClose();

    final changed = await rootNav.push<bool>(
      MaterialPageRoute(
        builder: (_) => RoleSelectScreen(
          apiClient: apiClient,
          changingAccount: true,
          initialRole: initialRole,
          initialGrade: initialGrade,
        ),
      ),
    );

    if (changed == true) {
      apiClient.invalidateLearningProfileCache();
      onUpdated();
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      contentPadding: _fieldPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        bottomInset + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '기본 정보 수정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '계정 타입',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSub,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: _fieldDecoration(label: '현재 타입'),
                  child: Text(
                    widget.user.role?.label ?? '미설정',
                    style: _fieldTextStyle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: _loading ? null : _openRoleChange,
                child: const Text('변경'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _nameController,
            enabled: !_loading,
            textInputAction: TextInputAction.next,
            style: _fieldTextStyle,
            decoration: _fieldDecoration(label: '이름', hint: '표시 이름'),
          ),
          if (widget.user.isStudent) ...[
            const SizedBox(height: AppSpacing.xl),
            DropdownButtonFormField<String>(
              value: _selectedGrade,
              isExpanded: true,
              style: _fieldTextStyle,
              decoration: _fieldDecoration(label: '학년'),
              hint: const Text(
                '학년 선택',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
              ),
              items: [
                for (final grade in gradeOptionsList)
                  DropdownMenuItem(value: grade, child: Text(grade)),
              ],
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _selectedGrade = value),
            ),
          ],
          if (widget.user.isTeacher) ...[
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _orgController,
              enabled: !_loading,
              style: _fieldTextStyle,
              decoration: _fieldDecoration(
                label: '소속 (학원·학교)',
                hint: '예: OO학원',
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.accent),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}
