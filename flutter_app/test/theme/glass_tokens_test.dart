import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';

void main() {
  test('glass presets match the spec', () {
    final clear = GlassSpec.of(GlassPreset.clear);
    expect(clear.fill, const Color(0x4DFFFFFF)); // 흰색 30%
    expect(clear.blur, 14);
    expect(clear.rim, const Color(0xA8FFFFFF)); // 흰색 66%
    expect(clear.topHighlight, isTrue);

    final onBlue = GlassSpec.of(GlassPreset.onBlue);
    expect(onBlue.fill, const Color(0x24FFFFFF)); // 흰색 14%
    expect(onBlue.blur, 16);
    expect(onBlue.rim, const Color(0x61FFFFFF)); // 흰색 38%

    final prominent = GlassSpec.of(GlassPreset.prominent);
    expect(prominent.fill, const Color(0xE02A72E5)); // #2A72E5 88%
    expect(prominent.blur, 10);
    expect(prominent.rim, const Color(0x47FFFFFF)); // 흰색 28%
    expect(prominent.topHighlight, isTrue);
  });

  test('stage gradient runs sky to cobalt', () {
    expect(AppGradients.stage.colors, const [
      Color(0xFF5EB7EB), Color(0xFF2A72E5), Color(0xFF1E46AA),
    ]);
  });

  test('soft and white button styles', () {
    final soft = AppButtonStyles.soft();
    expect(soft.backgroundColor!.resolve({}), AppColors.primarySoft);
    expect(soft.foregroundColor!.resolve({}), AppColors.primaryDark);
    final white = AppButtonStyles.white();
    expect(white.backgroundColor!.resolve({}), Colors.white);
    expect(white.foregroundColor!.resolve({}), AppColors.primary);
  });
}
