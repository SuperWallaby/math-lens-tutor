import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// 로딩 한 줄. `web/index.html` 과 같은 목록을 유지한다.
const kSplashLines = <String>[
  '배우고 때로 익히면, 또한 기쁘지 아니한가.',
  '시작이 반이다.',
  '천 리 길도 한 걸음부터.',
  '노력은 배신하지 않는다.',
  '실패는 성공의 어머니.',
  '늦었다고 생각할 때가 가장 빠르다.',
  '천재는 1%의 영감과 99%의 노력이다.',
  '아는 것이 힘이다.',
  '반복은 학습의 어머니다.',
  '배움에는 왕도가 없다.',
  '오늘 걷지 않으면 내일은 뛰어야 한다.',
  '구슬이 서 말이라도 꿰어야 보배.',
  '티끌 모아 태산.',
  '독서백편, 뜻이 스스로 드러난다.',
  '작은 성취가 큰 자신감을 만든다.',
  '이해한 것만 내 것이다.',
  '질문은 답을 부른다.',
  '공부는 남을 따라가는 게 아니라 나를 이기는 일이다.',
  '로마는 하루아침에 이루어지지 않았다.',
  '어제보다 나은 오늘이면 된다.',
];

/// 앱 부팅·짧은 대기 — 아이콘 흔들림 + 랜덤 한 줄.
class BrandSplashView extends StatefulWidget {
  const BrandSplashView({
    super.key,
    this.message = '잠시만요',
    this.showProgress = true,
  });

  final String message;
  final bool showProgress;

  @override
  State<BrandSplashView> createState() => _BrandSplashViewState();
}

class _BrandSplashViewState extends State<BrandSplashView>
    with SingleTickerProviderStateMixin {
  static const _iconAsset = 'assets/brand/app_icon.png';

  late final AnimationController _sway;
  late final String _line;

  @override
  void initState() {
    super.initState();
    _line = kSplashLines[math.Random().nextInt(kSplashLines.length)];
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.primarySoft,
              AppColors.primary,
              AppColors.primaryDark,
            ],
            stops: [0.0, 0.48, 1.0],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: reduce
                      ? const AlwaysStoppedAnimation<double>(0.5)
                      : _sway,
                  builder: (context, child) {
                    final t = reduce
                        ? 0.5
                        : Curves.easeInOut.transform(_sway.value);
                    return Transform.translate(
                      offset: Offset((t - 0.5) * 36, 0),
                      child: Transform.rotate(
                        angle: (t - 0.5) * 0.1,
                        child: child,
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: Image.asset(
                      _iconAsset,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, error, stackTrace) => const Icon(
                        Icons.auto_awesome_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _line,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: Colors.white,
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
