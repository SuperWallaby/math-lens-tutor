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
import '../widgets/home_stage.dart';
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
    this.demoUser,
    this.demoToday,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;
  final LearningProfile? demoProfile;
  final List<SubmissionSummary>? demoSubmissions;
  final bool? demoIsGuest;

  /// 디자인 리뷰·테스트용. 없으면 로그인한 사용자를 쓴다.
  final AppUser? demoUser;

  /// 디자인 리뷰·테스트용. 없으면 오늘 날짜를 쓴다.
  final DateTime? demoToday;

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
    final user = widget.demoUser ?? widget.apiClient.authSession.user;
    final today = widget.demoToday ?? DateTime.now();

    return RefreshIndicator(
      onRefresh: () async => _reload(forceRefresh: true),
      child: FutureBuilder<_HubData>(
        future: _hubFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: TabletLayout.pagePadding(context),
              children: const [_HubLoadingSkeleton()],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: TabletLayout.pagePadding(context),
              children: [
                ProfileLoadingError(
                  error: snapshot.error,
                  onRetry: () => _reload(forceRefresh: true),
                ),
              ],
            );
          }

          final data = snapshot.data!;
          final stageUser = HomeStageUser.from(
            user,
            data.profile,
            isGuest: isGuest,
          );
          if (!data.hasHistory) {
            return _FirstTimeHome(
              stageUser: stageUser,
              today: today,
              onPickGallery: _openGalleryAndAnalyze,
              onSignup: _openSignup,
            );
          }

          return _ReturningHome(
            data: data,
            stageUser: stageUser,
            today: today,
            apiBaseUrl: widget.apiClient.baseUrl,
            onSignup: _openSignup,
            onOpenSubmission: _openSubmission,
            onOpenMission: _openMission,
          );
        },
      ),
    );
  }
}

/// 무대 밑 본문의 좌우 여백. `HomeStage` 안쪽 좌우 여백과 같아서 카드 가장자리가 맞는다.
const double _kSidePad = 20;

/// 무대 위 보조 글자 — 흰색 80%.
const Color _kStageTextSub = Color(0xCCFFFFFF);

/// 예시 풀이에서 막힌 곳을 표시하는 빨간색.
const Color _kMarkRed = Color(0xFFE5484D);

/// 이만큼 내려가면 「스크롤했다」로 본다. 말풍선이 카드를 가릴 때는 아래 여백 덕에
/// 언제나 이보다 더 내려갈 수 있다(`_FirstTimeHome` 참고).
const double _kScrolledThreshold = 8;

/// 홈 목록을 감싸 스크롤 여부를 지켜본다. 스크롤하면 맨 위에 상태 표시줄 높이만큼
/// 흐림 띠를 깔아 무대 글자가 시계와 겹치지 않게 하고, [overlay]에도 스크롤 여부를 넘긴다.
class _HomeScrollFrame extends StatefulWidget {
  const _HomeScrollFrame({required this.list, this.overlay});

  final Widget list;
  final Widget Function(bool scrolled)? overlay;

  @override
  State<_HomeScrollFrame> createState() => _HomeScrollFrameState();
}

class _HomeScrollFrameState extends State<_HomeScrollFrame> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final scrolled = notification.metrics.pixels > _kScrolledThreshold;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.list,
        ),
        if (widget.overlay != null) widget.overlay!(_scrolled),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GlassStatusBarBand(visible: _scrolled),
        ),
      ],
    );
  }
}

class _FirstTimeHome extends StatelessWidget {
  const _FirstTimeHome({
    required this.stageUser,
    required this.today,
    required this.onPickGallery,
    required this.onSignup,
  });

  final HomeStageUser stageUser;
  final DateTime today;
  final VoidCallback onPickGallery;
  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    // `Scaffold(extendBody: true)` 아래에서는 떠 있는 탭바(솟은 카메라 포함) 높이가 들어 있다.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return _HomeScrollFrame(
      list: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // 말풍선(약 46px)이 뜬 자리까지 비운다. 말풍선이 카드를 조금이라도 가리면
        // 이 여백 때문에 20px 넘게 스크롤할 수 있어서, 스크롤로 말풍선을 치울 수 있다.
        padding: EdgeInsets.only(bottom: bottomInset + 72),
        children: [
          HomeStage(
            mode: HomeStageMode.firstVisit,
            user: stageUser,
            today: today,
            card: _FirstVisitStageCard(onPickGallery: onPickGallery),
            footer: stageUser.isGuest
                ? _GuestSignupRow(onSignup: onSignup)
                : null,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              _kSidePad,
              AppSpacing.xxl,
              _kSidePad,
              0,
            ),
            child: _ExampleCard(),
          ),
        ],
      ),
      // 가운데 카메라 바로 위. 카메라 탭을 막지 않도록 터치는 통과시킨다.
      // 작은 화면에서는 예시 카드(「= 20」)를 가리므로 스크롤하면 사라지고, 맨 위로
      // 돌아오면 다시 보인다.
      overlay: (scrolled) => Positioned(
        left: 0,
        right: 0,
        bottom: bottomInset + 8,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: scrolled ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: const Center(
              heightFactor: 1,
              child: GlassCoachBubble(text: '여기를 눌러 숙제 한 장 찍어요'),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReturningHome extends StatelessWidget {
  const _ReturningHome({
    required this.data,
    required this.stageUser,
    required this.today,
    required this.apiBaseUrl,
    required this.onSignup,
    required this.onOpenSubmission,
    required this.onOpenMission,
  });

  final _HubData data;
  final HomeStageUser stageUser;
  final DateTime today;
  final String apiBaseUrl;
  final VoidCallback onSignup;
  final ValueChanged<SubmissionSummary> onOpenSubmission;
  final ValueChanged<TodayMission> onOpenMission;

  @override
  Widget build(BuildContext context) {
    final recent = data.submissions.take(5).toList();
    final mission = data.profile.mission;
    final accuracy = data.profile.stats.accuracy;
    final totalProblems = data.profile.stats.totalProblems;

    return _HomeScrollFrame(
      list: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // 위쪽 안전 영역은 무대가 직접 채운다. 아래는 떠 있는 탭바 위로 스크롤되게 비운다.
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
        ),
        children: [
          HomeStage(
            mode: HomeStageMode.returning,
            user: stageUser,
            today: today,
            card: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mission != null && mission.title.trim().isNotEmpty) ...[
                  _MissionCard(
                    mission: mission,
                    onContinue: () => onOpenMission(mission),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: '정답률',
                        value: accuracy > 0 ? '$accuracy%' : '시작 전',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatTile(
                        label: '해결한 문제',
                        value: '$totalProblems개',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            footer: stageUser.isGuest
                ? _GuestSignupRow(onSignup: onSignup)
                : null,
          ),
          if (recent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kSidePad,
                AppSpacing.section,
                _kSidePad,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionHeader(title: '최근', caption: '${recent.length}장'),
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
              ),
            ),
        ],
      ),
    );
  }
}

/// 처음 화면 무대 카드: 3단계 안내 + 아래 「앨범에서 사진 고르기」 링크.
class _FirstVisitStageCard extends StatelessWidget {
  const _FirstVisitStageCard({required this.onPickGallery});

  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          preset: GlassPreset.onBlue,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          padding: const EdgeInsets.all(18),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StageStep(
                number: 1,
                title: '숙제 한 장 찍기',
                caption: '풀다가 막힌 문제 그대로',
              ),
              SizedBox(height: 14),
              _StageStep(number: 2, title: '막힌 곳 짚기', caption: '어디서 틀렸는지 한 줄로'),
              SizedBox(height: 14),
              _StageStep(number: 3, title: '이어서 풀기', caption: '비슷한 문제로 다시 확인'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: onPickGallery,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          // 글꼴(SUIT)은 버튼 기본 글자 스타일에서 이어받고, 모양만 여기서 덮는다.
          child: const Text(
            '앨범에서 사진 고르기',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _StageStep extends StatelessWidget {
  const _StageStep({
    required this.number,
    required this.title,
    required this.caption,
  });

  final int number;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(
                    color: _kStageTextSub,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 무대 밑 「이렇게 짚어줘요 · 예시」: 분과 시간 단위를 섞은 풀이에 빨간 원을 친 예시.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard();

  static const _formulaStyle = TextStyle(
    fontFamily: AppFonts.family,
    color: AppColors.text,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                '이렇게 짚어줘요',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                ' · 예시',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    const Text('x/4 − x/12', style: _formulaStyle),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: _kMarkRed, width: 2.5),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text('= 20', style: _formulaStyle),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _kMarkRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '여기서 막혔어요',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '분과 시간 단위를 섞었어요. 20분은 1/3시간이에요.',
                      style: TextStyle(
                        color: AppColors.textSub,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 다시 온 화면 무대 카드: 단원 · 남은 문제 수, 제목, 흰 「이어서 풀기」.
class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.onContinue});

  final TodayMission mission;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final concept = mission.conceptTags
        .map((tag) => tag.trim())
        .firstWhere((tag) => tag.isNotEmpty, orElse: () => '');
    final eyebrow = [
      concept,
      if (mission.remainingCount > 0) '${mission.remainingCount}문제 남음',
    ].where((part) => part.isNotEmpty).join(' · ');

    return GlassSurface(
      preset: GlassPreset.onBlue,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eyebrow.isNotEmpty) ...[
            Text(
              eyebrow,
              style: const TextStyle(
                color: _kStageTextSub,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
          ],
          Text(
            mission.title.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          FilledButton(
            onPressed: onContinue,
            style: AppButtonStyles.white(),
            child: const Text('이어서 풀기'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      preset: GlassPreset.onBlue,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _kStageTextSub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

/// 게스트일 때 무대 카드 아래에 붙는 가입 안내 줄.
class _GuestSignupRow extends StatelessWidget {
  const _GuestSignupRow({required this.onSignup});

  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      preset: GlassPreset.onBlue,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '둘러보는 중이에요. 가입하면 기록이 남아요.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onSignup,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0x33FFFFFF),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              '가입하기',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
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

    // 카드 전체가 눌리도록 AppCard 패딩을 없애고 InkWell 안에 패딩을 둔다.
    return AppCard(
      padding: EdgeInsets.zero,
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
