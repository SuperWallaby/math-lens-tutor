import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({
    super.key,
    required this.apiClient,
    this.changingAccount = false,
    this.initialRole,
    this.initialGrade,
  });

  final ApiClient apiClient;
  final bool changingAccount;
  final AppUserRole? initialRole;
  final String? initialGrade;

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  bool _loading = false;
  String? _error;
  AppUserRole? _pendingRole;
  String? _grade = '중1';
  final _orgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pendingRole = widget.initialRole;
    _grade = widget.initialGrade ?? '중1';
  }

  static const _grades = [
    '초1',
    '초2',
    '초3',
    '초4',
    '초5',
    '초6',
    '중1',
    '중2',
    '중3',
    '고1',
    '고2',
    '고3',
  ];

  @override
  void dispose() {
    _orgController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final role = _pendingRole;
    if (role == null) return;

    if (role == AppUserRole.student && (_grade == null || _grade!.isEmpty)) {
      setState(() => _error = '학년을 선택해 주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.apiClient.completeProfile(
        role,
        grade: role == AppUserRole.student ? _grade : null,
        organizationName: role == AppUserRole.teacher
            ? _orgController.text
            : null,
      );
      widget.apiClient.invalidateLearningProfileCache();
      if (!mounted) return;
      final changing = widget.changingAccount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changing
                ? '계정 타입을 변경했습니다.'
                : '프로필 설정을 완료했습니다.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final changing = widget.changingAccount;

    return Scaffold(
      appBar: AppBar(
        title: Text(changing ? '계정 타입 변경' : '역할 선택'),
      ),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Text(
                changing ? '이용 중인 계정 타입을 바꿉니다' : '어떤 계정으로 이용하시나요?',
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                changing
                    ? '학생 ↔ 학부모 전환 시 학생 연결 정보가 초기화될 수 있어요.'
                    : '학생은 풀이 분석·연습을, 학부모는 자녀 학습을 함께 돕습니다.',
                style: const TextStyle(color: AppColors.textSub, height: 1.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.accent)),
              ],
              const SizedBox(height: 24),
              _RoleCard(
                title: '학생',
                body: '풀이 사진 분석, 유사 문제 연습, 내 학습 대시보드',
                icon: Icons.school_rounded,
                selected: _pendingRole == AppUserRole.student,
                onTap: () => setState(() => _pendingRole = AppUserRole.student),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: '학부모',
                body: '오늘의 코칭 질문·틀린 문제 설명으로 자녀 학습 돕기',
                icon: Icons.family_restroom_rounded,
                selected: _pendingRole == AppUserRole.parent,
                onTap: () => setState(() => _pendingRole = AppUserRole.parent),
              ),
              if (_pendingRole == AppUserRole.student) ...[
                const SizedBox(height: 20),
                const Text(
                  '학년',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                DropdownMenu<String>(
                  initialSelection: _grade,
                  dropdownMenuEntries: [
                    for (final grade in _grades)
                      DropdownMenuEntry(value: grade, label: grade),
                  ],
                  onSelected: (value) => setState(() => _grade = value),
                ),
              ],
              if (_pendingRole != null) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _confirm,
                  child: Text(
                    _loading
                        ? '설정 중...'
                        : changing
                            ? '변경하기'
                            : '시작하기',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
    required this.selected,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: const TextStyle(
                        color: AppColors.textSub,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
