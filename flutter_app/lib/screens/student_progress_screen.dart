import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/guardian_learning_gate.dart';
import '../widgets/learning_profile_widgets.dart';
import 'practice_screen.dart';

class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({
    super.key,
    required this.apiClient,
    this.viewAsGuardian = false,
  });

  final ApiClient apiClient;
  final bool viewAsGuardian;

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  Future<LearningProfile>? _profileFuture;
  late int _gradeTab;
  bool _gradeTabTouched = false;

  @override
  void initState() {
    super.initState();
    _gradeTab = gradeBandTabIndex(widget.apiClient.authSession.user?.grade);
    _reload();
  }

  void _reload() {
    if (widget.viewAsGuardian &&
        widget.apiClient.authSession.linkedStudents.isEmpty) {
      setState(() => _profileFuture = null);
      return;
    }
    setState(() {
      _profileFuture = widget.apiClient.getLearningProfile();
    });
  }

  void _onGradeTabChanged(int index) {
    setState(() {
      _gradeTab = index;
      _gradeTabTouched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<LearningProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ProfileLoadingError(error: snapshot.error, onRetry: _reload);
        }

        final profile = snapshot.data!;
        final userGradeTab = gradeBandTabIndex(profile.grade);
        if (!_gradeTabTouched && _gradeTab != userGradeTab) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_gradeTabTouched) {
              setState(() => _gradeTab = userGradeTab);
            }
          });
        }

        return _ProgressContent(
          apiClient: widget.apiClient,
          viewAsGuardian: widget.viewAsGuardian,
          profile: profile,
          gradeTab: _gradeTab,
          userGradeTab: userGradeTab,
          onGradeTabChanged: _onGradeTabChanged,
          onReload: _reload,
        );
      },
    );

    if (!widget.viewAsGuardian) {
      return body;
    }

    return GuardianLearningGate(
      apiClient: widget.apiClient,
      title: '교육과정 진도',
      onStudentChanged: () {
        _gradeTabTouched = false;
        _reload();
      },
      child: body,
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.apiClient,
    required this.viewAsGuardian,
    required this.profile,
    required this.gradeTab,
    required this.userGradeTab,
    required this.onGradeTabChanged,
    required this.onReload,
  });

  final ApiClient apiClient;
  final bool viewAsGuardian;
  final LearningProfile profile;
  final int gradeTab;
  final int userGradeTab;
  final ValueChanged<int> onGradeTabChanged;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final showUnits = gradeTab == userGradeTab;

    return RefreshIndicator(
      onRefresh: () async => onReload(),
      child: ListView(
        padding: TabletLayout.pagePadding(context),
        children: [
          Text(
            viewAsGuardian ? '교육과정 진도' : '내 진도 현황',
            style: TextStyle(
              fontSize: TabletLayout.titleSection(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '2022 개정 교육과정 · ${profile.grade}',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: gradeBandLabels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final selected = gradeTab == index;
                return ChoiceChip(
                  label: Text(gradeBandLabels[index]),
                  selected: selected,
                  onSelected: (_) => onGradeTabChanged(index),
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (showUnits)
            CurriculumProgressList(
              units: profile.curriculumUnits,
              chainWarning: profile.chainWarning,
              gradeLabel: gradeBandLabels[gradeTab],
            )
          else
            AppCard(
              child: Column(
                children: [
                  const Text('📖', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    gradeBandPlaceholderTitle(gradeTab),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    gradeBandPlaceholderSubtitle(gradeTab),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          if (!viewAsGuardian && profile.mission?.setId != null) ...[
            SectionLabel('이어서 훈련'),
            OutlinedButton.icon(
              onPressed: () async {
                final setId = profile.mission!.setId!;
                try {
                  final set = await apiClient.getProblemSet(setId);
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PracticeScreen(
                        apiClient: apiClient,
                        problemSet: set,
                      ),
                    ),
                  );
                  onReload();
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('미션 이어하기'),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
