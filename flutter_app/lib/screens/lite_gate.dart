import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'lite_home_screen.dart';

/// 로그인·온보딩 없이 게스트 세션만 준비하고 홈으로 보냅니다.
class LiteGate extends StatefulWidget {
  const LiteGate({
    super.key,
    required this.apiClient,
    required this.authSession,
  });

  final ApiClient apiClient;
  final AuthSession authSession;

  @override
  State<LiteGate> createState() => _LiteGateState();
}

class _LiteGateState extends State<LiteGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await widget.authSession.load();
    if (!widget.authSession.isGuest) {
      await widget.authSession.enterGuestMode(
        await widget.apiClient.deviceScopedUserId,
      );
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return LiteHomeScreen(apiClient: widget.apiClient);
  }
}
