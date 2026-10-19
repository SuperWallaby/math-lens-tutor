import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dev/design_review_data.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/mixed_math_text.dart';
import '../widgets/page_stage.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/skeleton_lines.dart';
import 'open_practice_flow.dart';
import '../theme/app_design_system.dart';
import '../theme/app_icons.dart';

const _title = '훈련';
const _subtitle = '막힌 개념만 모아서 다시 풀어봐요';

/// 피드에 준비된 문제 수(카드마다 `problemCount`를 더한다).
int feedProblemCount(TrainingFeedResponse feed) =>
    feed.items.fold(0, (sum, item) => sum + item.problemCount);

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
      _screenFuture = _loadScreen(forceRefresh: forceRefresh);
    });
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
    return StageFrame(child: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<_TrainingScreenData>(
      future: _screenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _TrainingTabSkeleton();
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: () async => _reload(forceRefresh: true),
            child: StageListView(
              stage: const PageStage.tab(title: _title, subtitle: _subtitle),
              children: [
                ProfileLoadingError(
                  error: snapshot.error,
                  onRetry: () => _reload(forceRefresh: true),
                ),
              ],
            ),
          );
        }

        final profile = snapshot.data!.profile;
        final feed = snapshot.data!.feed;
        final training = profile.training;
        final hasFeed = feed.items.isNotEmpty;
        final stage = PageStage.tab(
          title: _title,
          subtitle: _subtitle,
          children: [
            _TrainingStageCard(
              training: training,
              hasFeed: hasFeed,
              feedProblems: feedProblemCount(feed),
              displayName: widget.apiClient.authSession.user?.displayName,
              onStart: () => _startTraining(training),
            ),
            if (training.hasLearningData || hasFeed)
              StageTileRow(
                tiles: [
                  StageTile(label: '풀 문제', value: '${feedProblemCount(feed)}개'),
                  StageTile(
                    label: '다시 맞힘',
                    value: '${training.relearnedCount}건',
                  ),
                ],
              ),
          ],
        );

        final Widget list;
        if (training.available || hasFeed) {
          list = StageListView(
            stage: stage,
            children: _feedChildren(training, feed),
          );
        } else if (training.hasLearningData) {
          list = StageListView(stage: stage, children: const []);
        } else {
          list = CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: stage),
              SliverPadding(
                padding: stageBodyPadding(context),
                sliver: const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _TrainingFirstVisitBelow(),
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _reload(forceRefresh: true),
          child: list,
        );
      },
    );
  }

  /// 무대 아래 목록: 피드 상태 칩 · 「풀 문제」 · 「훈련 대상」.
  List<Widget> _feedChildren(
    TrainingSnapshot training,
    TrainingFeedResponse feed,
  ) {
    return [
      if (feed.refreshPending) ...[
        _FeedStatusChip(
          label: feed.isPrecomputed
              ? '추천 목록 업데이트 중'
              : '기본 추천 표시 · 분석 후 더 맞춤',
        ),
        const SizedBox(height: 16),
      ],
      if (feed.items.isNotEmpty) ...[
        const SectionLabel('풀 문제'),
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
    ];
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
                AppIcons.playCircleFill,
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

/// 훈련 무대 카드. 지금 상태에 맞는 한 가지를 고른다.
///
/// 복습 세트(이어서 하기 / 5문제 새로) → 피드만 → 기록은 있는데 다 풂 → 기록 없음.
class _TrainingStageCard extends StatelessWidget {
  const _TrainingStageCard({
    required this.training,
    required this.hasFeed,
    required this.feedProblems,
    required this.displayName,
    required this.onStart,
  });

  final TrainingSnapshot training;
  final bool hasFeed;
  final int feedProblems;
  final String? displayName;
  final VoidCallback onStart;

  String _heroMessage() {
    final fromApi = training.headline.trim();
    if (fromApi.isNotEmpty) return fromApi;

    final name = displayName?.trim();
    if (name != null && name.isNotEmpty && name != '게스트') {
      return '$name님, 막힌 개념으로 문제를 준비했어요.';
    }
    return '막힌 개념으로 문제를 준비했어요.';
  }

  @override
  Widget build(BuildContext context) {
    if (training.available) return _reviewSet();
    if (hasFeed) {
      return _message('풀 문제 $feedProblems개가 준비됐어요', null);
    }
    if (training.hasLearningData) {
      return _message('막힌 문제를 다 풀었어요.', '새로 막히면 여기에 모여요.');
    }
    return _message('아직 훈련할 문제가 없어요', '숙제를 찍으면 막힌 개념이 여기에 모여요.');
  }

  Widget _message(String title, String? body) {
    return StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: StageText.cardTitle),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body, style: StageText.body),
          ],
        ],
      ),
    );
  }

  Widget _reviewSet() {
    final continueSet =
        training.activeSetId != null && training.remainingCount > 0;
    final concepts = training.focusConcepts.take(3).join(' · ');
    return StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (concepts.isNotEmpty) ...[
            Text(
              concepts,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StageText.eyebrow,
            ),
            const SizedBox(height: 6),
          ],
          Text(_heroMessage(), style: StageText.cardTitle),
          if (training.totalMisses > 0) ...[
            const SizedBox(height: 8),
            Text('누적 오답 ${training.totalMisses}건', style: StageText.body),
          ],
          if (continueSet) ...[
            const SizedBox(height: 4),
            Text(
              '틀렸던 개념 문제 · ${training.remainingCount}개 남음',
              style: StageText.body,
            ),
          ],
          const SizedBox(height: 16),
          if (continueSet)
            FilledButton(
              style: AppButtonStyles.white(),
              onPressed: onStart,
              child: const Text('이어서 복습하기'),
            )
          else
            FilledButton.icon(
              style: AppButtonStyles.white(),
              onPressed: onStart,
              icon: const Icon(AppIcons.play),
              label: const Text('5문제 세트로 복습'),
            ),
        ],
      ),
    );
  }
}

/// 첫 로그인 직후(기록 없음) 무대 아래: 예시 두 줄과 가운데 카메라 안내.
class _TrainingFirstVisitBelow extends StatelessWidget {
  const _TrainingFirstVisitBelow();

  static const _examples = [
    '단위 바꾸기 (분 → 시간) · 일차방정식의 활용 · 3문제',
    '분배법칙 부호 · 문자와 식 · 2문제',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ExampleHeader(),
        const SizedBox(height: 10),
        for (final example in _examples)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExampleRow(text: example),
          ),
        const Spacer(),
        const SizedBox(height: 20),
        const _CameraHint(),
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
            AppIcons.chevronDown,
            size: 20,
            color: AppColors.primary,
          ),
        ],
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
          '훈련할 개념을 모으는 중이에요.',
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
              ? AppIcons.checkCircle
              : AppIcons.error,
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

/// 훈련 탭 본문과 같은 구조의 로딩 플레이스홀더. 무대(제목과 설명)는 그대로 보인다.
class _TrainingTabSkeleton extends StatelessWidget {
  const _TrainingTabSkeleton();

  @override
  Widget build(BuildContext context) {
    return StageListView(
      stage: const PageStage.tab(title: _title, subtitle: _subtitle),
      children: [
        const _TrainingHeroCardSkeleton(),
        const SizedBox(height: 16),
        const SkeletonBox(height: AppSizes.buttonHeight, borderRadius: AppRadii.md),
        const SizedBox(height: 24),
        const SectionLabel('풀 문제'),
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
