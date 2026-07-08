import 'package:flutter/material.dart';

import '../models/app_models.dart';
import 'problem_set_pdf_impl.dart' deferred as pdf_impl;

Future<void> openSimilarProblemsPdf(
  BuildContext context,
  GeneratedProblemSet set,
) async {
  await pdf_impl.loadLibrary();
  if (!context.mounted) return;
  return pdf_impl.openSimilarProblemsPdf(context, set);
}
