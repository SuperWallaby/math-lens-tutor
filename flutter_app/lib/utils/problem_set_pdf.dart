import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_models.dart';
import 'math_mixed_segments.dart';
import 'math_tex_raster.dart';
import 'problem_answer_format.dart';

bool _hasJsxFigure(GeneratedProblem p) {
  final g = p.jsxGraph;
  if (g == null) return false;
  if (g['diagramNeeded'] == true) return true;
  final els = g['elements'];
  return els is List && els.isNotEmpty;
}

void _appendPlainPdfSpans(
  List<pw.InlineSpan> buffer,
  String plain,
  pw.TextStyle style,
) {
  if (plain.isEmpty) return;
  final lines = plain.split('\n').where((line) => line.isNotEmpty).toList();
  for (var i = 0; i < lines.length; i++) {
    buffer.add(pw.TextSpan(text: lines[i], style: style));
    if (i < lines.length - 1) {
      buffer.add(pw.TextSpan(text: '\n', style: style));
    }
  }
}

Future<List<pw.Widget>> _buildPdfMixedBlocks(
  OverlayState overlay,
  String text, {
  required pw.TextStyle style,
}) async {
  final source = compactMathMixedLineBreaks(text);
  final segs = parseMathMixed(source);
  final blocks = <pw.Widget>[];
  var inlineSpans = <pw.InlineSpan>[];
  final fontSize = style.fontSize ?? 10;

  Future<void> flushInline() async {
    if (inlineSpans.isEmpty) return;
    blocks.add(
      pw.RichText(
        text: pw.TextSpan(style: style, children: [...inlineSpans]),
      ),
    );
    inlineSpans = [];
  }

  for (final seg in segs) {
    switch (seg.kind) {
      case MathMixedSegmentKind.plain:
        _appendPlainPdfSpans(inlineSpans, seg.value, style);
        break;
      case MathMixedSegmentKind.inlineMath:
        final png = await rasterizeTexToPng(
          overlay,
          seg.value,
          fontSize: fontSize,
        );
        if (png != null) {
          inlineSpans.add(
            pw.WidgetSpan(
              child: pw.Image(
                pw.MemoryImage(png),
                height: fontSize * 1.35,
              ),
            ),
          );
        } else {
          inlineSpans.add(pw.TextSpan(text: seg.value, style: style));
        }
        break;
      case MathMixedSegmentKind.displayMath:
        await flushInline();
        final png = await rasterizeTexToPng(
          overlay,
          seg.value,
          fontSize: fontSize + 1,
          display: true,
        );
        if (png != null) {
          blocks.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Image(pw.MemoryImage(png)),
            ),
          );
        } else {
          blocks.add(pw.Text(seg.value, style: style));
        }
        break;
    }
  }

  await flushInline();
  return blocks;
}

Future<Uint8List> buildSimilarProblemsPdf(
  BuildContext context,
  GeneratedProblemSet set,
  PdfPageFormat format,
) async {
  if (!context.mounted) {
    throw StateError('PDF 생성 중 화면이 닫혔습니다.');
  }
  final overlay = Overlay.of(context, rootOverlay: true);

  final base = await PdfGoogleFonts.notoSansKRRegular();
  final bold = await PdfGoogleFonts.notoSansKRBold();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: base, bold: bold),
  );

  final bodyStyle = pw.TextStyle(fontSize: 10, lineSpacing: 2);
  final titleBlocks = await _buildPdfMixedBlocks(
    overlay,
    set.title,
    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
  );
  final goalBlocks = await _buildPdfMixedBlocks(
    overlay,
    set.learningGoal,
    style: bodyStyle,
  );

  final problemWidgets = <pw.Widget>[];
  for (var i = 0; i < set.problems.length; i++) {
    final p = set.problems[i];
    final meta =
        '문제 ${i + 1} · ${formatDifficultyLabel(p.difficulty)}${p.conceptTags.isNotEmpty ? ' · ${p.conceptTags.join(', ')}' : ''}';
    final promptBlocks = await _buildPdfMixedBlocks(
      overlay,
      p.prompt,
      style: bodyStyle,
    );
    final titleBlocks = await _buildPdfMixedBlocks(
      overlay,
      p.title,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    );

    final children = <pw.Widget>[
      pw.Text(
        meta,
        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 4),
      ...titleBlocks,
      pw.SizedBox(height: 6),
      ...promptBlocks,
    ];

    if (p.chart != null || _hasJsxFigure(p)) {
      children.addAll([
        pw.SizedBox(height: 4),
        pw.Text(
          '(그래프·도형은 앱·웹 화면에서 확인하세요.)',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ]);
    }

    if (p.isMultipleChoice) {
      children.add(pw.SizedBox(height: 6));
      for (final c in p.choices) {
        final choiceBlocks = await _buildPdfMixedBlocks(
          overlay,
          '${c.id}. ${c.label}',
          style: bodyStyle,
        );
        children.addAll([
          ...choiceBlocks,
          pw.SizedBox(height: 2),
        ]);
      }
    }

    problemWidgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      build: (context) {
        return [
          pw.Text(
            '유사 문제 세트 · ${set.id}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          ...titleBlocks,
          pw.SizedBox(height: 8),
          ...goalBlocks,
          pw.SizedBox(height: 14),
          ...problemWidgets,
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              '인쇄·공유 메뉴에서 PDF로 저장할 수 있습니다.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
        ];
      },
    ),
  );

  return doc.save();
}

Future<void> openSimilarProblemsPdf(
  BuildContext context,
  GeneratedProblemSet set,
) async {
  await Printing.layoutPdf(
    onLayout: (format) => buildSimilarProblemsPdf(context, set, format),
    name: '유사문제.pdf',
  );
}
