import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  bool _loading = false;
  String? _error;
  AppUserRole? _pendingRole;
  String? _grade = '중1';
  final _orgController = TextEditingController();

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
      if (!mounted) return;
      Navigator.of(context).pop(role);
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
    return Scaffold(
      appBar: AppBar(title: const Text('역할 선택')),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Text(
                '어떤 계정으로 이용하시나요?',
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '학생은 풀이 분석·연습을, 학부모·교사는 연결된 학생의 활동과 수준을 확인합니다.',
                style: TextStyle(color: Color(0xFFCBD5E1), height: 1.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
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
                body: '자녀 학생 고유번호로 연결 후 활동·수준 확인',
                icon: Icons.family_restroom_rounded,
                selected: _pendingRole == AppUserRole.parent,
                onTap: () => setState(() => _pendingRole = AppUserRole.parent),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: '교사',
                body: '학생 고유번호로 연결 후 학습 현황 확인',
                icon: Icons.menu_book_rounded,
                selected: _pendingRole == AppUserRole.teacher,
                onTap: () => setState(() => _pendingRole = AppUserRole.teacher),
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
              if (_pendingRole == AppUserRole.teacher) ...[
                const SizedBox(height: 20),
                const Text(
                  '기관명 (선택)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _orgController,
                  decoration: const InputDecoration(
                    hintText: '예) 스마트수학학원',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_pendingRole != null) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _confirm,
                  child: Text(_loading ? '설정 중...' : '시작하기'),
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
      color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
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
                  ? const Color(0xFF2563EB)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF60A5FA), size: 28),
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
                        color: Color(0xFF94A3B8),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF60A5FA)),
            ],
          ),
        ),
      ),
    );
  }
}
