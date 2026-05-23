import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import 'dashboard_screen.dart';
import 'link_student_screen.dart';
import 'upload_screen.dart';

const _kStudyReturnUser = 'study_return_user';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _redirectChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRedirectToUpload());
  }

  Future<void> _maybeRedirectToUpload() async {
    if (_redirectChecked || !mounted) return;
    _redirectChecked = true;

    final user = widget.apiClient.authSession.user;
    if (user?.isGuardian ?? false) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool(_kStudyReturnUser) ?? false) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UploadScreen(apiClient: widget.apiClient),
        ),
      );
    }
  }

  Future<void> _copyStudentCode() async {
    final code = widget.apiClient.authSession.user?.studentCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('학생 고유번호가 복사되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.authSession.user;
    final isGuardian = user?.isGuardian ?? false;
    final isStudent = user?.isStudent ?? false;

    return Scaffold(
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '우열',
                      style: TextStyle(
                        fontSize: TabletLayout.titleHero(context),
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ),
                  if (user != null)
                    Chip(
                      label: Text(user.role?.label ?? '가입 중'),
                    ),
                ],
              ),
              SizedBox(height: TabletLayout.isWideTablet(context) ? 20 : 16),
              Text(
                isGuardian
                    ? '연결된 학생의 활동과 수준을 대시보드에서 확인할 수 있습니다. 풀이 등록은 학생 계정에서 진행해 주세요.'
                    : '풀이 사진을 찍으면 AI가 오답 원인과 부족 개념을 분석하고, 유사 문제 5개로 바로 훈련합니다.',
                style: TextStyle(
                  color: const Color(0xFFCBD5E1),
                  fontSize: TabletLayout.body(context),
                  height: 1.55,
                ),
              ),
              if (isStudent && user?.studentCode != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '내 학생 고유번호',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user!.studentCode!,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _copyStudentCode,
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: '복사',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (isStudent) ...[
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UploadScreen(apiClient: widget.apiClient),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('풀이 사진 분석하기'),
                ),
                const SizedBox(height: 12),
              ] else if (isGuardian) ...[
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LinkStudentScreen(
                          apiClient: widget.apiClient,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('학생 연결하기'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: isGuardian &&
                        widget.apiClient.authSession.linkedStudents.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                DashboardScreen(apiClient: widget.apiClient),
                          ),
                        );
                      },
                icon: const Icon(Icons.insights_rounded),
                label: Text(isGuardian ? '학생 학습 대시보드' : '학습 대시보드'),
              ),
              if (isGuardian &&
                  widget.apiClient.authSession.linkedStudents.isEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '대시보드를 보려면 먼저 학생 고유번호로 연결해 주세요.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ],
              const SizedBox(height: 32),
              const _FeatureTile(
                icon: Icons.image_search_rounded,
                title: '사진 기반 분석',
                body: 'Azure OpenAI는 서버에서만 호출하고 앱에는 API 키를 넣지 않습니다.',
              ),
              const _FeatureTile(
                icon: Icons.quiz_rounded,
                title: '네이티브 문제풀이',
                body: '객관식 1~5번과 주관식 답안을 Flutter 화면에서 제출합니다.',
              ),
              const _FeatureTile(
                icon: Icons.bar_chart_rounded,
                title: '수준 피드백',
                body: 'MongoDB에 누적된 풀이 기록으로 약점과 정답률을 보여줍니다.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF60A5FA)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: TabletLayout.isWideTablet(context) ? 18 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: const Color(0xFF94A3B8),
                    height: 1.45,
                    fontSize: TabletLayout.bodySmall(context),
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
