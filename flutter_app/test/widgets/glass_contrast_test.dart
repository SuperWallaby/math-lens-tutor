import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/glass.dart';

import '../support/pixel_probe.dart';

/// 글자 대비 기준 (WCAG AA 일반 글자).
const _aa = 4.5;

final _boundary = GlobalKey();

/// 안개색 한 장 위에 앱 테마로 시트·팝업을 띄우는 앱.
Widget _app(void Function(BuildContext) opener) => RepaintBoundary(
  key: _boundary,
  child: MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => opener(context),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('theme barrier', () {
    final theme = buildAppTheme();

    test('dialogs and sheets sit on a light navy tint, not black54', () {
      const tint = Color(0x2E112850);
      expect(theme.dialogTheme.barrierColor, tint);
      expect(theme.bottomSheetTheme.modalBarrierColor, tint);
      // 기존 팝업 모양은 그대로.
      expect(theme.dialogTheme.backgroundColor, AppColors.surfaceElevated);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
    });
  });

  group('readability on the clear glass panel', () {
    testWidgets('GlassDialog panel keeps textSub and the link color at AA', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          (context) => showDialog<void>(
            context: context,
            builder: (_) => const GlassDialog(
              title: Text('계정을 삭제할까요?'),
              content: Text('되돌릴 수 없어요.'),
              actions: [TextButton(onPressed: null, child: Text('취소'))],
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      final panel = tester.getRect(find.byType(GlassSurface));
      final probe = await PixelProbe.capture(tester, _boundary);
      // 안쪽 여백(24)의 빈 곳: 글자·하이라이트·테두리와 겹치지 않는다.
      final color = probe.at(
        (panel.left + 12).round(),
        (panel.top + 12).round(),
      );
      final onTextSub = contrastRatio(AppColors.textSub, color);
      final onPrimaryDark = contrastRatio(AppColors.primaryDark, color);
      final onText = contrastRatio(AppColors.text, color);
      // ignore: avoid_print
      print(
        'GlassDialog panel ${hex(color)}: textSub ${onTextSub.toStringAsFixed(2)}:1, '
        'primaryDark ${onPrimaryDark.toStringAsFixed(2)}:1, '
        'text ${onText.toStringAsFixed(2)}:1',
      );

      expect(onTextSub, greaterThanOrEqualTo(_aa), reason: hex(color));
      expect(onPrimaryDark, greaterThanOrEqualTo(_aa), reason: hex(color));
      expect(onText, greaterThanOrEqualTo(_aa), reason: hex(color));

      // 팝업 안의 글자 버튼은 진한 파랑(primaryDark)으로 칠해진다.
      final buttonTheme = TextButtonTheme.of(tester.element(find.text('취소')));
      expect(
        buttonTheme.style?.foregroundColor?.resolve(const {}),
        AppColors.primaryDark,
      );
    });

    testWidgets('glass sheet panel keeps textSub at AA', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          (context) => showGlassSheet<void>(
            context: context,
            builder: (_) => const SizedBox(height: 160),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      final panel = tester.getRect(find.byType(GlassSurface));
      final probe = await PixelProbe.capture(tester, _boundary);
      final color = probe.at(
        (panel.left + 40).round(),
        (panel.top + 100).round(),
      );
      final onTextSub = contrastRatio(AppColors.textSub, color);
      // ignore: avoid_print
      print(
        'glass sheet panel ${hex(color)}: textSub ${onTextSub.toStringAsFixed(2)}:1',
      );
      expect(onTextSub, greaterThanOrEqualTo(_aa), reason: hex(color));
    });
  });
}
