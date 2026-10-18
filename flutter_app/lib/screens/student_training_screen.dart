import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dev/design_review_data.dart';
import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/glass.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/mixed_math_text.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/skeleton_lines.dart';
import 'open_practice_flow.dart';
import '../theme/app_design_system.dart';

const _scrollEdgeThreshold = 30.0;

class _TrainingScreenData {
  const _TrainingScreenData({
    required this.profile,
    required this.feed,
  });

  final LearningProfile profile;
  final TrainingFeedResponse feed;
}

class StudentTrainingScreen extends StatefulWidget {
  const StudentTrainingScreen({
    super.key,
    required this.apiClient,
    this.demoProfile,
    this.demoFeed,
  });

  final ApiClient apiClient;
  final LearningProfile? demoProfile;
  final TrainingFeedResponse? demoFeed;

  @override
  StudentTrainingScreenState createState() => StudentTrainingScreenState();
}

class StudentTrainingScreenState extends State<StudentTrainingScreen> {
  Future<_TrainingScreenData>? _screenFuture;

  /// 본문이 [_scrollEdgeThreshold]보다 아래로 스크롤되면 위쪽 흐림을 보인다.
  bool _scrolled = false;

  /// 하단 탭 전환 시 — TTL 내면 캐시 재사용.
  void refreshFromTab({bool forceRefresh = false}) {
    if (!forceRefresh &&
        widget.apiClient.isTrainingTabDataFresh &&
        _screenFuture != null) {
      return;
    }
    _reload(forceRefresh: forceRefresh);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool forceRefresh = false}) {
    setState(() {
      // 다시 불러오는 동안 스크롤 위치가 사라지므로 흐림도 함께 끈다.
      _scrolled = false;
      _screenFuture = _loadScreen(forceRefresh: forceRefresh);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final scrolled = notification.metrics.pixels > _scrollEdgeThreshold;
    if (scrolled != _scrolled && mounted) {
      setState(() => _scrolled = scrolled);
    }
    return false;
  }

  Future<_TrainingScreenData> _loadScreen({bool forceRefresh = false}) async {
    if (widget.demoProfile != null) {
      return _TrainingScreenData(
        profile: widget.demoProfile!,
        feed: widget.demoFeed ?? designReviewTrainingFeed(),
      );
    }
    final results = await Future.wait([
      widget.apiClient.getLearningProfile(
        forceRefresh: forceRefresh,
        scope: LearningProfileScope.summary,
      ),
      widget.apiClient.getTrainingFeed(forceRefresh: forceRefresh),
    ]);
    return _TrainingScreenData(
      profile: results[0] as LearningProfile,
      feed: results[1] as TrainingFeedResponse,
    );
  }

  Future<void> _startTraining(TrainingSnapshot training) async {
    await openPracticeWithSingleRequest(
      context,
      apiClient: widget.apiClient,
      start: () => widget.apiClient.startTrainingPractice(
        resumeSetId: training.activeSetId,
      ),
      subtitle: training.focusConcepts.isNotEmpty
          ? training.focusConcepts.take(2).join(' · ')
          : '복습 훈련',
      generatingTitle: 'AI 복습 문제 만드는 중…',
      iconAsset: 'assets/icons/3d/training_active.webp',
    );
    if (!mounted) return;
    _reload(forceRefresh: true);
  }

  Future<void> _startFeedItem(TrainingFeedItem item) async {
    await openPracticeWithSingleRequest(
      context,
      apiClient: widget.apiClient,
      start: () => widget.apiClient.startFeedPractice(
        feedItemId: item.id,
        bankItemId: item.bankItemId,
      ),
      subtitle: item.reason,
      generatingTitle: '문제 불러오는 중…',
      iconAsset: 'assets/icons/3d/training_active.webp',
    );
    if (!mounted) return;
    _reload(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: _buildBody(context),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GlassScrollEdge(visible: _scrolled, title: '훈련'),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<_TrainingScreenData>(
      future: _screenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _TrainingTabSkeleton();
        }
        if (snapshot.hasError) {
          return ProfileLoadingError(
            error: snapshot.error,
            onRetry: () => _reload(forceRefresh: true),
          );
        }

        final profile = snapshot.data!.profile;
        final feed = snapshot.data!.feed;
        final training = profile.training;
        final hasFeed = feed.items.isNotEmpty;
        final showContent = training.available || hasFeed;

        return RefreshIndicator(
          onRefresh: () async => _reload(forceRefresh: true),
          child: showContent
              ? _buildFeed(context, profile, feed)
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: TabletLayout.pagePadding(context),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
                        child: _TrainingEmptyState(
                          hasLearningData: training.hasLearningData,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildFeed(
    BuildContext context,
    LearningProfile profile,
    TrainingFeedResponse feed,
  ) {
    final training = profile.training;
    final hasFeed = feed.items.isNotEmpty;
    return ListView(
      padding: TabletLayout.pagePadding(context),
      children: [
        const _TrainingHeader(),
        if (feed.refreshPending) ...[
          const SizedBox(height: 10),
          _FeedStatusChip(
            label: feed.isPrecomputed
                ? '추천 목록 업데이트 중'
                : '기본 추천 표시 · 분석 후 더 맞춤',
          ),
        ],
        const SizedBox(height: 20),
        if (training.available) ...[
          _TrainingHeroCard(
            training: training,
            displayName: widget.apiClient.authSession.user?.displayName,
          ),
          const SizedBox(height: 16),
          if (training.activeSetId != null && training.remainingCount > 0)
            _ContinueTrainingCard(
              remainingCount: training.remainingCount,
              onTap: () => _startTraining(training),
            )
          else
            FilledButton.icon(
              style: AppButtonStyles.soft(),
              onPressed: () => _startTraining(training),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('5문제 세트로 복습'),
            ),
          const SizedBox(height: 24),
        ],
        if (hasFeed) ...[
          const SectionLabel('맞춤 문제'),
          const SizedBox(height: 10),
          ...feed.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TrainingFeedCard(
                item: item,
                onTap: () => _startFeedItem(item),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (training.focusItems.isNotEmpty) ...[
          const SectionLabel('훈련 대상'),
          _TrainingFocusList(items: training.focusItems),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FeedStatusChip extends StatelessWidget {
  const _FeedStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TrainingFeedCard extends StatelessWidget {
  const _TrainingFeedCard({
    required this.item,
    required this.onTap,
  });

  final TrainingFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryLine = _feedCardPrimaryLine(item);
    final reasonLine = _feedCardReasonLine(item);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FeedTag(text: item.concept, color: AppColors.primary),
                      _FeedTag(
                        text: item.difficultyLabel,
                        color: AppColors.accent,
                      ),
                      _FeedTag(
                        text: '${item.problemCount}문제',
                        color: AppColors.textSub,
                      ),
                    ],
                  ),
                  if (primaryLine != null) ...[
                    const SizedBox(height: 10),
                    MixedMathText(
                      primaryLine,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (reasonLine != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      reasonLine,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _feedCardPrimaryLine(TrainingFeedItem item) {
  final title = item.title.trim();
  if (title.isNotEmpty) return title;
  return null;
}

String? _feedCardReasonLine(TrainingFeedItem item) {
  var reason = item.reason.trim();
  if (reason.isEmpty) return null;

  final concept = item.concept.trim();
  final diffLabel = item.difficultyLabel;
  final parts = reason
      .split('·')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isNotEmpty && parts.first == concept) {
    if (parts.length >= 2 &&
        (parts[1] == diffLabel || parts[1] == item.difficulty)) {
      reason = parts.length > 2 ? parts.sublist(2).join(' · ') : '';
    } else if (parts.length == 1) {
      reason = '';
    }
  }

  reason = reason.trim();
  if (reason.isEmpty || reason == '맞춤 추천' || reason == concept) {
    return null;
  }
  return reason;
}

class _FeedTag extends StatelessWidget {
  const _FeedTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tagChipTextColor(color),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 훈련 탭 맨 위 제목 「훈련」과 설명. 목록·빈 상태·로딩이 모두 같은 글자를 쓰고,
/// 스크롤하면 [GlassScrollEdge]가 같은 제목을 이어 받는다.
class _TrainingHeader extends StatelessWidget {
  const _TrainingHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '훈련',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '막힌 개념만 모아서 다시 풀어보는 곳이에요.',
          style: TextStyle(color: AppColors.textSub, height: 1.45, fontSize: 14),
        ),
      ],
    );
  }
}

/// 첫 로그인 직후(기록 없음)와 막힌 문제를 다 푼 뒤에 보이는 훈련 탭.
///
/// [hasLearningData]가 true면 빈 카드 문구만 바뀌고, 예시 줄과 카메라 안내는 숨긴다.
class _TrainingEmptyState extends StatelessWidget {
  const _TrainingEmptyState({required this.hasLearningData});

  final bool hasLearningData;

  static const _examples = [
    '단위 바꾸기 (분 → 시간) · 일차방정식의 활용 · 3문제',
    '분배법칙 부호 · 문자와 식 · 2문제',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TrainingHeader(),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  hasLearningData ? '막힌 문제를 다 풀었어요.' : '아직 훈련할 문제가 없어요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasLearningData
                      ? '새로 막히면 여기에 모여요.'
                      : '숙제를 찍으면 막힌 개념이 여기에 모여요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSub,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!hasLearningData) ...[
          const SizedBox(height: 24),
          const _ExampleHeader(),
          const SizedBox(height: 10),
          for (final example in _examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ExampleRow(text: example),
            ),
        ],
        const Spacer(),
        if (!hasLearningData) ...[
          const SizedBox(height: 20),
          const _CameraHint(),
        ],
      ],
    );
  }
}

class _ExampleHeader extends StatelessWidget {
  const _ExampleHeader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '이런 식으로 쌓여요 · 예시',
      child: ExcludeSemantics(
        child: Row(
          children: const [
            Text(
              '이런 식으로 쌓여요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSub,
              ),
            ),
            Text(
              ' · 예시',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 실제 항목이 아니라 보여주기용이라 55% 투명도에 점선 테두리로 흐리게 둔다.
class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: CustomPaint(
        painter: const _DashedRRectPainter(
          color: AppColors.textMuted,
          radius: AppRadii.md,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppColors.textSub,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _strokeWidth = 1.5;
  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    for (final metric in path.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += _dash + _gap) {
        final end = math.min(start + _dash, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _CameraHint extends StatelessWidget {
  const _CameraHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '가운데 카메라로 시작해요',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _TrainingHeroCard extends StatelessWidget {
  const _TrainingHeroCard({
    required this.training,
    this.displayName,
  });

  final TrainingSnapshot training;
  final String? displayName;

  String _heroMessage() {
    final fromApi = training.headline.trim();
    if (fromApi.isNotEmpty) return fromApi;

    final name = displayName?.trim();
    if (name != null && name.isNotEmpty && name != '게스트') {
      return '$name님을 위한 맞춤 문제가 준비되었습니다.';
    }
    return '맞춤 문제가 준비되었습니다.';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(
                  Icons.replay_circle_filled_outlined,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _heroMessage(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (training.focusConcepts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              training.focusConcepts.take(3).join(' · '),
              style: const TextStyle(
                color: AppColors.textSub,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          if (training.totalMisses > 0 || training.relearnedCount > 0) ...[
            const SizedBox(height: 14),
            Text(
              [
                if (training.totalMisses > 0) '누적 오답 ${training.totalMisses}건',
                if (training.relearnedCount > 0)
                  '재학습 성공 ${training.relearnedCount}건',
              ].join(' · '),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContinueTrainingCard extends StatelessWidget {
  const _ContinueTrainingCard({
    required this.remainingCount,
    required this.onTap,
  });

  final int remainingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이어서 복습하기',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '틀렸던 개념 문제 · $remainingCount개 남음',
                      style: const TextStyle(
                        color: AppColors.textSub,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingFocusList extends StatelessWidget {
  const _TrainingFocusList({required this.items});

  final List<TrainingFocusItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppCard(
        child: Text(
          '훈련 대상 개념을 정리하는 중입니다.',
          style: TextStyle(color: AppColors.textSub, height: 1.5),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: AppColors.border),
            _TrainingFocusRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _TrainingFocusRow extends StatelessWidget {
  const _TrainingFocusRow({required this.item});

  final TrainingFocusItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.isRelearned ? AppColors.success : AppColors.accent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          item.isRelearned
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.concept,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.isRelearned
                    ? item.label
                    : '오답 ${item.missScore}회 · ${item.label}',
                style: TextStyle(
                  color: item.isRelearned ? AppColors.success : AppColors.textSub,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 훈련 탭 본문과 같은 구조의 로딩 플레이스홀더.
class _TrainingTabSkeleton extends StatelessWidget {
  const _TrainingTabSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: TabletLayout.pagePadding(context),
      children: [
        // 제목과 설명은 불러온 뒤와 같은 글자라 자리표시 대신 그대로 보인다.
        const _TrainingHeader(),
        const SizedBox(height: 20),
        const _TrainingHeroCardSkeleton(),
        const SizedBox(height: 16),
        const SkeletonBox(height: AppSizes.buttonHeight, borderRadius: AppRadii.md),
        const SizedBox(height: 24),
        const SectionLabel('맞춤 문제'),
        const SizedBox(height: 10),
        for (var i = 0; i < 3; i++) ...[
          const _TrainingFeedCardSkeleton(),
          if (i < 2) const SizedBox(height: 12),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TrainingHeroCardSkeleton extends StatelessWidget {
  const _TrainingHeroCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(
            width: 44,
            height: 44,
            borderRadius: AppRadii.md,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLines(
                  widthFactors: [0.94, 0.72],
                  lineHeight: 14,
                  gap: 8,
                ),
                SizedBox(height: 10),
                SkeletonBox(width: 168, height: 12, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingFeedCardSkeleton extends StatelessWidget {
  const _TrainingFeedCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    SkeletonBox(width: 72, height: 26, borderRadius: AppRadii.pill),
                    SizedBox(width: 8),
                    SkeletonBox(width: 56, height: 26, borderRadius: AppRadii.pill),
                  ],
                ),
                SizedBox(height: 10),
                SkeletonLines(
                  widthFactors: [0.92, 0.68],
                  lineHeight: 14,
                  gap: 6,
                ),
                SizedBox(height: 6),
                SkeletonBox(width: 96, height: 12, borderRadius: 6),
              ],
            ),
          ),
          SizedBox(width: 8),
          SkeletonBox(width: 28, height: 28, borderRadius: AppRadii.pill),
        ],
      ),
    );
  }
}
