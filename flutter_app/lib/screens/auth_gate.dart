import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/app_prefs.dart';
import '../services/auth_session.dart';
import '../services/oauth_service.dart';
import '../utils/pending_student_link.dart';
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
    try {
      await _bootstrapInner().timeout(const Duration(seconds: 8));
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthGate] bootstrap timeout (web hot restart?): $e');
      }
      _recoverGuestSession();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthGate] bootstrap failed: $e');
      }
      _recoverGuestSession();
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  Future<void> _bootstrapInner() async {
    await widget.authSession.load();
    await captureInitialStudentLinkCode();
    if (widget.authSession.isSignedIn) {
      try {
        final me = await widget.apiClient.fetchMe();
        if (me.user.isGuardian) {
          await widget.apiClient.fetchLinkedStudents();
        }
        if (mounted && widget.authSession.isProfileComplete) {
          setState(() => _profileOnboardingDismissed = true);
        }
      } catch (_) {
        await widget.authSession.clear();
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

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
