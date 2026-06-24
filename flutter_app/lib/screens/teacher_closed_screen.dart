import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../theme/app_design_system.dart';
import '../services/api_client.dart';

/// 교사 계정 일시 중단 안내
class TeacherClosedScreen extends StatelessWidget {
  const TeacherClosedScreen({
    super.key,
    required this.apiClient,
  });

  final ApiClient apiClient;

  Future<void> _logout(BuildContext context) async {
    apiClient.invalidateLearningProfileCache();
    await apiClient.authSession.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: TabletBody(
          child: Padding(
            padding: TabletLayout.pagePadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.construction_outlined,
                  size: 56,
                  color: AppColors.textSub,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  '교사 계정 준비 중',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TabletLayout.titleSection(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  '교사 기능은 현재 점검 중입니다.\n학부모 또는 학생 계정으로 이용해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSub, height: 1.55),
                ),
                const SizedBox(height: AppSpacing.section),
                FilledButton(
                  onPressed: () => _logout(context),
                  child: const Text('다른 계정으로 시작'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
