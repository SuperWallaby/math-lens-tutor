import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 학생 고유번호 `WY-XXXXXX` (6자, I/O/0/1 제외)
final RegExp studentCodePattern = RegExp(
  r'^WY-[A-HJ-NP-Z2-9]{6}$',
  caseSensitive: false,
);

final RegExp _studentCodeInTextPattern = RegExp(
  r'WY-[A-HJ-NP-Z2-9]{6}',
  caseSensitive: false,
);

bool isCompleteStudentCode(String raw) {
  return studentCodePattern.hasMatch(raw.trim().toUpperCase());
}

/// 붙여넣기·공유 메시지 등에서 `WY-XXXXXX` 추출.
String? parseStudentCodeFromText(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  final embedded = _studentCodeInTextPattern.firstMatch(raw.trim());
  if (embedded != null) {
    return embedded.group(0)!.toUpperCase();
  }

  var chars = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (chars.startsWith('WY')) {
    chars = chars.substring(2);
  } else if (chars.startsWith('W')) {
    chars = chars.substring(1);
  }
  if (chars.startsWith('Y')) {
    chars = chars.substring(1);
  }
  chars = chars.replaceAll(RegExp(r'[^A-HJ-NP-Z2-9]'), '');
  if (chars.isEmpty) return null;

  final limited = chars.length > 6 ? chars.substring(0, 6) : chars;
  return 'WY-$limited';
}

Future<String?> readStudentCodeFromClipboard() async {
  final data = await Clipboard.getData('text/plain');
  return parseStudentCodeFromText(data?.text);
}

Future<bool> pasteStudentCodeInto(TextEditingController controller) async {
  final data = await Clipboard.getData('text/plain');
  final text = data?.text?.trim();
  if (text == null || text.isEmpty) return false;
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  return true;
}

Future<void> copyStudentCodeToClipboard(String code) async {
  await Clipboard.setData(ClipboardData(text: code.trim().toUpperCase()));
}
