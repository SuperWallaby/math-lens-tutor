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
}
