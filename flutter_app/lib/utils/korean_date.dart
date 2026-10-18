const List<String> _koreanWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 「10월 17일 토요일」
String formatKoreanDate(DateTime date) {
  final weekday = _koreanWeekdays[date.weekday - 1];
  return '${date.month}월 ${date.day}일 $weekday요일';
}
