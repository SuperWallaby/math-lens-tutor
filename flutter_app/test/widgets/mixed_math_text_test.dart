import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/mixed_math_text.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: buildAppTheme(), home: Scaffold(body: child));

/// 본문 글자를 그리는 [RichText]의 맨 위 스팬 스타일.
TextStyle _rootStyle(WidgetTester tester) {
  final rich = tester.widget<RichText>(
    find
        .descendant(
          of: find.byType(MixedMathText),
          matching: find.byType(RichText),
        )
        .first,
  );
  return (rich.text as TextSpan).style!;
}

void main() {
  testWidgets('a color-less style falls back to the app text color and font', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const MixedMathText(
          '식 \$x^2 + 1\$ 의 값은?',
          style: TextStyle(fontSize: 15),
        ),
      ),
    );

    final style = _rootStyle(tester);
    expect(style.color, AppColors.text);
    expect(style.fontFamily, AppFonts.family);
    expect(style.fontSize, 15);
  });

  testWidgets('a caller color and font still win', (tester) async {
    await tester.pumpWidget(
      _app(
        const MixedMathText(
          '풀이',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSub,
            fontFamily: 'Georgia',
          ),
        ),
      ),
    );

    final style = _rootStyle(tester);
    expect(style.color, AppColors.textSub);
    expect(style.fontFamily, 'Georgia');
  });

  testWidgets('same text with a different font is not served from the cache', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const MixedMathText('같은 글', style: TextStyle(fontSize: 15))),
    );
    expect(_rootStyle(tester).fontFamily, AppFonts.family);

    await tester.pumpWidget(
      _app(
        const MixedMathText(
          '같은 글',
          style: TextStyle(fontSize: 15, fontFamily: 'Georgia'),
        ),
      ),
    );
    expect(_rootStyle(tester).fontFamily, 'Georgia');
  });
}
