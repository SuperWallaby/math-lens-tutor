import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../layout/tablet_layout.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import '../utils/problem_image_picker.dart';
import 'analysis_screen.dart';

/// 카메라·앨범 → 분석 → 유사문제/PDF/풀이만 제공하는 미니멀 홈.
class LiteHomeScreen extends StatelessWidget {
  const LiteHomeScreen({
    super.key,
    required this.apiClient,
  });

  final ApiClient apiClient;

  Future<void> _pickAndAnalyze(
    BuildContext context, {
    required ImageSource source,
  }) async {
    final picked = await pickProblemImage(source: source, context: context);
    if (picked == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          apiClient: apiClient,
          imageBytes: picked.bytes,
          uploadFilename: picked.filename,
          liteMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: TabletLayout.isWideTablet(context) ? 28 : 24,
      fontWeight: FontWeight.w900,
      height: 1.25,
    );
    final subtitleStyle = TextStyle(
      color: AppColors.textSub,
      fontSize: TabletLayout.body(context),
      height: 1.5,
    );

    return Scaffold(
      body: SafeArea(
        child: TabletBody(
          child: Padding(
            padding: TabletLayout.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text('우열 라이트', style: titleStyle),
                const SizedBox(height: 10),
                Text(
                  '풀이 사진만 올리면\n분석 · 유사문제 · PDF까지 한 번에',
                  style: subtitleStyle,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _pickAndAnalyze(
                    context,
                    source: primaryProblemImageSource,
                  ),
                  icon: const Icon(Icons.photo_camera_rounded, size: 26),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      '카메라로 풀이 촬영',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickAndAnalyze(
                    context,
                    source: ImageSource.gallery,
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('앨범에서 선택'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
