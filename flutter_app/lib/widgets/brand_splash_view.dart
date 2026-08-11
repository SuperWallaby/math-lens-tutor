import 'package:flutter/material.dart';

import '../app_variant.dart';
import '../theme/app_design_system.dart';

/// 앱 부팅·짧은 대기 구간에 쓰는 브랜드 로딩 화면.
class BrandSplashView extends StatelessWidget {
  const BrandSplashView({
    super.key,
    this.message = '잠시만요',
    this.showProgress = true,
  });

  final String message;
  final bool showProgress;

  static const _heroAsset = 'assets/onboarding/student/01.webp';
  static const _fallbackAsset = 'assets/icons/3d/practice_start.webp';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    _heroAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Image.asset(
                      _fallbackAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error2, stackTrace2) => const Icon(
                        Icons.auto_awesome_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  appDisplayName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '틀린 문제, 사진 한 장이면 됩니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI가 왜 틀렸는지 알려주고\n비슷한 문제로 바로 훈련해요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSub.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 30),
                if (showProgress) ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
