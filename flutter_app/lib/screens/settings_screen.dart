import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../theme/app_design_system.dart';
import '../services/api_client.dart';
import '../services/app_prefs.dart';
import '../services/oauth_service.dart';
import '../utils/problem_image_picker.dart';
import '../utils/student_code_format.dart';
import '../widgets/app_card.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/student_picker.dart';
import 'link_student_screen.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.apiClient,
    required this.oauthService,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _missionAlerts = true;
  bool _weeklyReport = true;
  bool _coachingDaily = true;
  bool _loadingStudentCode = false;
  bool _studentCodeFetchDone = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureStudentCode());
  }

  Future<void> _loadPrefs() async {
    final prefs = await getAppPrefs();
    if (!mounted) return;
    setState(() {
      _missionAlerts = prefs.getBool('notify_mission') ?? true;
      _weeklyReport = prefs.getBool('notify_weekly') ?? true;
      _coachingDaily = prefs.getBool('notify_coaching_daily') ?? true;
    });
  }

  Future<void> _ensureStudentCode() async {
    final session = widget.apiClient.authSession;
    final user = session.user;
    if (user?.isStudent != true) return;
    if (user?.studentCode != null && user!.studentCode!.isNotEmpty) return;
    if (session.isGuest || !session.isSignedIn) return;
    if (_loadingStudentCode || _studentCodeFetchDone) return;

    setState(() => _loadingStudentCode = true);
    try {
      await widget.apiClient.fetchMe();
    } catch (_) {
      // 세션 갱신 실패 — 아래 UI에서 안내만 표시
    } finally {
      if (mounted) {
        setState(() {
          _loadingStudentCode = false;
          _studentCodeFetchDone = true;
        });
      }
    }
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await getAppPrefs();
    await prefs.setBool(key, value);
  }

  Future<void> _copyStudentCode() async {
    final code = widget.apiClient.authSession.user?.studentCode;
    if (code == null) return;
    await copyStudentCodeToClipboard(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('학생 고유번호가 복사되었습니다.')),
    );
  }

  Future<void> _openSignIn() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupScreen(
          apiClient: widget.apiClient,
          oauthService: widget.oauthService,
          signupOnly: widget.apiClient.authSession.isGuest,
          onSignedIn: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _studentCodeFetchDone = false;
      });
      await _ensureStudentCode();
    }
  }

  Future<void> _logout() async {
    widget.apiClient.invalidateLearningProfileCache();
    await widget.apiClient.authSession.clear();
  }

  Future<void> _pickProfileImage() async {
    if (widget.apiClient.authSession.isGuest) return;

    final picked = await pickProfileImage(context: context);
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      await widget.apiClient.uploadProfileAvatar(
        bytes: picked.bytes,
        filename: picked.filename,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진을 변경했습니다.')),
      );
      setState(() {});
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _openEditProfile() async {
    final user = widget.apiClient.authSession.user;
    if (user == null || widget.apiClient.authSession.isGuest) return;

    await showEditProfileSheet(
      context: context,
      apiClient: widget.apiClient,
      user: user,
      onSaved: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기본 정보를 저장했습니다.')),
        );
        setState(() {});
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 탈퇴'),
        content: const Text(
          '학습 기록과 연결 정보가 모두 삭제되며 되돌릴 수 없습니다.\n정말 탈퇴하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.apiClient.deleteAccount();
      widget.apiClient.invalidateLearningProfileCache();
      await widget.apiClient.authSession.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계정을 탈퇴했습니다.')),
      );
      setState(() {});
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.authSession.user;
    final isGuest = widget.apiClient.authSession.isGuest;
    final studentCode = user?.studentCode;

    return ListenableBuilder(
      listenable: widget.apiClient.authSession,
      builder: (context, _) {
        return ListView(
          padding: TabletLayout.pagePadding(context),
          children: [
            if (user?.role == AppUserRole.parent &&
                widget.apiClient.authSession.linkedStudents.isNotEmpty) ...[
              StudentPicker(
                authSession: widget.apiClient.authSession,
                apiClient: widget.apiClient,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              '설정',
              style: TextStyle(
                fontSize: TabletLayout.titleSection(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            if (isGuest) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        '로그인하지 않은 게스트 모드입니다.',
                        style: TextStyle(
                          color: AppColors.textSub,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openSignIn,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text('로그인'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ProfileAvatar(
                            user: user,
                            size: 72,
                            showEditBadge:
                                !isGuest && widget.apiClient.authSession.isSignedIn,
                            onTap: isGuest ||
                                    !widget.apiClient.authSession.isSignedIn ||
                                    _uploadingAvatar
                                ? null
                                : _pickProfileImage,
                          ),
                          if (_uploadingAvatar)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Color(0x66FFFFFF),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _SettingsProfileChip(
                                  label: user?.role?.label ?? '역할 미설정',
                                ),
                                if (user?.grade != null)
                                  _SettingsProfileChip(label: user!.grade!),
                                if (user?.organizationName != null)
                                  _SettingsProfileChip(
                                    label: user!.organizationName!,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isGuest && widget.apiClient.authSession.isSignedIn) ...[
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _openEditProfile,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('기본 정보 수정'),
                    ),
                  ],
                ],
              ),
            ),
            if (user?.isStudent == true) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '내 학생 고유번호',
                      style: TextStyle(color: AppColors.textSub),
                    ),
                    const SizedBox(height: 6),
                    if (_loadingStudentCode)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    else if (studentCode != null)
                      InkWell(
                        onTap: _copyStudentCode,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            studentCode,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        isGuest
                            ? '로그인하면 학생 고유번호가 발급됩니다.'
                            : '번호를 불러올 수 없습니다.',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    if (studentCode != null) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '탭하거나 복사해서 학부모·교사에게 보내주세요.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _copyStudentCode,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('번호 복사'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (user?.isGuardian ?? false) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LinkStudentScreen(apiClient: widget.apiClient),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.link_rounded),
                label: const Text('학생 연결 관리'),
              ),
            ],
            const SizedBox(height: 20),
            if (user?.isStudent == true || user?.isGuardian == true) ...[
              const Text(
                '학습',
                style: TextStyle(
                  color: AppColors.textSub,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  onTap: () => DashboardScreen.open(context, widget.apiClient),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.insights_outlined,
                            size: 22,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.isGuardian == true
                                    ? '학생 학습 통계'
                                    : '학습 통계',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const Text(
                                '정답률 · 주간 추이 · 약점 개념',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  height: 1.35,
                                ),
                              ),
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
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              '알림',
              style: TextStyle(
                color: AppColors.textSub,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  if (user?.isStudent == true) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('오늘의 미션 알림'),
                      subtitle: const Text(
                        '남은 유사문제가 있을 때 알려드려요',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      value: _missionAlerts,
                      onChanged: (value) {
                        setState(() => _missionAlerts = value);
                        _setPref('notify_mission', value);
                      },
                    ),
                    const Divider(color: AppColors.border),
                  ],
                  if (user?.role == AppUserRole.parent) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('오늘의 부모 코칭'),
                      subtitle: const Text(
                        '매일 코칭 질문과 틀린 문제 설명을 알려드려요',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      value: _coachingDaily,
                      onChanged: (value) {
                        setState(() => _coachingDaily = value);
                        _setPref('notify_coaching_daily', value);
                      },
                    ),
                    const Divider(color: AppColors.border),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('주간 보고서'),
                    subtitle: Text(
                      switch (user?.role) {
                        AppUserRole.student => '매주 학습 요약을 받아보세요',
                        AppUserRole.parent => '매주 자녀 학습 요약을 받아보세요',
                        AppUserRole.teacher => '매주 학생 학습 요약을 받아보세요',
                        _ => '매주 학습 요약을 받아보세요',
                      },
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    value: _weeklyReport,
                    onChanged: (value) {
                      setState(() => _weeklyReport = value);
                      _setPref('notify_weekly', value);
                    },
                  ),
                ],
              ),
            ),
            if (!isGuest) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('로그아웃'),
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: _confirmDeleteAccount,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '계정 탈퇴',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        );
      },
    );
  }
}

class _SettingsProfileChip extends StatelessWidget {
  const _SettingsProfileChip({required this.label});

  final String label;

  static const _chipBackground = Color(0xFFE8EEF4);
  static const _chipText = Color(0xFF3D4A5C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: _chipBackground,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _chipText,
          height: 1.2,
        ),
      ),
    );
  }
}
