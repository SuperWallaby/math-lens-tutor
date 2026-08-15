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
import '../widgets/glass.dart';
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
    this.matchPinPreview = false,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;
  final VoidCallback onSignedIn;
  final VoidCallback? onContinueAsGuest;
  final bool signupOnly;
  final bool matchPinPreview;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  StreamSubscription<String>? _magicLinkSub;

  bool _loading = false;
  String? _error;
  String? _sentEmail;
  String? _devMagicLink;

  @override
  void initState() {
    super.initState();
    _magicLinkSub = MagicLinkAuth.instance.tokens.listen(_verifyMagicToken);

    if (kDebugMode && _emailController.text.trim().isEmpty) {
      _emailController.text = _devBypassEmail;
    }

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
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.border, height: 1, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.9),
              fontSize: TabletLayout.bodySmall(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.border, height: 1, thickness: 1),
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
        GlassField(
          hint: '이메일',
          icon: Icons.mail_outline,
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          enabled: !_loading,
          onSubmitted: (_) => _sendMagicLink(),
        ),
        const SizedBox(height: 12),
        GlassField(
          hint: '비밀번호',
          icon: Icons.lock_outline,
          obscureText: true,
          enabled: !_loading,
          onSubmitted: (_) => _sendMagicLink(),
        ),
        const SizedBox(height: 18),
        GlassButton(
          label: '시작하기',
          onPressed: _loading ? null : _sendMagicLink,
        ),
      ],
    );
  }

  Widget _heroHeader() {
    final headline = widget.signupOnly
        ? '체험 기록을 계정에 저장해요'
        : '수학, 왜 틀렸는지\n먼저 보여드릴게요';

    return Column(
      children: [
        Text(
          appDisplayName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: TabletLayout.titleHero(context) + 10,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: TabletLayout.body(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textSub,
            height: 1.45,
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
      backgroundColor: Colors.transparent,
      body: GlassAtmosphere(
        child: SafeArea(
          child: Stack(
            children: [
              TabletBody(
                child: ListView(
                  padding: TabletLayout.pagePadding(context),
                  children: [
                    const SizedBox(height: 12),
                    const SizedBox(height: 28),
                    _heroHeader(),
                    const SizedBox(height: 36),
                    if (_error != null) ...[
                      GlassPanel(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _emailSection(),
                    if (widget.onContinueAsGuest != null) ...[
                      const SizedBox(height: 12),
                      if (widget.matchPinPreview)
                        TextButton(
                          onPressed: _loading ? null : widget.onContinueAsGuest,
                          child: const Text(
                            '게스트로 둘러보기',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSub,
                            ),
                          ),
                        )
                      else
                        GlassButton(
                          label: '게스트로 둘러보기',
                          primary: false,
                          onPressed: _loading ? null : widget.onContinueAsGuest,
                        ),
                    ],
                    if (!widget.matchPinPreview) ...[
                    const SizedBox(height: AppSpacing.section),
                    _orDivider(),
                    const SizedBox(height: AppSpacing.lg),
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
                    ],
                    if (_loading) ...[
                      const SizedBox(height: 24),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              if (!widget.matchPinPreview)
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
      ),
    );
  }
}
