import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import '../theme/app_design_system.dart';
import 'signup_screen.dart';
import '../widgets/hero_icon_3d.dart';
import '../widgets/linked_children_panel.dart';
import '../widgets/student_link_guide.dart';

enum _OnboardingStep { role, grade, details, linkChildren, studentCode }

class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({
    super.key,
    required this.apiClient,
    required this.oauthService,
    required this.onComplete,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;
  final VoidCallback onComplete;

  @override
  State<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  _OnboardingStep _step = _OnboardingStep.role;
  int _gradeIndex = 6;
  AppUserRole? _role;
  AppUserRole? _highlightedRole;
  bool _roleAdvancePending = false;
  final _orgController = TextEditingController();
  bool _loading = false;
  bool _finishing = false;
  String? _error;
  String? _studentCode;
  int _slideDirection = 1;

  static const _grades = [
    '초1',
    '초2',
    '초3',
    '초4',
    '초5',
    '초6',
    '중1',
    '중2',
    '중3',
    '고1',
    '고2',
    '고3',
    '대학생 이상',
  ];

  String get _selectedGrade => _grades[_gradeIndex.clamp(0, _grades.length - 1)];

  int? get _ageFromGrade {
    const ages = {
      '초1': 8,
      '초2': 9,
      '초3': 10,
      '초4': 11,
      '초5': 12,
      '초6': 13,
      '중1': 14,
      '중2': 15,
      '중3': 16,
      '고1': 17,
      '고2': 18,
      '고3': 19,
      '대학생 이상': 22,
    };
    return ages[_selectedGrade];
  }

  @override
  void dispose() {
    _orgController.dispose();
    super.dispose();
  }

  void _goToStep(
    _OnboardingStep next, {
    required bool forward,
    void Function()? apply,
  }) {
    if (!mounted) return;
    setState(() {
      _slideDirection = forward ? 1 : -1;
      _step = next;
      apply?.call();
    });
  }

  void _goBack() {
    setState(() {
      _error = null;
      _slideDirection = -1;
      switch (_step) {
        case _OnboardingStep.role:
          break;
        case _OnboardingStep.grade:
          _step = _OnboardingStep.role;
        case _OnboardingStep.details:
          _step = _OnboardingStep.role;
        case _OnboardingStep.linkChildren:
          _step = _OnboardingStep.details;
        case _OnboardingStep.studentCode:
          _step = _OnboardingStep.grade;
      }
    });
  }

  Future<void> _selectRole(AppUserRole role) async {
    if (_loading || _roleAdvancePending) return;

    HapticFeedback.lightImpact();
    setState(() {
      _roleAdvancePending = true;
      _role = role;
      _highlightedRole = role;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    setState(() {
      _highlightedRole = null;
      _roleAdvancePending = false;
      _slideDirection = 1;
      if (role == AppUserRole.student) {
        _step = _OnboardingStep.grade;
      } else {
        _step = _OnboardingStep.details;
      }
    });
  }

  bool get _isGuest => widget.apiClient.authSession.isGuest;

  Future<void> _submitProfile() async {
    final role = _role;
    if (role == null || _loading || _finishing) return;

    if (role == AppUserRole.student && _selectedGrade.isEmpty) {
      setState(() => _error = '학년을 선택해 주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isGuest) {
        await widget.apiClient.authSession.completeGuestProfile(
          role: role,
          age: role == AppUserRole.student ? _ageFromGrade : null,
          grade: role == AppUserRole.student ? _selectedGrade : null,
          organizationName: role == AppUserRole.teacher
              ? _orgController.text.trim()
              : null,
        );
        if (!mounted) return;

        if (role == AppUserRole.student) {
          if (!mounted) return;
          setState(() => _loading = false);
          _finish();
        } else {
          _goToStep(
            _OnboardingStep.linkChildren,
            forward: true,
            apply: () => _loading = false,
          );
        }
        return;
      }

      final user = await widget.apiClient.completeProfile(
        role,
        age: role == AppUserRole.student ? _ageFromGrade : null,
        grade: role == AppUserRole.student ? _selectedGrade : null,
        organizationName: role == AppUserRole.teacher
            ? _orgController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (user.isStudent) {
        _goToStep(
          _OnboardingStep.studentCode,
          forward: true,
          apply: () {
            _studentCode = user.studentCode;
            _loading = false;
          },
        );
      } else {
        _goToStep(
          _OnboardingStep.linkChildren,
          forward: true,
          apply: () => _loading = false,
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _copyStudentCode() async {
    final code = _studentCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('학생 고유번호가 복사되었습니다.')),
    );
  }

  void _finish() {
    if (_finishing) return;
    final role = _role ?? widget.apiClient.authSession.user?.role;
    if (role == AppUserRole.parent || role == AppUserRole.teacher) {
      if (widget.apiClient.authSession.linkedStudents.isEmpty) return;
    }
    _finishing = true;
    widget.onComplete();
  }

  Future<void> _leaveGuestForSignup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupScreen(
          apiClient: widget.apiClient,
          oauthService: widget.oauthService,
          signupOnly: true,
          onSignedIn: () async {
            if (!context.mounted) return;
            Navigator.of(context).pop();
            if (!mounted || _role == null) return;
            await _submitProfile();
          },
        ),
      ),
    );
  }

  Widget _stepTransitionBuilder(Widget child, Animation<double> animation) {
    final slide = Tween<Offset>(
      begin: Offset(0.18 * _slideDirection, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: SlideTransition(position: slide, child: child),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    return switch (_step) {
      _OnboardingStep.grade => _buildGradeStep(context),
      _OnboardingStep.role => _buildRoleStep(context),
      _OnboardingStep.details => _buildDetailsStep(context),
      _OnboardingStep.linkChildren => const SizedBox.shrink(),
      _OnboardingStep.studentCode => _buildStudentCodeStep(context),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _step != _OnboardingStep.role;
    final stepTitle = _stepTitle;

    return Scaffold(
      appBar: AppBar(
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _loading ? null : _goBack,
              )
            : null,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: _stepTransitionBuilder,
          child: Text(
            stepTitle,
            key: ValueKey<String>(stepTitle),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(14),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              TabletLayout.pageHorizontalPadding(context),
              0,
              TabletLayout.pageHorizontalPadding(context),
              AppSpacing.sm,
            ),
            child: _StepIndicator(current: _step),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabletBody(
          child: _step == _OnboardingStep.linkChildren
              ? Padding(
                  padding: TabletLayout.appBarBodyPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _role == AppUserRole.parent
                                    ? '자녀를 연결해 주세요'
                                    : '학생을 연결해 주세요',
                                style: TextStyle(
                                  fontSize: TabletLayout.titleSection(context),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                '고유번호 6자리를 모두 입력하면 자동으로 연결됩니다.',
                                style: const TextStyle(
                                  color: AppColors.textSub,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              ListenableBuilder(
                                listenable: widget.apiClient.authSession,
                                builder: (context, _) {
                                  return LinkedChildrenPanel(
                                    apiClient: widget.apiClient,
                                    linkedStudents: widget
                                        .apiClient.authSession.linkedStudents,
                                    compact: true,
                                    onChanged: () => setState(() {}),
                                    onAutoLinked: _finish,
                                  );
                                },
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              StudentLinkGuide(role: _role),
                            ],
                          ),
                        ),
                      ),
                      if (_isGuest) ...[
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _leaveGuestForSignup,
                          style: AppButtonStyles.filledKeyAction(
                            backgroundColor: _role == AppUserRole.teacher
                                ? AppColors.teacher
                                : AppColors.success,
                          ),
                          child: const Text('가입하고 연결하기'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView(
                  padding: TabletLayout.appBarBodyPadding(context),
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: _stepTransitionBuilder,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<_OnboardingStep>(_step),
                        child: _buildStepContent(context),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String get _stepTitle {
    return switch (_step) {
      _OnboardingStep.role => '시작하기',
      _OnboardingStep.grade => '학년 선택',
      _OnboardingStep.details => '프로필 설정',
      _OnboardingStep.linkChildren =>
        _role == AppUserRole.parent ? '자녀 연결' : '학생 연결',
      _OnboardingStep.studentCode => '내 학생 고유번호',
    };
  }

  Widget _buildGradeStep(BuildContext context) {
    final grade = _selectedGrade;
    final displaySize = grade.length > 3 ? 36.0 : 48.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '현재 학년을 선택해 주세요',
          style: TextStyle(
            fontSize: TabletLayout.titleSection(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          '학년에 맞는 문제와 학습 경로를 추천해 드려요.',
          style: TextStyle(color: AppColors.textSub, height: 1.55),
        ),
        const SizedBox(height: AppSpacing.section),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.section,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  grade,
                  style: TextStyle(
                    fontSize: displaySize,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.surfaceMuted,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.12),
                  thumbShape: const _GradeSliderThumbShape(),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 32),
                  tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
                  activeTickMarkColor: AppColors.primary.withValues(alpha: 0.45),
                  inactiveTickMarkColor: AppColors.textMuted.withValues(alpha: 0.35),
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  value: _gradeIndex.toDouble(),
                  min: 0,
                  max: (_grades.length - 1).toDouble(),
                  divisions: _grades.length - 1,
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _gradeIndex = value.round()),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(_error!, style: const TextStyle(color: AppColors.accent)),
        ],
        const SizedBox(height: AppSpacing.section),
        FilledButton(
          onPressed: _loading ? null : _submitProfile,
          style: AppButtonStyles.filledKeyAction(),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('시작하기'),
        ),
      ],
    );
  }

  Widget _buildRoleStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: HeroIcon3d(
            asset: 'assets/icons/3d/onboarding_camera.png',
            tint: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          '우열, 시작!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: TabletLayout.titleHero(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          '어떤 계정으로 이용하시나요?',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSub, height: 1.55),
        ),
        const SizedBox(height: AppSpacing.section),
        _RoleCard(
          title: '학생',
          body: '풀이 사진 분석, 유사 문제 연습, 내 학습 대시보드',
          asset: 'assets/icons/3d/role_student.png',
          accent: AppColors.primary,
          selected: _highlightedRole == AppUserRole.student,
          dimmed: _highlightedRole != null &&
              _highlightedRole != AppUserRole.student,
          onTap: _loading || _roleAdvancePending
              ? null
              : () => _selectRole(AppUserRole.student),
        ),
        const SizedBox(height: AppSpacing.md),
        _RoleCard(
          title: '학부모',
          body: '오늘의 코칭 질문·틀린 문제 설명으로 자녀 학습 돕기',
          asset: 'assets/icons/3d/role_parent.png',
          accent: AppColors.success,
          selected: _highlightedRole == AppUserRole.parent,
          dimmed:
              _highlightedRole != null && _highlightedRole != AppUserRole.parent,
          onTap: _loading || _roleAdvancePending
              ? null
              : () => _selectRole(AppUserRole.parent),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(_error!, style: const TextStyle(color: AppColors.accent)),
        ],
      ],
    );
  }

  Widget _buildDetailsStep(BuildContext context) {
    if (_role == AppUserRole.teacher) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '기관 정보 (선택)',
            style: TextStyle(
              fontSize: TabletLayout.titleSection(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '학원·학교 이름을 입력하면 보고서에 표시됩니다.',
            style: TextStyle(color: AppColors.textSub, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            controller: _orgController,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: '예) 스마트수학학원',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(_error!, style: const TextStyle(color: AppColors.accent)),
          ],
          const SizedBox(height: AppSpacing.section),
          FilledButton(
            onPressed: _loading ? null : _submitProfile,
            style: AppButtonStyles.filledKeyAction(
              backgroundColor: AppColors.teacher,
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('다음'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: HeroIcon3d(
            asset: 'assets/icons/3d/parent_report.png',
            tint: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          '학부모 계정으로 시작합니다',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: TabletLayout.titleSection(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          '자녀가 푼 문제와 주간 보고서를 확인할 수 있어요. 다음 단계에서 자녀를 연결합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSub, height: 1.55),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(_error!, style: const TextStyle(color: AppColors.accent)),
        ],
        const SizedBox(height: AppSpacing.section),
        FilledButton(
          onPressed: _loading ? null : _submitProfile,
          style: AppButtonStyles.filledKeyAction(
            backgroundColor: AppColors.success,
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('다음'),
        ),
      ],
    );
  }

  Widget _buildStudentCodeStep(BuildContext context) {
    final code = _studentCode ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: HeroIcon3d(
            asset: 'assets/icons/3d/link_student.png',
            tint: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          '학부모·교사에게 알려주세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: TabletLayout.titleSection(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          '아래 번호를 공유하면 학부모·교사 계정에서 연결해 활동을 확인할 수 있습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSub, height: 1.55),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.primary),
          ),
          child: Text(
            code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: code.isEmpty ? null : _copyStudentCode,
          icon: const Icon(Icons.copy_rounded),
          label: const Text('번호 복사하기'),
        ),
        const SizedBox(height: AppSpacing.section),
        FilledButton(
          onPressed: _finish,
          style: AppButtonStyles.filledKeyAction(),
          child: const Text('시작하기'),
        ),
      ],
    );
  }
}

/// Pill-shaped thumb for grade slider — easier to grab than the default dot.
class _GradeSliderThumbShape extends SliderComponentShape {
  const _GradeSliderThumbShape();

  static const _width = 32.0;
  static const _height = 44.0;
  static const _radius = 12.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(_width, _height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final thumbColor = sliderTheme.thumbColor ?? AppColors.primary;
    final scale = 1 + (activationAnimation.value * 0.06);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: _width * scale,
        height: _height * scale,
      ),
      const Radius.circular(_radius),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..color = thumbColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final gripPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const gripSpan = 6.0;
    for (var i = -1; i <= 1; i++) {
      final dy = center.dy + (i * gripSpan);
      canvas.drawLine(
        Offset(center.dx - 5, dy),
        Offset(center.dx + 5, dy),
        gripPaint,
      );
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final _OnboardingStep current;

  /// Always 3 segments: 역할 → (학년 | 프로필) → (학생번호 | 연결)
  int get _activeIndex => switch (current) {
        _OnboardingStep.role => 0,
        _OnboardingStep.grade => 1,
        _OnboardingStep.details => 1,
        _OnboardingStep.studentCode => 2,
        _OnboardingStep.linkChildren => 2,
      };

  static const _stepCount = 3;

  @override
  Widget build(BuildContext context) {
    final index = _activeIndex.clamp(0, _stepCount - 1);

    return Row(
      children: [
        for (var i = 0; i < _stepCount; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i <= index
                    ? AppColors.primary
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.body,
    required this.asset,
    required this.accent,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final String title;
  final String body;
  final String asset;
  final Color accent;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: dimmed ? 0.42 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: selected ? 0.98 : 1,
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: onTap,
            splashColor: accent.withValues(alpha: 0.14),
            highlightColor: accent.withValues(alpha: 0.08),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(AppSpacing.lg + 2),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.14)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: selected ? accent : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Image.asset(asset, width: 48, height: 48),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: selected ? accent : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          body,
                          style: const TextStyle(
                            color: AppColors.textSub,
                            height: 1.45,
                          ),
                        ),
                      ],
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
