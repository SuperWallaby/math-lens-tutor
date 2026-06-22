import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// 학생 고유번호 — 입력 중 포맷 강제 없음, 제출 시에만 파싱·검증.
class StudentCodeInputField extends StatelessWidget {
  const StudentCodeInputField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: 'WY-7K3M9P',
        hintStyle: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.85),
          fontWeight: FontWeight.w500,
          fontSize: 20,
          letterSpacing: 1.2,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
