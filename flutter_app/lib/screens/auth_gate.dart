import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_session.dart';
import '../services/oauth_service.dart';
import 'app_shell.dart';
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

  @override
  void initState() {
    super.initState();
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
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await widget.authSession.load();
    if (widget.authSession.isSignedIn) {
      try {
        final me = await widget.apiClient.fetchMe();
        if (me.user.isGuardian) {
          await widget.apiClient.fetchLinkedStudents();
        }
      } catch (_) {
        await widget.authSession.clear();
      }
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  void _handleUnauthorized() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = widget.authSession;
    if (!session.isSignedIn || !session.isProfileComplete) {
      return SignupScreen(
        apiClient: widget.apiClient,
        oauthService: widget.oauthService,
        onSignedIn: () => setState(() {}),
      );
    }

    return AppBootstrap(apiClient: widget.apiClient);
  }
}
