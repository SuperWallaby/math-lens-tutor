import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/learning_profile_widgets.dart';
import 'practice_screen.dart';
import 'upload_screen.dart';

class StudentTrainingScreen extends StatefulWidget {
  const StudentTrainingScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<StudentTrainingScreen> createState() => _StudentTrainingScreenState();
}

class _StudentTrainingScreenState extends State<StudentTrainingScreen> {
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

  Future<void> _openSet(String setId) async {
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
    return FutureBuilder<LearningProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ProfileLoadingError(error: snapshot.error, onRetry: _reload);
        }

        final profile = snapshot.data!;
        final mission = profile.mission;

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Text(
                '유사문제 훈련',
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '정답률 ${profile.stats.accuracy}% · ${profile.insight.levelLabel}',
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 20),
              if (mission != null && mission.setId != null) ...[
                MissionCard(
                  mission: mission,
                  onTap: () => _openSet(mission.setId!),
                ),
              ] else ...[
                AppCard(
                  child: Column(
                    children: [
                      const Text('📝', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      const Text(
                        '진행 중인 훈련이 없어요',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '틀린 문제를 업로드하면 AI가 유사문제 5개를 만들어 드려요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  UploadScreen(apiClient: widget.apiClient),
                            ),
                          );
                          _reload();
                        },
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('풀이 사진 분석하기'),
                      ),
                    ],
                  ),
                ),
              ],
              SectionLabel('약점 개념'),
              ConceptStatusCard(items: profile.conceptStatus),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
