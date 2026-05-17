import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layout/tablet_layout.dart';
import '../services/api_client.dart';
import 'dashboard_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              const SizedBox(height: 24),
              Text(
                '우열',
                style: TextStyle(
                  fontSize: TabletLayout.titleHero(context),
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              SizedBox(height: TabletLayout.isWideTablet(context) ? 20 : 16),
              Text(
                '풀이 사진을 찍으면 AI가 오답 원인과 부족 개념을 분석하고, 유사 문제 5개로 바로 훈련합니다.',
                style: TextStyle(
                  color: const Color(0xFFCBD5E1),
                  fontSize: TabletLayout.body(context),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
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
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DashboardScreen(apiClient: widget.apiClient),
                    ),
                  );
                },
                icon: const Icon(Icons.insights_rounded),
                label: const Text('학습 대시보드'),
              ),
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
