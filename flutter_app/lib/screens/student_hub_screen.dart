import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/learning_profile_widgets.dart';
import 'practice_screen.dart';
import 'upload_screen.dart';

class StudentHubScreen extends StatefulWidget {
  const StudentHubScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<StudentHubScreen> createState() => _StudentHubScreenState();
}

class _StudentHubScreenState extends State<StudentHubScreen> {
  Future<LearningProfile>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _profileFuture = widget.apiClient.getLearningProfile();
    });
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

  Future<void> _openMission(TodayMission mission) async {
    final setId = mission.setId;
    if (setId == null || setId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진행 중인 문제 세트가 없습니다. 먼저 풀이를 분석해 주세요.')),
      );
      return;
    }

    try {
      final set = await widget.apiClient.getProblemSet(setId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PracticeScreen(
            apiClient: widget.apiClient,
            problemSet: set,
          ),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.authSession.user;

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<LearningProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              children: const [
                SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                ProfileLoadingError(error: snapshot.error, onRetry: _reload),
              ],
            );
          }

          final profile = snapshot.data!;
          return ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              StatsHero(
                greeting: '안녕하세요 👋',
                name: user?.displayName ?? '학생',
                stats: profile.stats,
              ),
              SectionLabel('틀린 문제 올리기'),
              Material(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UploadScreen(apiClient: widget.apiClient),
                      ),
                    );
                    _reload();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '사진\n업로드',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '틀린 문제 사진 찍기',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'AI가 왜 틀렸는지 분석해드려요',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF60A5FA)),
                      ],
                    ),
                  ),
                ),
              ),
              if (profile.mission != null) ...[
                SectionLabel('오늘의 미션'),
                MissionCard(
                  mission: profile.mission!,
                  onTap: () => _openMission(profile.mission!),
                ),
              ],
              SectionLabel('지금 약한 개념'),
              ConceptStatusCard(items: profile.conceptStatus),
              if (user?.studentCode != null) ...[
                SectionLabel('연결 코드'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '부모님 · 선생님께 이 코드를 알려주세요',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user!.studentCode!,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF60A5FA),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _copyStudentCode,
                        child: const Text('복사'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
