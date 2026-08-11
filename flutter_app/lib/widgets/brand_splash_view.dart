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

  static const _heroAsset = 'assets/splash/brand_hero.png';
  static const _fallbackAsset = 'assets/onboarding/student/01.webp';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
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
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '틀린 문제를 사진으로 올리면\n바로 분석해 드려요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 28),
                if (showProgress) ...[
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSub,
                    fontWeight: FontWeight.w500,
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
