import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';

void main() {
  final theme = buildAppTheme();

  test('outlined buttons are white with a #EFEFF1 hairline', () {
    final style = theme.outlinedButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), Colors.white);
    final side = style.side!.resolve({})!;
    expect(side.color, AppColors.border);
    expect(side.width, 1);
    // 그대로 두는 값: 글자색, 높이, 모양.
    expect(style.foregroundColor!.resolve({}), AppColors.text);
    expect(style.minimumSize!.resolve({}), const Size.fromHeight(52));
    expect(style.shape!.resolve({}), isA<StadiumBorder>());
  });

  test('input fields are white with a #EFEFF1 border and a blue focus ring', () {
    final input = theme.inputDecorationTheme;
    expect(input.filled, isTrue);
    expect(input.fillColor, Colors.white);
    final normal = input.border as OutlineInputBorder;
    expect(normal.borderSide.color, AppColors.border);
    expect(normal.borderSide.width, 1);
    final enabled = input.enabledBorder as OutlineInputBorder;
    expect(enabled.borderSide.color, AppColors.border);
    expect(enabled.borderSide.width, 1);
    final focused = input.focusedBorder as OutlineInputBorder;
    expect(focused.borderSide.color, AppColors.primary);
    expect(focused.borderSide.width, 1.5);
    // 모서리는 그대로 알약.
    expect(enabled.borderRadius, BorderRadius.circular(AppRadii.pill));
  });

  test('chips are white with a #EFEFF1 hairline', () {
    final chip = theme.chipTheme;
    expect(chip.backgroundColor, Colors.white);
    expect(chip.side!.color, AppColors.border);
    expect(chip.side!.width, 1);
    expect(chip.selectedColor, AppColors.primarySoft);
  });

  test('switch is visible on a white card both off and on', () {
    final sw = theme.switchTheme;
    const off = <WidgetState>{};
    const on = {WidgetState.selected};

    // 꺼짐: 회색 트랙 위 진한 회색 손잡이, 트랙 가장자리도 같은 회색.
    expect(sw.trackColor!.resolve(off), AppColors.borderStrong);
    expect(sw.thumbColor!.resolve(off), AppColors.controlOff);
    expect(sw.trackOutlineColor!.resolve(off), AppColors.controlOff);

    // 켜짐: 기존 파랑은 그대로, 테두리만 투명.
    expect(sw.trackColor!.resolve(on), AppColors.primarySoft);
    expect(sw.thumbColor!.resolve(on), AppColors.primary);
    expect(sw.trackOutlineColor!.resolve(on), Colors.transparent);
  });

  test('off switch meets the 3:1 non-text contrast on a white card', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    final sw = theme.switchTheme;
    const off = <WidgetState>{};
    final thumb = sw.thumbColor!.resolve(off)!;
    final track = sw.trackColor!.resolve(off)!;
    final outline = sw.trackOutlineColor!.resolve(off)!;

    // 손잡이는 트랙 위에서, 트랙 테두리는 흰 카드 위에서 보여야 한다.
    expect(contrast(thumb, track), greaterThanOrEqualTo(3));
    expect(contrast(outline, Colors.white), greaterThanOrEqualTo(3));
    // 예전 값(#999 손잡이, #E0E0E4 테두리)은 둘 다 모자랐다.
    expect(contrast(AppColors.textMuted, track), lessThan(3));
    expect(contrast(AppColors.borderStrong, Colors.white), lessThan(3));
  });
}
