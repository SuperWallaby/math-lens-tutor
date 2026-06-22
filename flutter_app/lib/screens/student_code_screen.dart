import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../theme/app_design_system.dart';
import '../utils/student_code_format.dart';

class StudentCodeScreen extends StatelessWidget {
  const StudentCodeScreen({super.key, required this.studentCode});

  final String studentCode;

  Future<void> _copy(BuildContext context) async {
    await copyStudentCodeToClipboard(studentCode);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('학생 고유번호가 복사되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 학생 고유번호')),
      body: SafeArea(
        child: TabletBody(
          child: Padding(
            padding: TabletLayout.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학부모·교사에게 알려주세요',
                  style: TextStyle(
                    fontSize: TabletLayout.titleSection(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '번호를 복사해서 보내면, 학부모·교사가 앱에서 붙여넣어 연결할 수 있습니다.',
                  style: TextStyle(color: AppColors.textSub, height: 1.5),
                ),
                const SizedBox(height: 28),
                InkWell(
                  onTap: () => _copy(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      studentCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('번호 복사하기'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('시작하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
