import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/app_prefs.dart';
import '../services/auth_session.dart';
import '../services/oauth_service.dart';
import '../utils/pending_student_link.dart';
import '../widgets/brand_splash_view.dart';
import 'app_shell.dart';
import 'guardian_link_required_screen.dart';
import 'teacher_closed_screen.dart';
import 'profile_onboarding_screen.dart';
import 'signup_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.apiClient,
    required this.authSession,
    required this.oauthService,
  });

  final ApiClient apiClient;
  final AuthSession authSession;
  final OAuthService oauthService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;

  /// API로 profileComplete가 true가 되어도, 온보딩 UI는 onComplete까지 유지
  bool _profileOnboardingDismissed = false;

  /// 스플래시가 너무 빨리 사라지지 않도록 최소 표시 시간
  static const _minSplash = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _profileOnboardingDismissed = widget.authSession.isProfileComplete;
    widget.apiClient.onUnauthorized = _handleUnauthorized;
    widget.authSession.addListener(_onSessionChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    widget.authSession.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (!widget.authSession.canUseApp) {
      setState(() => _profileOnboardingDismissed = false);
      return;
    }
    if (!widget.authSession.isProfileComplete) {
      setState(() => _profileOnboardingDismissed = false);
      return;
    }
    setState(() {});
  }

  Future<void> _bootstrap() async {
    final started = DateTime.now();
    try {
      await widget.authSession.load();
      if (widget.authSession.isProfileComplete) {
        _profileOnboardingDismissed = true;
      }

      unawaited(captureInitialStudentLinkCode());

      // 최소 스플래시 시간과 세션 동기화를 함께 진행
      final remaining = _minSplash - DateTime.now().difference(started);
      final waitSplash = remaining > Duration.zero
          ? Future<void>.delayed(remaining)
          : Future<void>.value();

      Future<void> syncSession() async {
        if (!widget.authSession.isSignedIn) return;
        try {
          final me = await widget.apiClient
              .fetchMe()
              .timeout(const Duration(seconds: 8));
          if (me.user.isGuardian) {
            await widget.apiClient
                .fetchLinkedStudents()
                .timeout(const Duration(seconds: 8));
          }
          if (mounted && widget.authSession.isProfileComplete) {
            _profileOnboardingDismissed = true;
          }
        } on TimeoutException catch (e) {
          if (kDebugMode) {
            debugPrint('[AuthGate] fetchMe timeout: $e');
          }
        } catch (_) {
          await widget.authSession.clear();
        }
      }

      // 스플래시는 최소 시간 보장. 네트워크는 그 안/뒤에서 병행.
      await Future.wait<void>([waitSplash, syncSession()]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthGate] bootstrap failed: $e');
      }
      _recoverGuestSession();
      final remaining = _minSplash - DateTime.now().difference(started);
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  void _recoverGuestSession() {
    resetAppPrefsCache();
    if (!widget.authSession.canUseApp) {
      widget.authSession.enterGuestRecovery(
        'device:web-recovery-${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  Future<void> _handleUnauthorized() async {
    if (!mounted || !widget.authSession.isSignedIn) return;
    await widget.authSession.clear();
    if (mounted) setState(() {});
  }

  Future<void> _backToAppStart() async {
    await widget.apiClient.signOutToAppStart();
    if (mounted) {
      setState(() => _profileOnboardingDismissed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const BrandSplashView(message: '학습 준비를 하고 있어요');
    }

    final session = widget.authSession;
    if (!session.isSignedIn && !session.isGuest) {
      return SignupScreen(
        apiClient: widget.apiClient,
        oauthService: widget.oauthService,
        onSignedIn: () => setState(() {
          if (widget.authSession.isProfileComplete) {
            _profileOnboardingDismissed = true;
          }
        }),
        onContinueAsGuest: () async {
          await session.enterGuestMode(
            await widget.apiClient.deviceScopedUserId,
          );
          if (mounted) setState(() => _profileOnboardingDismissed = false);
        },
      );
    }

    if (!_profileOnboardingDismissed &&
        (session.isGuest || !session.isProfileComplete)) {
      return ProfileOnboardingScreen(
        apiClient: widget.apiClient,
        oauthService: widget.oauthService,
        onComplete: () => setState(() => _profileOnboardingDismissed = true),
      );
    }

    if ((session.user?.isGuardian ?? false) &&
        session.linkedStudents.isEmpty &&
        !session.isGuest) {
      return GuardianLinkRequiredScreen(
        apiClient: widget.apiClient,
        onLinked: () => setState(() {}),
        onBackToAppStart: _backToAppStart,
      );
    }

    if (session.user?.role == AppUserRole.teacher && !session.isGuest) {
      return TeacherClosedScreen(
        apiClient: widget.apiClient,
      );
    }

    return AppBootstrap(
      apiClient: widget.apiClient,
      oauthService: widget.oauthService,
    );
  }
}
