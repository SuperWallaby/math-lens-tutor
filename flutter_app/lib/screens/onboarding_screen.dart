import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/app_prefs.dart';
import '../theme/app_design_system.dart';
import 'onboarding_feature_slides.dart';

const kOnboardingCompleteKey = 'onboarding_complete';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.apiClient,
    required this.onComplete,
  });

  final ApiClient apiClient;
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  late final List<OnboardingFeatureSlide> _slides;
  int _page = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final role = widget.apiClient.authSession.user?.role;
    _slides = onboardingSlidesForRole(role);
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final prefs = await getAppPrefs();
    if (!mounted) return;
    await prefs.setBool(kOnboardingCompleteKey, true);
    if (!mounted) return;
    widget.onComplete();
  }

  void _onPageChanged(int index) {
    setState(() => _page = index);
  }

  String get _roleLabel {
    final role = widget.apiClient.authSession.user?.role;
    switch (role) {
      case AppUserRole.student:
        return '학생';
      case AppUserRole.parent:
        return '학부모';
      case AppUserRole.teacher:
        return '교사';
      case null:
        return '우열';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page >= _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: TabletBody(
          child: Padding(
            padding: TabletLayout.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$_roleLabel을 위한 우열',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TabletLayout.titleSection(context),
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '이렇게 사용할 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSub,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double scale = 1.0;
                          if (_pageController.position.haveDimensions) {
                            final page =
                                _pageController.page ?? index.toDouble();
                            scale =
                                (1 - (page - index).abs() * 0.06).clamp(0.94, 1.0);
                          }
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: _FeatureScreenshotCard(slide: _slides[index]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _PageDots(count: _slides.length, index: _page),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLast
                        ? _finish
                        : () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          },
                    style: AppButtonStyles.filledKeyAction(),
                    child: Text(isLast ? '시작하기' : '다음'),
                  ),
                ),
                if (!isLast) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _finish,
                    child: const Text(
                      '건너뛰기',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 실제 앱 UI 스크린샷을 세로형 카드로 보여줍니다 (3D 아이콘 아님).
class _FeatureScreenshotCard extends StatelessWidget {
  const _FeatureScreenshotCard({required this.slide});

  final OnboardingFeatureSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceElevated,
                  ),
                  child: Image.asset(
                    slide.imageAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      slide.body,
                      style: const TextStyle(
                        color: AppColors.textSub,
                        height: 1.45,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.borderStrong,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        );
      }),
    );
  }
}

Future<bool> isOnboardingComplete() async {
  try {
    final prefs = await getAppPrefs().timeout(const Duration(seconds: 4));
    return prefs.getBool(kOnboardingCompleteKey) ?? false;
  } on TimeoutException {
    if (kDebugMode) {
      debugPrint('[onboarding] prefs timeout — skip onboarding gate');
    }
    return true;
  }
}
