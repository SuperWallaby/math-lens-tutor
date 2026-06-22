import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../theme/app_design_system.dart';
import '../services/api_client.dart';
import '../widgets/hero_icon_3d.dart';
import '../widgets/linked_children_panel.dart';
import '../widgets/student_link_guide.dart';

class GuardianLearningGate extends StatelessWidget {
  const GuardianLearningGate({
    super.key,
    required this.apiClient,
    required this.title,
    required this.onStudentChanged,
    required this.child,
  });

  final ApiClient apiClient;
  final String title;
  final VoidCallback onStudentChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: apiClient.authSession,
      builder: (context, _) {
        final linked = apiClient.authSession.linkedStudents;

        if (linked.isEmpty) {
          return ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: HeroIcon3d(
                  asset: 'assets/icons/3d/link_empty.png',
                  tint: AppColors.success,
                  size: 96,
                  iconSize: 60,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                '고유번호 6자리를 모두 입력하면 자동으로 연결됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSub, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xxl),
              LinkedChildrenPanel(
                apiClient: apiClient,
                linkedStudents: linked,
                compact: true,
                onChanged: onStudentChanged,
                onAutoLinked: onStudentChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
              StudentLinkGuide(role: apiClient.authSession.user?.role),
              SizedBox(
                height: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
              ),
            ],
          );
        }

        return child;
      },
    );
  }
}
