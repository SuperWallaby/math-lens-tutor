import 'dart:math';

const oauthDisplayNamePlaceholders = {
  '카카오 사용자',
  'Google 사용자',
  'Apple 사용자',
  '게스트',
};

const _adjectives = [
  '열정적인',
  '꾸준한',
  '호기심 많은',
  '도전적인',
  '집중하는',
  '밝은',
  '성실한',
  '똑똑한',
];

const _nouns = [
  '수학자',
  '문제풀이왕',
  '탐구자',
  '계산사',
  '퍼즐러',
];

bool needsDisplayNamePrompt(String? displayName) {
  final trimmed = displayName?.trim() ?? '';
  if (trimmed.isEmpty) return true;
  return oauthDisplayNamePlaceholders.contains(trimmed);
}

String generateDefaultDisplayName({Random? random}) {
  final r = random ?? Random();
  final adj = _adjectives[r.nextInt(_adjectives.length)];
  final noun = _nouns[r.nextInt(_nouns.length)];
  final num = r.nextInt(99) + 1;
  return '$adj $noun${num.toString().padLeft(2, '0')}';
}
