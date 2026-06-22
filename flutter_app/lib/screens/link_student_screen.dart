import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import '../utils/pending_student_link.dart';
import '../utils/student_code_format.dart';
import '../widgets/student_code_input_field.dart';
import '../widgets/student_link_guide.dart';

class LinkStudentScreen extends StatefulWidget {
  const LinkStudentScreen({
    super.key,
    required this.apiClient,
    this.onLinked,
  });

  final ApiClient apiClient;
  final VoidCallback? onLinked;

  @override
  State<LinkStudentScreen> createState() => _LinkStudentScreenState();
}

class _LinkStudentScreenState extends State<LinkStudentScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _lastSubmittedCode;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCodeChanged);
    _applyPendingLinkCode();
  }

  Future<void> _applyPendingLinkCode() async {
    final pending = await consumePendingStudentLinkCode();
    if (pending == null || !mounted) return;
    _controller.text = pending;
  }

  Future<void> _pasteCode() async {
    if (_loading) return;
    final pasted = await pasteStudentCodeInto(_controller);
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
    _controller.removeListener(_onCodeChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_loading) return;
    final raw = _controller.text.trim();
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

  Future<void> _link({String? code, bool auto = false}) async {
    if (widget.apiClient.authSession.isGuest) {
      setState(
        () => _error = '학생 연결은 가입 후 이용할 수 있습니다. 설정에서 로그인해 주세요.',
      );
      return;
    }

    final normalized =
        (code ?? parseStudentCodeFromText(_controller.text))?.trim().toUpperCase();
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
      if (!mounted) return;
      widget.onLinked?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.displayName} 학생과 연결되었습니다.')),
      );
      Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('학생 연결')),
      body: SafeArea(
        child: TabletBody(
          child: Padding(
            padding: TabletLayout.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '학생 고유번호 입력',
                  style: TextStyle(
                    fontSize: TabletLayout.titleSection(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '복사한 코드를 붙여넣거나 직접 입력하세요.',
                  style: TextStyle(color: AppColors.textSub, height: 1.5),
                ),
                const SizedBox(height: 24),
                StudentCodeInputField(
                  controller: _controller,
                  enabled: !_loading,
                  onSubmitted: _loading ? null : (_) => _link(),
                  suffixIcon: _fieldSuffix,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.accent, height: 1.45),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                StudentLinkGuide(
                  role: widget.apiClient.authSession.user?.role,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
