import 'package:flutter/material.dart';

import '../models/app_models.dart';
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
        onSaved: () {
          Navigator.of(sheetContext).pop();
          onSaved();
        },
      );
    },
  );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.apiClient,
    required this.user,
    required this.onSaved,
  });

  final ApiClient apiClient;
  final AppUser user;
  final VoidCallback onSaved;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
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
      widget.onSaved();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = '저장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          TextField(
            controller: _nameController,
            enabled: !_loading,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '표시 이름',
            ),
          ),
          if (widget.user.isStudent) ...[
            const SizedBox(height: AppSpacing.md),
            InputDecorator(
              decoration: const InputDecoration(labelText: '학년'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGrade,
                  isExpanded: true,
                  hint: const Text('학년 선택'),
                  items: [
                    for (final grade in gradeOptionsList)
                      DropdownMenuItem(value: grade, child: Text(grade)),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _selectedGrade = value),
                ),
              ),
            ),
          ],
          if (widget.user.isTeacher) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _orgController,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: '소속 (학원·학교)',
                hintText: '예: OO학원',
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
