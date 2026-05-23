import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/student_picker.dart';
import '../screens/link_student_screen.dart';

class GuardianLearningGate extends StatelessWidget {
  const GuardianLearningGate({
    super.key,
    required this.apiClient,
    required this.title,
    required this.onStudentChanged,
    required this.child,
  });

  final ApiClient apiClient;
  final String title;
  final VoidCallback onStudentChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: apiClient.authSession,
      builder: (context, _) {
        final linked = apiClient.authSession.linkedStudents;

        if (linked.isEmpty) {
          return ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  children: [
                    const Text(
                      '연결된 학생이 없습니다',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '학생 고유번호로 연결하면 학습 현황을 확인할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LinkStudentScreen(apiClient: apiClient),
                          ),
                        );
                        onStudentChanged();
                      },
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('학생 연결하기'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: TabletLayout.pagePadding(context).copyWith(bottom: 0),
              child: StudentPicker(
                authSession: apiClient.authSession,
                onChanged: onStudentChanged,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
