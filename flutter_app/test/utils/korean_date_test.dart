import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/utils/korean_date.dart';

void main() {
  test('formats month, day, and weekday', () {
    expect(formatKoreanDate(DateTime(2026, 10, 17)), '10월 17일 토요일');
    expect(formatKoreanDate(DateTime(2026, 10, 19)), '10월 19일 월요일');
  });

  test('covers every weekday, including Sunday', () {
    expect(formatKoreanDate(DateTime(2026, 10, 18)), '10월 18일 일요일');
    expect(formatKoreanDate(DateTime(2026, 1, 1)), '1월 1일 목요일');
  });
}
