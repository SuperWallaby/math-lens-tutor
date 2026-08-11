import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_variant.dart';
import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../theme/app_design_system.dart';
import '../services/api_client.dart';
import '../services/magic_link_auth.dart';
import '../services/oauth_service.dart';
import '../dev/dev_oauth_login_chip.dart';
import '../widgets/oauth_sign_in_button.dart';

/// 서버 bypass (`devstudy*@wooyeol.com`, dev `crawl123@naver.com`) 와 동일한 기본값
const _devBypassEmail = 'crawl123@naver.com';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.apiClient,
    required this.oauthService,
    required this.onSignedIn,
    this.onContinueAsGuest,
    this.signupOnly = false,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;
  final VoidCallback onSignedIn;
  final VoidCallback? onContinueAsGuest;
  final bool signupOnly;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  StreamSubscription<String>? _magicLinkSub;

  bool _loading = false;
  bool _showEmailInput = false;
  String? _error;
  String? _sentEmail;
  String? _devMagicLink;

  @override
  void initState() {
    super.initState();
    _magicLinkSub = MagicLinkAuth.instance.tokens.listen(_verifyMagicToken);

    final webToken = readWebMagicLinkToken();
    if (webToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyMagicToken(webToken);
      });
    }
  }

  @override
  void dispose() {
    _magicLinkSub?.cancel();
    _emailFocusNode.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _openEmailInput() {
    if (_loading || _sentEmail != null) return;

    setState(() {
      _showEmailInput = true;
      _error = null;
      if (kDebugMode && _emailController.text.trim().isEmpty) {
        _emailController.text = _devBypassEmail;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _emailFocusNode.requestFocus();
      }
    });
  }

  Future<void> _continueAfterAuth(AppUser user) async {
    if (!mounted) return;
    // 프로필 온보딩은 AuthGate 가 담당 (중복 push 시 완료 후 다시 role부터 시작하는 버그)
    widget.onSignedIn();
  }

  Future<void> _verifyMagicToken(String token) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await widget.apiClient.verifyMagicLink(token);
      await _continueAfterAuth(user);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = '로그인 링크 확인에 실패했습니다.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleOAuth(
    Future<OAuthCredentialBundle> Function() signIn,
  ) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = await signIn();
      final user = await widget.apiClient.signInWithOAuth(
        credential,
        signupOnly: widget.signupOnly,
      );
      await _continueAfterAuth(user);
    } on OAuthException catch (error) {
      setState(() => _error = error.message);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (e) {
      setState(() => _error = kDebugMode
          ? '간편 가입에 실패했습니다. ($e)'
          : '간편 가입에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '이메일 주소를 입력해 주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _devMagicLink = null;
    });

    try {
      final result = await widget.apiClient.sendMagicLink(
        email,
        signupOnly: widget.signupOnly,
      );
      if (result.bypassUser != null) {
        await _continueAfterAuth(result.bypassUser!);
        return;
      }
      setState(() {
        _sentEmail = email;
        _devMagicLink = result.devLink;
        _showEmailInput = false;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (e) {
      setState(() => _error = kDebugMode
          ? '매직 링크 발송에 실패했습니다. ($e)'
          : '매직 링크 발송에 실패했습니다.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _orDivider() {
    const lineColor = Color(0x0A000000);

    return Row(
      children: [
        const Expanded(
          child: Divider(color: lineColor, height: 1, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.75),
              fontSize: TabletLayout.bodySmall(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: lineColor, height: 1, thickness: 1),
        ),
      ],
    );
  }

  Widget _emailSection() {
    if (_sentEmail != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '메일함을 확인해 주세요',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$_sentEmail 로 로그인 링크를 보냈습니다.\n메일의 버튼을 누르면 앱에서 자동으로 로그인됩니다.',
              style: const TextStyle(
                color: AppColors.textSub,
                height: 1.5,
              ),
            ),
            if (_devMagicLink != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '개발용 링크:\n$_devMagicLink',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _sentEmail = null;
                      _devMagicLink = null;
                      _showEmailInput = false;
                    }),
              child: const Text('다른 이메일로 받기'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _loading || _showEmailInput ? null : _openEmailInput,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.text,
              side: BorderSide(color: AppColors.border),
            ),
            child: const Text(
              '이메일로 시작하기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (_showEmailInput) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: '이메일',
              hintText: 'name@example.com',
            ),
            onSubmitted: (_) => _sendMagicLink(),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _sendMagicLink,
              style: AppButtonStyles.filled(),
              child: const Text('로그인 링크 보내기'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _heroHeader() {
    final headline = widget.signupOnly
        ? '새 계정으로 가입하기'
        : '틀린 문제, 사진 한 장이면 됩니다';
    final sub = widget.signupOnly
        ? '체험 중이던 기록을 계정에 저장합니다.\n이미 가입한 계정은 앱을 처음부터 다시 열어 로그인해 주세요.'
        : '가입하면 학습 기록이 계정에 저장돼요.\n간편 로그인으로 바로 시작할 수 있어요.';

    return Column(
      children: [
        Text(
          appDisplayName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: TabletLayout.titleHero(context) + 6,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: TabletLayout.titleSection(context),
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSub,
            fontSize: TabletLayout.body(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.asset(
              'assets/splash/brand_hero.png',
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => const ColoredBox(
                color: AppColors.surfaceElevated,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final kakaoEnabled = resolveKakaoNativeAppKey().isNotEmpty;
    final googleEnabled = isGoogleSignInConfigured;
    final appleEnabled = isAppleSignInAvailable;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFDCEEFF),
                    Color(0xFFF4F7FB),
                    Color(0xFFF7F8FA),
                  ],
                  stops: [0, 0.38, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                TabletBody(
                  child: ListView(
                    padding: TabletLayout.pagePadding(context),
                    children: [
                      const SizedBox(height: 12),
                      _heroHeader(),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.accent),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      OAuthSignInButton(
                        provider: OAuthProvider.kakao,
                        enabled: !_loading && kakaoEnabled,
                        onPressed: () =>
                            _handleOAuth(widget.oauthService.signInWithKakao),
                        label: kakaoEnabled
                            ? '카카오로 시작하기'
                            : '카카오 (앱 키 설정 필요)',
                      ),
                      const SizedBox(height: 12),
                      OAuthSignInButton(
                        provider: OAuthProvider.google,
                        enabled: !_loading && googleEnabled,
                        onPressed: () =>
                            _handleOAuth(widget.oauthService.signInWithGoogle),
                        label: googleEnabled
                            ? 'Google로 시작하기'
                            : 'Google (Client ID 설정 필요)',
                      ),
                      if (appleEnabled) ...[
                        const SizedBox(height: 12),
                        OAuthSignInButton(
                          provider: OAuthProvider.apple,
                          enabled: !_loading,
                          onPressed: () =>
                              _handleOAuth(widget.oauthService.signInWithApple),
                          label: 'Apple로 시작하기',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.section),
                      _orDivider(),
                      const SizedBox(height: AppSpacing.lg),
                      _emailSection(),
                      if (_loading) ...[
                        const SizedBox(height: 24),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      if (widget.onContinueAsGuest != null) ...[
                        const SizedBox(height: AppSpacing.section),
                        Center(
                          child: TextButton(
                            onPressed:
                                _loading ? null : widget.onContinueAsGuest,
                            child: const Text(
                              '로그인 없이 체험하기',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 16,
                  child: DevOAuthLoginChip(
                    apiClient: widget.apiClient,
                    onSignedIn: widget.onSignedIn,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
