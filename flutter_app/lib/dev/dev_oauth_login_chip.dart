import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import 'dev_oauth_accounts.dart';

/// 디버그 빌드 전용 — 카카오/Apple OAuth 계정 즉시 로그인
class DevOAuthLoginChip extends StatelessWidget {
  const DevOAuthLoginChip({
    super.key,
    required this.apiClient,
    required this.onSignedIn,
  });

  final ApiClient apiClient;
  final VoidCallback onSignedIn;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Tooltip(
      message: '개발용 OAuth 로그인',
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: () => _openSheet(context),
          borderRadius: BorderRadius.circular(99),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.developer_mode_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'DEV',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _DevOAuthLoginSheet(
        apiClient: apiClient,
        onSignedIn: onSignedIn,
      ),
    );
  }
}

class _DevOAuthLoginSheet extends StatefulWidget {
  const _DevOAuthLoginSheet({
    required this.apiClient,
    required this.onSignedIn,
  });

  final ApiClient apiClient;
  final VoidCallback onSignedIn;

  @override
  State<_DevOAuthLoginSheet> createState() => _DevOAuthLoginSheetState();
}

class _DevOAuthLoginSheetState extends State<_DevOAuthLoginSheet> {
  String? _busyId;
  String? _error;

  Future<void> _login(DevOAuthLoginOption account) async {
    setState(() {
      _busyId = account.id;
      _error = null;
    });

    try {
      await widget.apiClient.devOAuthLogin(account.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSignedIn();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const Text(
            '개발용 OAuth 로그인',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            '실제 카카오·Apple OAuth 계정으로 바로 들어갑니다.\n(이메일 매직링크 계정과 별개)',
            style: TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final account in devOAuthLoginOptionsList) ...[
            _DevOAuthLoginTile(
              account: account,
              loading: _busyId == account.id,
              enabled: _busyId == null,
              onTap: () => _login(account),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.accent, fontSize: 12, height: 1.45),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _DevOAuthLoginTile extends StatelessWidget {
  const _DevOAuthLoginTile({
    required this.account,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final DevOAuthLoginOption account;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isKakao = account.provider == 'kakao';
    final accent = isKakao ? const Color(0xFFFEE500) : AppColors.text;
    final fg = isKakao ? AppColors.text : Colors.white;
    final icon = isKakao ? Icons.chat_bubble_rounded : Icons.apple_rounded;

    return Material(
      color: isKakao ? accent : AppColors.text,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: enabled && !loading ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      account.email,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
