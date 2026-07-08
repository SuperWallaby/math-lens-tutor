import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import '../utils/pending_student_link.dart';
import '../utils/student_code_format.dart';
import 'app_card.dart';
import 'hero_icon_3d.dart';
import 'profile_avatar.dart';
import 'student_code_input_field.dart';

class LinkedChildrenPanel extends StatefulWidget {
  const LinkedChildrenPanel({
    super.key,
    required this.apiClient,
    required this.linkedStudents,
    this.onChanged,
    this.onAutoLinked,
    this.compact = false,
    this.autoSubmitOnValidCode = true,
    this.showConnectButton = false,
    this.showInlineGuide = false,
  });

  final ApiClient apiClient;
  final List<LinkedStudent> linkedStudents;
  final VoidCallback? onChanged;
  final VoidCallback? onAutoLinked;
  final bool compact;
  final bool autoSubmitOnValidCode;
  final bool showConnectButton;
  final bool showInlineGuide;

  @override
  State<LinkedChildrenPanel> createState() => _LinkedChildrenPanelState();
}

class _LinkedChildrenPanelState extends State<LinkedChildrenPanel> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _lastSubmittedCode;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
    _applyPendingLinkCode();
  }

  Future<void> _applyPendingLinkCode() async {
    final pending = await consumePendingStudentLinkCode();
    if (pending == null || !mounted) return;
    _codeController.text = pending;
  }

  Future<void> _pasteCode() async {
    if (_loading) return;
    final pasted = await pasteStudentCodeInto(_codeController);
    if (!pasted && mounted) {
      setState(() => _error = '클립보드에 학생 코드가 없습니다.');
    } else if (mounted) {
      setState(() => _error = null);
    }
  }

  Widget? get _fieldSuffix {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      onPressed: _pasteCode,
      icon: const Icon(Icons.content_paste_rounded),
      tooltip: '붙여넣기',
    );
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (!widget.autoSubmitOnValidCode || _loading) return;
    final raw = _codeController.text.trim();
    final code = parseStudentCodeFromText(raw);

    if (raw.length >= 6 && code == null) {
      setState(
        () => _error = '올바른 학생 고유번호 형식이 아닙니다. (WY-XXXXXX)',
      );
      return;
    }

    if (code == null || !isCompleteStudentCode(code)) {
      if (_error != null && mounted) {
        setState(() => _error = null);
      }
      return;
    }
    if (_lastSubmittedCode == code) return;
    _link(code: code, auto: true);
  }

  String? _guestLinkBlockedMessage() {
    if (!widget.apiClient.authSession.isGuest) return null;
    return '학생 연결은 가입 후 이용할 수 있습니다. 아래 「가입하고 연결하기」 또는 설정에서 로그인해 주세요.';
  }

  Future<void> _link({String? code, bool auto = false}) async {
    final guestMessage = _guestLinkBlockedMessage();
    if (guestMessage != null) {
      setState(() => _error = guestMessage);
      return;
    }

    final normalized =
        (code ?? parseStudentCodeFromText(_codeController.text))?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      setState(() => _error = '학생 고유번호를 입력해 주세요.');
      return;
    }
    if (!isCompleteStudentCode(normalized)) {
      setState(
        () => _error = auto
            ? '올바른 학생 고유번호 형식이 아닙니다. (WY-XXXXXX)'
            : '학생 고유번호를 확인해 주세요.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _lastSubmittedCode = normalized;
    });

    try {
      final student = await widget.apiClient.linkStudent(normalized);
      _codeController.clear();
      _lastSubmittedCode = null;
      widget.onChanged?.call();
      if (widget.autoSubmitOnValidCode) {
        widget.onAutoLinked?.call();
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.labelForGuardian} 학생과 연결되었습니다.'),
          ),
        );
      }
    } on ApiException catch (error) {
      setState(() {
        _error = error.message;
        _lastSubmittedCode = null;
      });
    } catch (_) {
      setState(() {
        _error = '연결에 실패했습니다. 잠시 후 다시 시도해 주세요.';
        _lastSubmittedCode = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEditLabelSheet(LinkedStudent student) async {
    final guestMessage = _guestLinkBlockedMessage();
    if (guestMessage != null) {
      setState(() => _error = guestMessage);
      return;
    }

    final controller = TextEditingController(text: student.guardianLabel ?? '');
    final saved = await showModalBottomSheet<bool>(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '표시 이름 변경',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '학생 계정 이름: ${student.displayName}',
                style: const TextStyle(color: AppColors.textSub, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: '부모에게 보이는 이름',
                  hintText: student.displayName,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  backgroundColor: AppColors.success,
                ),
                child: const Text('저장'),
              ),
              TextButton(
                onPressed: () {
                  controller.clear();
                  Navigator.of(context).pop(true);
                },
                child: const Text('학생 계정 이름으로 되돌리기'),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true || !mounted) {
      controller.dispose();
      return;
    }

    final trimmed = controller.text.trim();
    controller.dispose();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.apiClient.updateLinkedStudentLabel(
        studentId: student.id,
        guardianLabel: trimmed.isEmpty ? null : trimmed,
      );
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('표시 이름을 저장했습니다.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '표시 이름을 저장하지 못했습니다.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.linkedStudents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Center(
            child: HeroIcon3d(
              asset: 'assets/icons/3d/link_student.webp',
              tint: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        if (students.isNotEmpty) ...[
          Text(
            '연결된 ${widget.compact ? "학생" : "자녀"} ${students.length}명',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              children: [
                for (var i = 0; i < students.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: AppColors.border),
                  Row(
                    children: [
                      LinkedStudentAvatar(
                        student: students[i],
                        apiBaseUrl: widget.apiClient.baseUrl,
                        size: 36,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              students[i].labelForGuardian,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              students[i].studentCode,
                              style: const TextStyle(
                                color: AppColors.textSub,
                                fontSize: 12,
                              ),
                            ),
                            if (students[i].hasCustomGuardianLabel)
                              Text(
                                '계정 이름: ${students[i].displayName}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '표시 이름 변경',
                        onPressed: _loading
                            ? null
                            : () => _showEditLabelSheet(students[i]),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Text(
          students.isEmpty ? '학생 고유번호 입력' : '자녀 추가하기',
          style: TextStyle(
            fontSize: widget.compact ? 15 : TabletLayout.titleSection(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          '복사한 코드를 붙여넣거나 직접 입력하세요.',
          style: TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.sm),
        StudentCodeInputField(
          controller: _codeController,
          enabled: !_loading,
          onSubmitted: _loading ? null : (_) => _link(),
          suffixIcon: _fieldSuffix,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.accent, height: 1.45),
            ),
          ),
        ],
        if (widget.showConnectButton) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _loading ? null : () => _link(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              backgroundColor: AppColors.success,
            ),
            icon: _loading
                ? const SizedBox.shrink()
                : const Icon(Icons.add_link_rounded),
            label: Text(students.isEmpty ? '학생 연결하기' : '자녀 추가'),
          ),
        ],
        if (widget.showInlineGuide && !widget.compact) ...[
          const SizedBox(height: AppSpacing.md),
          const Text(
            '여러 자녀를 등록할 수 있어요. 학생 계정의 WY-XXXXXX 코드를 입력하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSub, height: 1.5, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
