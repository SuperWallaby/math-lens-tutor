import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_models.dart';

bool _hasJsxFigure(GeneratedProblem p) {
  final g = p.jsxGraph;
  if (g == null) return false;
  if (g['diagramNeeded'] == true) return true;
  final els = g['elements'];
  return els is List && els.isNotEmpty;
}

Future<Uint8List> buildSimilarProblemsPdf(
  GeneratedProblemSet set,
  PdfPageFormat format,
) async {
  final base = await PdfGoogleFonts.notoSansKRRegular();
  final bold = await PdfGoogleFonts.notoSansKRBold();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: base, bold: bold),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      build: (context) {
        final out = <pw.Widget>[
          pw.Text(
            '유사 문제 세트 · ${set.id}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            set.title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(set.learningGoal, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 14),
        ];

        for (var i = 0; i < set.problems.length; i++) {
          final p = set.problems[i];
          final meta =
              '문제 ${i + 1} · ${p.difficulty}${p.conceptTags.isNotEmpty ? ' · ${p.conceptTags.join(', ')}' : ''}';
          out.add(
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
                children: [
                  pw.Text(
                    meta,
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    p.title,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    p.prompt,
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                  ),
                  if (p.chart != null || _hasJsxFigure(p)) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '(그래프·도형은 앱·웹 화면에서 확인하세요.)',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                  if (p.isMultipleChoice) ...[
                    pw.SizedBox(height: 6),
                    for (final c in p.choices)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(
                          '${c.id}. ${c.label}',
                          style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        }

        out.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              '인쇄·공유 메뉴에서 PDF로 저장할 수 있습니다.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
        );

        return out;
      },
    ),
  );

  return doc.save();
}

Future<void> openSimilarProblemsPdf(GeneratedProblemSet set) async {
  await Printing.layoutPdf(
    onLayout: (format) => buildSimilarProblemsPdf(set, format),
    name: '유사문제.pdf',
  );
}
