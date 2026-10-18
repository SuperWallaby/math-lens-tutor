import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_design_system.dart';
import '../utils/korean_date.dart';
import 'glass.dart';
import 'profile_avatar.dart' show resolveProfileImageUrl;

/// 홈 파란 무대가 어떤 인사를 건네는지.
enum HomeStageMode { firstVisit, returning }

/// 무대 사용자 줄에 필요한 값만 모은 것.
@immutable
class HomeStageUser {
  const HomeStageUser({
    this.name = '',
    this.grade = '',
    this.organization = '',
    this.imageUrl,
    this.streakWeeks = 0,
    this.isGuest = false,
  });

  /// 학년은 `user.grade`가 비면 학습 프로필의 학년을 쓴다.
  factory HomeStageUser.from(
    AppUser? user,
    LearningProfile profile, {
    required bool isGuest,
  }) {
    final userGrade = user?.grade?.trim() ?? '';
    return HomeStageUser(
      name: user?.displayName ?? '',
      grade: userGrade.isNotEmpty ? userGrade : profile.grade,
      organization: user?.organizationName ?? '',
      imageUrl: resolveProfileImageUrl(null, user?.profileImageUrl),
      streakWeeks: profile.stats.streakWeeks,
      isGuest: isGuest,
    );
  }

  final String name;
  final String grade;
  final String organization;
  final String? imageUrl;
  final int streakWeeks;
  final bool isGuest;

  bool get _hasName => !isGuest && name.trim().isNotEmpty;
}

/// 게스트·이름 없음: 「반가워요」, 그 외: 「{name}님」
String homeStageTitle(HomeStageUser u) =>
    u._hasName ? '${u.name.trim()}님' : '반가워요';

/// 게스트: 「둘러보는 중」, 그 외: 학년 · 학교 (없는 값은 뺀다). 둘 다 없으면 `null`.
String? homeStageSubline(HomeStageUser u) {
  if (u.isGuest) return '둘러보는 중';
  final parts = [
    u.grade.trim(),
    u.organization.trim(),
  ].where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(' · ');
}

bool homeStageShowsStreak(HomeStageMode mode, HomeStageUser u) =>
    mode == HomeStageMode.returning && !u.isGuest && u.streakWeeks >= 1;

String homeStageHeadline(HomeStageMode mode) => switch (mode) {
  HomeStageMode.firstVisit => '오늘은 한 장만\n올려도 돼요',
  HomeStageMode.returning => '어제 막힌 곳부터\n이어가요',
};

const double _kSidePad = 20;
const double _kIconSize = 108;
const double _kIconRightInset = 18;
const double _kIconGap = 12;
const double _kAvatarSize = 40;

/// 하늘색 구간에서 흰 글자가 묻히지 않게 깔아 주는 옅은 남색 그림자.
const List<Shadow> _stageTextShadows = [
  Shadow(color: Color(0x591E46AA), offset: Offset(0, 1), blurRadius: 3),
];

/// 학생 홈 맨 위 파란 무대: 날짜 · 사용자 줄 · 연속 칩 · 인사 문장 · [card] · [footer].
/// 안전 영역 위 여백까지 무대가 채우므로 화면 맨 위에 붙여서 쓴다.
class HomeStage extends StatelessWidget {
  const HomeStage({
    super.key,
    required this.mode,
    required this.user,
    required this.today,
    required this.card,
    this.footer,
  });

  final HomeStageMode mode;
  final HomeStageUser user;
  final DateTime today;
  final Widget card;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 14;
    final subline = homeStageSubline(user);
    // 아이콘 폭 + 오른쪽 여백 + 간격만큼 왼쪽 칸 오른쪽을 비워 글자가 아이콘 밑으로 가지 않게 한다.
    const headerRightReserve =
        _kIconSize + _kIconRightInset + _kIconGap - _kSidePad;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppGradients.stage,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(_kSidePad, top, _kSidePad, 24),
            child: Column(
              // card / footer가 무대 폭을 꽉 채운다.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _kIconSize),
                  child: Padding(
                    padding: const EdgeInsets.only(right: headerRightReserve),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatKoreanDate(today),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            shadows: _stageTextShadows,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xDBFFFFFF),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StageAvatar(user: user),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    homeStageTitle(user),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      shadows: _stageTextShadows,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (subline != null)
                                    Text(
                                      subline,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        shadows: _stageTextShadows,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xCCFFFFFF),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (homeStageShowsStreak(mode, user)) ...[
                          const SizedBox(height: 12),
                          _StreakChip(weeks: user.streakWeeks),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  homeStageHeadline(mode),
                  style: const TextStyle(
                    shadows: _stageTextShadows,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                card,
                if (footer != null) ...[const SizedBox(height: 14), footer!],
              ],
            ),
          ),
          Positioned(
            top: top,
            right: _kIconRightInset,
            child: const _StageIcon(),
          ),
        ],
      ),
    );
  }
}

class _StageIcon extends StatelessWidget {
  const _StageIcon();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x591A2F7A),
              offset: Offset(0, 10),
              blurRadius: 22,
            ),
          ],
        ),
        child: Image.asset(
          'assets/brand/app_icon_cutout.png',
          key: const Key('home-stage-icon'),
          width: _kIconSize,
          height: _kIconSize,
          cacheWidth: 324,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.weeks});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      preset: GlassPreset.onBlue,
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: AppColors.spark,
          ),
          const SizedBox(width: 4),
          Text(
            '$weeks주 연속',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 프로필 사진 → 없거나 실패하면 이니셜. 게스트·이름 없음은 사람 아이콘.
/// 이름 줄과 겹치는 장식이라 스크린리더에서는 뺀다.
class _StageAvatar extends StatelessWidget {
  const _StageAvatar({required this.user});

  final HomeStageUser user;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: _kAvatarSize,
        height: _kAvatarSize,
        child: user._hasName ? _initialOrPhoto() : _guest(),
      ),
    );
  }

  Widget _guest() {
    return const GlassSurface(
      preset: GlassPreset.onBlue,
      child: Center(
        child: Icon(Icons.person_rounded, size: 22, color: Colors.white),
      ),
    );
  }

  Widget _initialOrPhoto() {
    final initial = Center(
      child: Text(
        user.name.trim().characters.first,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7A3E12),
        ),
      ),
    );
    final url = user.imageUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD9A8), Color(0xFFF4A26A)],
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? initial
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initial,
              ),
      ),
    );
  }
}
