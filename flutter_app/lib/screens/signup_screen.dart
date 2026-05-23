import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import 'link_student_screen.dart';
import 'role_select_screen.dart';
import 'student_code_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.apiClient,
    required this.oauthService,
    required this.onSignedIn,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;
  final VoidCallback onSignedIn;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _continueAfterOAuth(AppUser user) async {
    if (!mounted) return;

    if (!user.profileComplete || user.role == null) {
      final role = await Navigator.of(context).push<AppUserRole>(
        MaterialPageRoute(
          builder: (_) => RoleSelectScreen(apiClient: widget.apiClient),
        ),
      );
      if (!mounted || role == null) return;
      final me = await widget.apiClient.fetchMe();
      user = me.user;
    }

    if (!mounted) return;

    if (user.isStudent && user.studentCode != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudentCodeScreen(studentCode: user.studentCode!),
        ),
      );
    } else if (user.isGuardian) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LinkStudentScreen(
            apiClient: widget.apiClient,
            skippable: true,
          ),
        ),
      );
    }

    if (!mounted) return;
    widget.onSignedIn();
  }

  Future<void> _handleOAuth(Future<OAuthCredentialBundle> Function() signIn) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = await signIn();
      final user = await widget.apiClient.signInWithOAuth(credential);
      await _continueAfterOAuth(user);
    } on OAuthException catch (error) {
      setState(() => _error = error.message);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = '간편 가입에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kakaoEnabled = resolveKakaoNativeAppKey().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              const SizedBox(height: 32),
              Text(
                '우열 시작하기',
                style: TextStyle(
                  fontSize: TabletLayout.titleHero(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '로그인 없이, 카카오·Google·Apple로 1초 만에 가입하고 바로 이용할 수 있습니다.',
                style: TextStyle(
                  color: const Color(0xFFCBD5E1),
                  fontSize: TabletLayout.body(context),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFECACA)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _loading || !kakaoEnabled
                    ? null
                    : () => _handleOAuth(widget.oauthService.signInWithKakao),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE500),
                  foregroundColor: const Color(0xFF191919),
                ),
                icon: const Icon(Icons.chat_bubble_rounded),
                label: Text(kakaoEnabled ? '카카오로 시작하기' : '카카오 (앱 키 설정 필요)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _handleOAuth(widget.oauthService.signInWithGoogle),
                icon: const Icon(Icons.g_mobiledata_rounded),
                label: const Text('Google로 시작하기'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _handleOAuth(widget.oauthService.signInWithApple),
                icon: const Icon(Icons.apple),
                label: const Text('Apple로 시작하기'),
              ),
              if (_loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
