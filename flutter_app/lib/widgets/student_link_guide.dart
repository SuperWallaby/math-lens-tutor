import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_design_system.dart';

/// 학생 고유번호를 **어디서** 찾는지 — 한 줄 보조 안내.
class StudentLinkGuide extends StatelessWidget {
  const StudentLinkGuide({
    super.key,
    this.role = AppUserRole.parent,
  });

  final AppUserRole? role;

  @override
  Widget build(BuildContext context) {
    final path = role == AppUserRole.teacher
        ? '학생 앱 → 설정 탭 → 「내 학생 고유번호」'
        : '자녀 앱 → 설정 탭 → 「내 학생 고유번호」';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        '번호는 어디서 보나요?\n$path',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.95),
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );
  }
}
