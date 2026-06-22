import 'package:flutter/foundation.dart';

import '../services/app_prefs.dart';
import 'student_code_format.dart';

const kPendingStudentLinkCodeKey = 'pending_student_link_code';

/// 웹 공유 링크(`/link?code=`) 등에서 코드를 저장해 연결 화면에 pre-fill.
Future<void> captureInitialStudentLinkCode() async {
  if (!kIsWeb) return;

  final raw = Uri.base.queryParameters['code'];
  if (raw == null || raw.trim().isEmpty) return;
  if (!isCompleteStudentCode(raw)) return;

  final prefs = await getAppPrefs();
  await prefs.setString(kPendingStudentLinkCodeKey, raw.trim().toUpperCase());
}

Future<String?> consumePendingStudentLinkCode() async {
  final prefs = await getAppPrefs();
  final code = prefs.getString(kPendingStudentLinkCodeKey);
  if (code == null || code.isEmpty) return null;
  await prefs.remove(kPendingStudentLinkCodeKey);
  return code;
}
