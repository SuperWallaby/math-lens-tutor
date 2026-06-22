import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/learning_profile_widgets.dart';
import 'open_practice_flow.dart';
import '../theme/app_design_system.dart';

class StudentTrainingScreen extends StatefulWidget {
  const StudentTrainingScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<StudentTrainingScreen> createState() => _StudentTrainingScreenState();
}

class _TrainingScreenData {
  const _TrainingScreenData({
    required this.profile,
    required this.feed,
  });

  final LearningProfile profile;
  final TrainingFeedResponse feed;
}

class _StudentTrainingScreenState extends State<StudentTrainingScreen> {
  Future<_TrainingScreenData>? _screenFuture;

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
    final results = await Future.wait([
      widget.apiClient.getLearningProfile(forceRefresh: forceRefresh),
      widget.apiClient.getTrainingFeed(),
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
      iconAsset: 'assets/icons/3d/training_active.png',
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
      iconAsset: 'assets/icons/3d/training_active.png',
    );
    if (!mounted) return;
    _reload(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TrainingScreenData>(
      future: _screenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ProfileLoadingView(message: '훈련 정보 불러오는 중…');
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (!showContent) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: TabletLayout.pagePadding(context),
                      child: _TrainingEmptyState(
                        hasLearningData: training.hasLearningData,
                      ),
                    ),
                  ),
                );
              }

              return ListView(
                padding: TabletLayout.pagePadding(context),
                children: [
                  Text(
                    '복습 훈련',
                    style: TextStyle(
                      fontSize: TabletLayout.titleSection(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasFeed
                        ? '맞춤 문제 피드 — 풀수록 더 잘 맞춰져요'
                        : '틀렸던 문제·개념 위주로 계속 연습합니다',
                    style: const TextStyle(
                      color: AppColors.textSub,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
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
                    _TrainingHeroCard(training: training),
                    const SizedBox(height: 16),
                    if (training.activeSetId != null && training.remainingCount > 0)
                      _ContinueTrainingCard(
                        remainingCount: training.remainingCount,
                        onTap: () => _startTraining(training),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => _startTraining(training),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('5문제 세트로 복습'),
                      ),
                    const SizedBox(height: 24),
                  ],
                  if (hasFeed) ...[
                    const SectionLabel('맞춤 피드'),
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
            },
          ),
        );
      },
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FeedTag(text: item.concept, color: AppColors.primary),
                    _FeedTag(text: item.difficultyLabel, color: AppColors.accent),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title.isNotEmpty ? item.title : item.concept,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                if (item.promptPreview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.promptPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSub,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.reason,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrainingEmptyState extends StatelessWidget {
  const _TrainingEmptyState({required this.hasLearningData});

  final bool hasLearningData;

  @override
  Widget build(BuildContext context) {
    final accent = hasLearningData ? AppColors.success : AppColors.primary;
    final icon = hasLearningData
        ? Icons.task_alt_rounded
        : Icons.replay_circle_filled_outlined;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: accent),
            ),
            const SizedBox(height: 28),
            Text(
              '아직 훈련할 항목이 없습니다',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: TabletLayout.isTablet(context) ? 22 : 20,
                height: 1.35,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              hasLearningData
                  ? '최근 틀린 기록이 없거나 모두 재학습에 성공했어요.\n새로 틀린 문제가 쌓이면 맞춤 추천이 올라와요.'
                  : '풀이 사진 분석이나 단원 연습을 시작하면\n틀린 개념이 쌓이고, 맞춤 복습 문제를 제공해요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSub,
                height: 1.6,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasLearningData ? '잘하고 있어요' : '홈에서 첫 문제를 풀어보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingHeroCard extends StatelessWidget {
  const _TrainingHeroCard({required this.training});

  final TrainingSnapshot training;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      training.headline.isNotEmpty
                          ? training.headline
                          : '틀렸던 개념을 다시 연습해요',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      training.description.isNotEmpty
                          ? training.description
                          : '분석·연습에서 틀린 부분을 모아 비슷한 문제로 반복 훈련합니다.',
                      style: const TextStyle(
                        color: AppColors.textSub,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
