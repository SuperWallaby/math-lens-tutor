import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_base_url.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import '../theme/app_design_system.dart';
import 'app_restart.dart';
import 'dev_accounts.dart';
import 'dev_oauth_accounts.dart';
import 'dev_tools.dart';

/// 디버그 빌드 전용 플로팅 개발자 메뉴.
class DevMenuOverlay extends StatelessWidget {
  const DevMenuOverlay({
    super.key,
    required this.apiClient,
    required this.authSession,
    required this.child,
  });

  final ApiClient apiClient;
  final AuthSession authSession;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 12,
          bottom: 92,
          child: SafeArea(
            child: _DevMenuFab(
              onPressed: () => _openSheet(context),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) {
      debugPrint('[dev_menu] Navigator not found — cannot open sheet');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (sheetContext) {
        return _DevMenuSheet(
          apiClient: apiClient,
          authSession: authSession,
          onRestart: () {
            Navigator.of(sheetContext).pop();
            AppRestart.restart(context);
          },
        );
      },
    );
  }
}

class _DevMenuFab extends StatelessWidget {
  const _DevMenuFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.developer_mode_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _DevMenuSheet extends StatefulWidget {
  const _DevMenuSheet({
    required this.apiClient,
    required this.authSession,
    required this.onRestart,
  });

  final ApiClient apiClient;
  final AuthSession authSession;
  final VoidCallback onRestart;

  @override
  State<_DevMenuSheet> createState() => _DevMenuSheetState();
}

class _DevMenuSheetState extends State<_DevMenuSheet> {
  bool _busy = false;

  Future<void> _run(String successMessage, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchRole(AppUserRole role) async {
    await _run('${role.label} 게스트로 전환했습니다', () async {
      await applyDevGuestPersona(
        authSession: widget.authSession,
        apiClient: widget.apiClient,
        role: role,
      );
      widget.onRestart();
    });
  }

  Future<void> _loginDevAccount(String accountId, String label) async {
    await _run('$label 로 로그인했습니다', () async {
      await loginAsDevEmptyAccount(
        authSession: widget.authSession,
        apiClient: widget.apiClient,
        accountId: accountId,
      );
      widget.onRestart();
    });
  }

  Future<void> _loginDevOAuth(String accountId, String label) async {
    await _run('$label 로 로그인했습니다', () async {
      await widget.apiClient.devOAuthLogin(accountId);
      widget.onRestart();
    });
  }

  Future<void> _purgeDevOAuth(String accountId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 탈퇴·데이터 삭제'),
        content: Text(
          '$label\n\n'
          '서버에서 계정과 학습 데이터를 완전히 삭제합니다.\n'
          'OAuth 재가입·온보딩 테스트용입니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await widget.apiClient.devOAuthPurge(accountId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData _oauthProviderIcon(String provider) {
    return switch (provider) {
      'kakao' => Icons.chat_bubble_rounded,
      'google' => Icons.g_mobiledata_rounded,
      'apple' => Icons.apple_rounded,
      _ => Icons.account_circle_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final sessionText = describeDevSession(widget.authSession);
    final apiUrl = resolveApiBaseUrl();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
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
            Row(
              children: [
                const Icon(Icons.developer_mode_rounded, size: 20),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    '개발자 메뉴',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoTile(label: '세션', value: sessionText),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoTile(label: 'API', value: apiUrl),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('액션'),
          _ActionTile(
            icon: Icons.refresh_rounded,
            title: '앱 재시작',
            subtitle: '위젯 트리만 다시 빌드 (hot restart 대용)',
            enabled: !_busy,
            onTap: widget.onRestart,
          ),
          _ActionTile(
            icon: Icons.delete_sweep_outlined,
            title: '로컬 데이터 삭제',
            subtitle: 'SharedPreferences + 로그인 세션 초기화',
            enabled: !_busy,
            onTap: () => _run('로컬 데이터를 삭제했습니다', () async {
              await clearAllLocalData(widget.authSession);
              widget.onRestart();
            }),
          ),
          _ActionTile(
            icon: Icons.tour_outlined,
            title: '앱 소개 온보딩 리셋',
            subtitle: '첫 실행 튜토리얼 다시 보기',
            enabled: !_busy,
            onTap: () => _run('소개 온보딩을 리셋했습니다', resetIntroOnboarding),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('OAuth 계정 로그인'),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '카카오·Apple OAuth DB 계정으로 바로 로그인합니다.',
            style: TextStyle(
              color: AppColors.textSub,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final account in devOAuthLoginOptionsList)
                ActionChip(
                  avatar: Icon(
                    _oauthProviderIcon(account.provider),
                    size: 18,
                  ),
                  label: Text(account.label),
                  onPressed: _busy
                      ? null
                      : () => _loginDevOAuth(account.id, account.label),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('OAuth 계정 탈퇴·데이터 삭제'),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '테스트 계정을 서버에서 완전히 삭제합니다. 재가입·온보딩 테스트 전에 사용하세요.',
            style: TextStyle(
              color: AppColors.textSub,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final account in devOAuthLoginOptionsList)
                ActionChip(
                  avatar: Icon(
                    Icons.delete_forever_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  label: Text('${account.label} 삭제'),
                  onPressed: _busy
                      ? null
                      : () => _purgeDevOAuth(account.id, account.label),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('빈 계정 로그인'),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '역할·학년 미설정 상태로 서버 계정에 로그인합니다. 온보딩부터 테스트할 때 사용하세요.',
            style: TextStyle(
              color: AppColors.textSub,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final account in devAccountOptionsList)
                ActionChip(
                  avatar: const Icon(Icons.person_outline_rounded, size: 18),
                  label: Text(account.label),
                  onPressed: _busy
                      ? null
                      : () => _loginDevAccount(account.id, account.label),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('게스트 역할 전환'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '학부모·교사는 mock 자녀(${devMockLinkedStudent.studentCode})가 연결됩니다.',
            style: const TextStyle(
              color: AppColors.textSub,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final role in AppUserRole.values)
                ActionChip(
                  label: Text(role.label),
                  onPressed: _busy ? null : () => _switchRole(role),
                ),
            ],
          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSub,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSub, fontSize: 12),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
