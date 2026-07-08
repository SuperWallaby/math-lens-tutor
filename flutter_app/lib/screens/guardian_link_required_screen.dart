import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import '../widgets/hero_icon_3d.dart';
import '../widgets/linked_children_panel.dart';
import '../widgets/student_link_guide.dart';

/// 학부모·교사는 자녀/학생 연결 전까지 앱 진입 불가.
class GuardianLinkRequiredScreen extends StatefulWidget {
  const GuardianLinkRequiredScreen({
    super.key,
    required this.apiClient,
    required this.onLinked,
    required this.onBackToAppStart,
  });

  final ApiClient apiClient;
  final VoidCallback onLinked;
  final Future<void> Function() onBackToAppStart;

  @override
  State<GuardianLinkRequiredScreen> createState() =>
      _GuardianLinkRequiredScreenState();
}

class _GuardianLinkRequiredScreenState extends State<GuardianLinkRequiredScreen> {
  bool _busy = false;

  Future<void> _handleBack() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onBackToAppStart();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.authSession.user;
    final isParent = user?.role == AppUserRole.parent;
    final accent = isParent ? AppColors.success : AppColors.teacher;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _busy ? null : _handleBack,
        ),
        title: Text(isParent ? '자녀 연결' : '학생 연결'),
      ),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              const SizedBox(height: 16),
              Center(
                child: HeroIcon3d(
                  asset: 'assets/icons/3d/link_empty.webp',
                  tint: accent,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                isParent ? '자녀를 연결해 주세요' : '학생을 연결해 주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                '고유번호 6자리를 모두 입력하면 자동으로 연결됩니다.\n연결해야 앱을 사용할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSub, height: 1.55),
              ),
              const SizedBox(height: AppSpacing.section),
              ListenableBuilder(
                listenable: widget.apiClient.authSession,
                builder: (context, _) {
                  return LinkedChildrenPanel(
                    apiClient: widget.apiClient,
                    linkedStudents: widget.apiClient.authSession.linkedStudents,
                    compact: true,
                    onChanged: widget.onLinked,
                    onAutoLinked: widget.onLinked,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              StudentLinkGuide(role: user?.role),
              SizedBox(
                height: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
