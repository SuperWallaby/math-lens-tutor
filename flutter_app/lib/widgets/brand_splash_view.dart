import 'package:flutter/material.dart';

import '../app_variant.dart';
import '../theme/app_design_system.dart';
import 'glass.dart';

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
      backgroundColor: Colors.transparent,
      body: GlassAtmosphere(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassPanel(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      width: 220,
                      height: 220,
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
                  ),
                  const SizedBox(height: 28),
                  Text(
                    appDisplayName,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '오늘, 틀린 거부터.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text.withValues(alpha: 0.92),
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
      ),
    );
  }
}
