import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import 'practice_generating_screen.dart';
import 'practice_screen.dart';

const _fastPathTimeout = Duration(milliseconds: 500);

/// preview 없이 POST 1회 — 빠르면 바로 연습, AI 생성이면 생성 화면으로 전환.
Future<void> openPracticeWithSingleRequest(
  BuildContext context, {
  required ApiClient apiClient,
  required Future<StartPracticeResult> Function() start,
  required String subtitle,
  String generatingTitle = 'AI 맞춤 문제 만드는 중…',
  String iconAsset = 'assets/icons/3d/practice_start.png',
}) async {
  final request = start();

  StartPracticeResult? fastResult;
  try {
    fastResult = await request.timeout(_fastPathTimeout);
  } on TimeoutException {
    fastResult = null;
  } catch (error) {
    if (!context.mounted) return;
    final message = switch (error) {
      ApiException(:final message) => message,
      _ => error.toString(),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  if (!context.mounted) return;

  if (fastResult != null) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeScreen(
          apiClient: apiClient,
          problemSet: fastResult!.problemSet,
        ),
      ),
    );
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PracticeGeneratingScreen(
        apiClient: apiClient,
        title: generatingTitle,
        subtitle: subtitle,
        iconAsset: iconAsset,
        request: request,
      ),
    ),
  );
}

/// Bank가 충분하면 짧은 로딩만, AI 생성이 필요할 때만 전용 생성 화면을 띄웁니다.
@Deprecated('Use openPracticeWithSingleRequest — preview+POST merged')
Future<void> openPracticeWithAvailabilityCheck(
  BuildContext context, {
  required ApiClient apiClient,
  required Future<PracticeAvailabilityPreview> Function() preview,
  required Future<GeneratedProblemSet> Function() generate,
  required String subtitle,
  String generatingTitle = 'AI 맞춤 문제 만드는 중…',
  String iconAsset = 'assets/icons/3d/practice_start.png',
}) async {
  await openPracticeWithSingleRequest(
    context,
    apiClient: apiClient,
    start: () async {
      final set = await generate();
      return StartPracticeResult(
        problemSet: set,
        meta: const PracticeAvailabilityPreview(
          bankCount: 5,
          setSize: 5,
          needsGeneration: false,
          generateCount: 0,
        ),
      );
    },
    subtitle: subtitle,
    generatingTitle: generatingTitle,
    iconAsset: iconAsset,
  );
}

String buildPracticeGeneratingSubtitle({
  required String base,
  required PracticeAvailabilityPreview availability,
}) {
  final trimmed = base.trim();
  final detail =
      '저장 ${availability.bankCount}개 · AI 생성 ${availability.generateCount}개';
  if (trimmed.isEmpty) return detail;
  return '$trimmed\n$detail';
}

/// 짧은 bank-only 로딩 다이얼로그
Future<T> withBriefPracticeLoading<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  if (!context.mounted) {
    return action();
  }

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 16),
                  Text(
                    '문제 준비 중…',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  try {
    return await action();
  } finally {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
