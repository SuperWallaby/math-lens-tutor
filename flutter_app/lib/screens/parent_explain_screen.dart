import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../utils/problem_set_pdf.dart';
import '../widgets/app_card.dart';
import '../widgets/guardian_learning_gate.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/parent_tab_scaffold.dart';
import '../widgets/mixed_math_text.dart';
import '../theme/app_design_system.dart';

class ParentExplainScreen extends StatefulWidget {
  const ParentExplainScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ParentExplainScreen> createState() => _ParentExplainScreenState();
}

class _ParentExplainScreenState extends State<ParentExplainScreen> {
  Future<LearningProfile>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _profileFuture = widget.apiClient.getLearningProfile(forceRefresh: true);
    });
  }

  Future<void> _openDetail(ParentWrongExplainItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ParentExplainDetailScreen(
          apiClient: widget.apiClient,
          item: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GuardianLearningGate(
      apiClient: widget.apiClient,
      title: '틀린 문제 설명',
      onStudentChanged: _reload,
      child: FutureBuilder<LearningProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ProfileLoadingError(error: snapshot.error, onRetry: _reload);
          }

          final items = snapshot.data!.parentWrongExplains;
          return ParentLinkedScrollView(
            apiClient: widget.apiClient,
            onStudentChanged: _reload,
            children: [
              Text(
                '이해하기 쉬운 설명',
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '학부모가 자녀에게 바로 설명할 수 있도록 정리했어요.',
                style: TextStyle(color: AppColors.textSub, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const AppCard(
                  child: Text(
                    '아직 틀린 문제가 없거나, 학습 기록이 쌓이는 중이에요.',
                    style: TextStyle(color: AppColors.textSub, height: 1.5),
                  ),
                )
              else
                for (final item in items) ...[
                  AppCard(
                    child: InkWell(
                      onTap: () => _openDetail(item),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TagChip(item.concept, color: AppColors.accent),
                              const Spacer(),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  color: AppColors.textSub,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.easyExplain,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(height: 1.45, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.parentScript,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '자세히 · 연습 PDF',
                              style: TextStyle(
                                color: AppColors.textSub,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class ParentExplainDetailScreen extends StatefulWidget {
  const ParentExplainDetailScreen({
    super.key,
    required this.apiClient,
    required this.item,
  });

  final ApiClient apiClient;
  final ParentWrongExplainItem item;

  @override
  State<ParentExplainDetailScreen> createState() =>
      _ParentExplainDetailScreenState();
}

class _ParentExplainDetailScreenState extends State<ParentExplainDetailScreen> {
  bool _loadingPdf = false;
  String? _pdfError;

  Future<void> _openPracticePdf() async {
    if (widget.item.sourceType != 'submission') {
      if (widget.item.problemSetId == null) {
        setState(() => _pdfError = '연결된 연습 세트가 없습니다.');
        return;
      }
    }

    setState(() {
      _loadingPdf = true;
      _pdfError = null;
    });

    try {
      GeneratedProblemSet? set;
      if (widget.item.sourceType == 'submission') {
        final detail =
            await widget.apiClient.getSubmissionDetail(widget.item.sourceId);
        set = detail.problemSet;
      }

      if (!mounted) return;
      if (set == null || set.problems.isEmpty) {
        setState(() => _pdfError = '발행할 유사문제가 아직 없습니다.');
        return;
      }

      await openSimilarProblemsPdf(context, set);
    } catch (error) {
      if (mounted) {
        setState(() => _pdfError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: TabletLayout.pagePadding(context),
        children: [
          TagChip(item.concept, color: AppColors.accent),
          const SizedBox(height: 16),
          const SectionLabel('쉬운 설명'),
          AppCard(
            child: MixedMathText(
              item.easyExplain,
              style: const TextStyle(height: 1.55, fontSize: 14),
            ),
          ),
          const SectionLabel('자녀에게 이렇게 말해보세요'),
          AppCard(
            child: Text(
              item.parentScript,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.5,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadingPdf ? null : _openPracticePdf,
            icon: _loadingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_loadingPdf ? '준비 중…' : '유사문제 PDF 발행'),
          ),
          if (_pdfError != null) ...[
            const SizedBox(height: 8),
            Text(
              _pdfError!,
              style: const TextStyle(color: AppColors.accent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            '인쇄하거나 카카오톡으로 보내 자녀와 함께 풀 수 있어요.',
            style: TextStyle(color: AppColors.textSub, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
