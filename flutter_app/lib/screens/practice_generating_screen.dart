import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import '../widgets/bouncing_ellipsis_text.dart';
import '../widgets/hero_icon_3d.dart';
import 'practice_screen.dart';

/// 단원·훈련 시작 시 AI 문제 생성 대기 — 즉시 푸시해 멈춘 화면 대신 피드백을 줍니다.
class PracticeGeneratingScreen extends StatefulWidget {
  const PracticeGeneratingScreen({
    super.key,
    required this.apiClient,
    this.generate,
    this.request,
    this.title = '문제 만드는 중…',
    this.subtitle,
    this.iconAsset = 'assets/icons/3d/practice_start.png',
    this.generateCount,
    this.setSize = 5,
  }) : assert(generate != null || request != null);

  final ApiClient apiClient;
  final Future<GeneratedProblemSet> Function()? generate;
  final Future<StartPracticeResult>? request;
  final String title;
  final String? subtitle;
  final String iconAsset;
  final int? generateCount;
  final int setSize;

  @override
  State<PracticeGeneratingScreen> createState() => _PracticeGeneratingScreenState();
}

class _PracticeGeneratingScreenState extends State<PracticeGeneratingScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _dotsController;
  String? _error;
  String? _resolvedSubtitle;
  int? _generateCount;
  int _setSize = 5;

  @override
  void initState() {
    super.initState();
    _resolvedSubtitle = widget.subtitle;
    _generateCount = widget.generateCount;
    _setSize = widget.setSize;
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _dotsController?.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final GeneratedProblemSet set;
      if (widget.request != null) {
        final result = await widget.request!;
        if (mounted && result.meta.needsGeneration) {
          setState(() {
            _generateCount = result.meta.generateCount;
            _setSize = result.meta.setSize;
            if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) {
              _resolvedSubtitle =
                  '${widget.subtitle!.trim()}\n저장 ${result.meta.bankCount}개 · AI 생성 ${result.meta.generateCount}개';
            }
          });
        }
        set = result.problemSet;
      } else {
        set = await widget.generate!();
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PracticeScreen(
            apiClient: widget.apiClient,
            problemSet: set,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error) {
          ApiException(:final message) => message,
          _ => error.toString(),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: TabletLayout.titleSection(context),
      fontWeight: FontWeight.w900,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('연습 준비'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: TabletLayout.pagePadding(context),
          child: _error != null
              ? _ErrorBody(message: _error!, onBack: () => Navigator.of(context).pop())
              : Column(
                  children: [
                    const Spacer(flex: 2),
                    HeroIcon3d(asset: widget.iconAsset, size: 128, iconSize: 80),
                    const SizedBox(height: 28),
                    BouncingEllipsisText(
                      text: widget.title,
                      controller: _dotsController!,
                      style: titleStyle.copyWith(color: AppColors.primary),
                    ),
                    if (_resolvedSubtitle != null &&
                        _resolvedSubtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _resolvedSubtitle!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSub,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _generateCount != null && _generateCount! > 0
                          ? '저장된 문제 ${_setSize - _generateCount!}개를 쓰고,\nAI가 ${_generateCount}개를 새로 만들고 있어요.'
                          : '잠시만 기다려 주세요.\nAI가 맞춤 문제를 준비하고 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSub,
                        height: 1.55,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(flex: 3),
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),
        HeroIcon3d(
          asset: 'assets/icons/3d/analysis_fail.png',
          size: 128,
          iconSize: 80,
          tint: AppColors.accent,
        ),
        const SizedBox(height: 24),
        Text(
          '문제를 만들지 못했어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: TabletLayout.titleSection(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSub, height: 1.5),
        ),
        const Spacer(flex: 3),
        FilledButton(onPressed: onBack, child: const Text('돌아가기')),
      ],
    );
  }
}
