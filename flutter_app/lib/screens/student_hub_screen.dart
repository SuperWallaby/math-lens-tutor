import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import '../theme/app_design_system.dart';
import '../utils/problem_image_picker.dart';
import '../utils/network_thumbnail_cache.dart';
import '../widgets/app_card.dart';
import '../widgets/glass.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/skeleton_lines.dart';
import 'analysis_screen.dart';
import 'practice_screen.dart';
import 'signup_screen.dart';

class _HubData {
  const _HubData({required this.profile, required this.submissions});

  final LearningProfile profile;
  final List<SubmissionSummary> submissions;

  bool get hasHistory =>
      submissions.isNotEmpty || profile.stats.totalProblems > 0;
}

class StudentHubScreen extends StatefulWidget {
  const StudentHubScreen({
    super.key,
    required this.apiClient,
    required this.oauthService,
    this.demoProfile,
    this.demoSubmissions,
    this.demoIsGuest,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;
  final LearningProfile? demoProfile;
  final List<SubmissionSummary>? demoSubmissions;
  final bool? demoIsGuest;

  @override
  State<StudentHubScreen> createState() => StudentHubScreenState();
}

class StudentHubScreenState extends State<StudentHubScreen> {
  Future<_HubData>? _hubFuture;

  /// 다른 탭(업로드·훈련) 후 홈 복귀 — TTL 내면 캐시 재사용.
  void refreshFromTab({bool forceRefresh = false}) {
    if (!forceRefresh &&
        widget.apiClient.isStudentTabDataFresh &&
        _hubFuture != null) {
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
    if (forceRefresh) {
      widget.apiClient.invalidateLearningProfileCache();
    }
    setState(() {
      _hubFuture = _loadHub(forceRefresh: forceRefresh);
    });
  }

  Future<_HubData> _loadHub({bool forceRefresh = false}) async {
    if (widget.demoProfile != null) {
      return _HubData(
        profile: widget.demoProfile!,
        submissions: widget.demoSubmissions ?? const [],
      );
    }
    final results = await Future.wait([
      widget.apiClient.getLearningProfile(
        forceRefresh: forceRefresh,
        scope: LearningProfileScope.summary,
      ),
      widget.apiClient.getSubmissionSummaries(forceRefresh: forceRefresh),
    ]);
    return _HubData(
      profile: results[0] as LearningProfile,
      submissions: results[1] as List<SubmissionSummary>,
    );
  }

  void _refreshAfterLearning() => _reload(forceRefresh: true);

  Future<void> _captureAndAnalyze() async {
    final picked = await pickProblemImage(
      source: primaryProblemImageSource,
      context: context,
    );
    if (picked == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          apiClient: widget.apiClient,
          imageBytes: picked.bytes,
          uploadFilename: picked.filename,
        ),
      ),
    );
    _refreshAfterLearning();
  }

  Future<void> _openGalleryAndAnalyze() async {
    final picked = await pickProblemImage(
      source: ImageSource.gallery,
      context: context,
    );
    if (picked == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          apiClient: widget.apiClient,
          imageBytes: picked.bytes,
          uploadFilename: picked.filename,
        ),
      ),
    );
    _refreshAfterLearning();
  }

  Future<void> _openSignup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupScreen(
          apiClient: widget.apiClient,
          oauthService: widget.oauthService,
          signupOnly: true,
          onSignedIn: () {
            if (mounted) Navigator.of(context).pop();
            _refreshAfterLearning();
          },
          onContinueAsGuest: () {
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _openSubmission(SubmissionSummary item) async {
    try {
      final result = await widget.apiClient.getSubmissionDetail(item.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AnalysisScreen(apiClient: widget.apiClient, result: result),
        ),
      );
      _refreshAfterLearning();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openMission(TodayMission mission) async {
    final setId = mission.setId;
    if (setId == null || setId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('진행 중인 문제 세트가 없습니다.')));
      return;
    }

    try {
      final set = await widget.apiClient.getProblemSet(setId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PracticeScreen(apiClient: widget.apiClient, problemSet: set),
        ),
      );
      _refreshAfterLearning();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = widget.demoIsGuest ?? widget.apiClient.authSession.isGuest;

    return RefreshIndicator(
      onRefresh: () async => _reload(forceRefresh: true),
      child: FutureBuilder<_HubData>(
        future: _hubFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: TabletLayout.pagePadding(context),
              children: const [
                _HubLoadingSkeleton(),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: TabletLayout.pagePadding(context),
              children: [
                ProfileLoadingError(error: snapshot.error, onRetry: () => _reload(forceRefresh: true)),
              ],
            );
          }

          final data = snapshot.data!;
          if (!data.hasHistory) {
            return _FirstTimeHome(
              onCapture: _captureAndAnalyze,
              onPickGallery: _openGalleryAndAnalyze,
            );
          }

          return _ReturningHome(
            data: data,
            isGuest: isGuest,
            apiBaseUrl: widget.apiClient.baseUrl,
            onCapture: _captureAndAnalyze,
            onPickGallery: _openGalleryAndAnalyze,
            onSignup: _openSignup,
            onOpenSubmission: _openSubmission,
            onOpenMission: _openMission,
          );
        },
      ),
    );
  }
}

class _FirstTimeHome extends StatelessWidget {
  const _FirstTimeHome({required this.onCapture, required this.onPickGallery});

  final VoidCallback onCapture;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: TabletLayout.pagePadding(context),
      children: [
        const Text(
          '우열',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const TagChip('중1 맞춤'),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          '오늘 어떤문제를 풀어볼까요?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.22,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '풀이 사진을 올리면 오답 원인과 비슷한 문제를 바로 만들어요.',
          style: TextStyle(color: AppColors.textSub, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xl),
        _NewProblemCard(
          onCapture: onCapture,
          onPickGallery: onPickGallery,
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _ReturningHome extends StatelessWidget {
  const _ReturningHome({
    required this.data,
    required this.isGuest,
    required this.apiBaseUrl,
    required this.onCapture,
    required this.onPickGallery,
    required this.onSignup,
    required this.onOpenSubmission,
    required this.onOpenMission,
  });

  final _HubData data;
  final bool isGuest;
  final String apiBaseUrl;
  final VoidCallback onCapture;
  final VoidCallback onPickGallery;
  final VoidCallback onSignup;
  final ValueChanged<SubmissionSummary> onOpenSubmission;
  final ValueChanged<TodayMission> onOpenMission;

  @override
  Widget build(BuildContext context) {
    final recent = data.submissions.take(5).toList();
    final mission = data.profile.mission;

    final missionTitle = mission?.title.trim();
    final hasMission = missionTitle != null && missionTitle.isNotEmpty;
    final grade = data.profile.grade.trim().isNotEmpty
        ? data.profile.grade.trim()
        : '중1';
    final accuracy = data.profile.stats.accuracy;
    final totalProblems = data.profile.stats.totalProblems;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: TabletLayout.pagePadding(context),
      children: [
        const Text(
          '우열',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TagChip('$grade 맞춤'),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          '오늘 어떤문제를 풀어볼까요?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.22,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          hasMission
              ? missionTitle
              : '풀이 사진을 올리면 오답 원인과 비슷한 문제를 바로 만들어요.',
          style: const TextStyle(color: AppColors.textSub, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            _StatPill(
              label: '정답률',
              value: accuracy > 0 ? '$accuracy%' : '시작 전',
              caption: '최근 7일',
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatPill(
              label: '해결한 문제',
              value: '$totalProblems개',
              caption: '최근 7일',
            ),
          ],
        ),
        if (hasMission && mission != null) ...[
          const SizedBox(height: AppSpacing.lg),
          GlassButton(
            onPressed: () => onOpenMission(mission),
            icon: Icons.play_arrow_rounded,
            label: mission.remainingCount > 0
                ? '이어서 ${mission.remainingCount}문제 풀기'
                : '이어서 훈련하기',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _NewProblemCard(
          onCapture: onCapture,
          onPickGallery: onPickGallery,
        ),
        if (isGuest) ...[
          const SizedBox(height: AppSpacing.lg),
          _GuestSaveBanner(onSignup: onSignup),
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          _SectionHeader(title: '최근 분석', caption: '${recent.length}개 기록'),
          const SizedBox(height: AppSpacing.md),
          for (final item in recent) ...[
            _RecentSubmissionTile(
              item: item,
              apiBaseUrl: apiBaseUrl,
              onTap: () => onOpenSubmission(item),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _NewProblemCard extends StatelessWidget {
  const _NewProblemCard({
    required this.onCapture,
    required this.onPickGallery,
  });

  final VoidCallback onCapture;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '새 문제',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '새 문제를 올리면 AI가 오답 원인을 분석하고 비슷한 문제로 훈련해요.',
            style: TextStyle(color: AppColors.textSub, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (supportsProblemImageCamera) ...[
            GlassButton(
              onPressed: onCapture,
              icon: Icons.camera_alt_rounded,
              label: '촬영하기',
            ),
            const SizedBox(height: AppSpacing.sm),
            GlassButton(
              onPressed: onPickGallery,
              icon: problemImageGalleryIcon,
              label: '앨범에서 고르기',
              primary: false,
            ),
          ] else
            GlassButton(
              onPressed: onPickGallery,
              icon: problemImageGalleryIcon,
              label: '새 문제 등록',
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestSaveBanner extends StatelessWidget {
  const _GuestSaveBanner({required this.onSignup});

  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              '로그인하면 분석 기록과 훈련 데이터를 이어갈 수 있어요.',
              style: TextStyle(
                color: AppColors.textSub,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onSignup,
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('로그인'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ),
        Text(
          caption,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RecentSubmissionTile extends StatelessWidget {
  const _RecentSubmissionTile({
    required this.item,
    required this.apiBaseUrl,
    required this.onTap,
  });

  final SubmissionSummary item;
  final String apiBaseUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = ApiClient.resolveListThumbnailUrl(
      apiBaseUrl,
      imageThumbUrl: item.imageThumbUrl,
      imageUrl: item.imageUrl,
    );
    final weakConcepts = item.weakConcepts
        .map((concept) => concept.trim())
        .where((concept) => concept.isNotEmpty)
        .toList();
    final primaryConcept = weakConcepts.isNotEmpty ? weakConcepts.first : null;

    return GlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _SubmissionThumbnail(imageUrl: imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    if (item.createdAt.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _formatSubmissionDate(item.createdAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (primaryConcept != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _MiniStatusChip(primaryConcept),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionThumbnail extends StatelessWidget {
  const _SubmissionThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? Container(
                color: AppColors.primary.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  color: AppColors.primary.withValues(alpha: 0.55),
                  size: 24,
                ),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                cacheWidth: networkImageCacheExtent(size, context),
                cacheHeight: networkImageCacheExtent(size, context),
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.primary.withValues(alpha: 0.55),
                    size: 24,
                  ),
                ),
              ),
      ),
    );
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Color.lerp(AppColors.accent, AppColors.text, 0.25),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HubLoadingSkeleton extends StatelessWidget {
  const _HubLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 72, height: 26, borderRadius: AppRadii.pill),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonLines(
                      widthFactors: [0.92, 0.64],
                      lineHeight: 18,
                      gap: 10,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonLines(
                      widthFactors: [0.98, 0.82],
                      lineHeight: 12,
                      gap: 8,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: SkeletonBox(height: 36, borderRadius: AppRadii.pill),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SkeletonBox(height: 36, borderRadius: AppRadii.pill),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.md),
                    SkeletonBox(height: AppSizes.buttonHeight, borderRadius: AppRadii.md),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const SkeletonBox(width: 58, height: 58, borderRadius: AppRadii.md),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        const SkeletonBox(width: 120, height: 14, borderRadius: 6),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < 2; i++) ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: const [
                SkeletonBox(width: 56, height: 56, borderRadius: AppRadii.sm),
                SizedBox(width: 12),
                Expanded(
                  child: SkeletonLines(
                    widthFactors: [0.88, 0.55],
                    lineHeight: 12,
                    gap: 8,
                  ),
                ),
              ],
            ),
          ),
          if (i == 0) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

String _formatSubmissionDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  return '${local.month}월 ${local.day}일';
}
