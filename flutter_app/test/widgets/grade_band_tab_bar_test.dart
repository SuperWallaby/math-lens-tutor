import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/learning_profile_widgets.dart';

/// [label] 알약의 바탕 장식.
BoxDecoration _pill(WidgetTester tester, String label) {
  final ink = tester.widget<Ink>(
    find.ancestor(of: find.text(label), matching: find.byType(Ink)),
  );
  return ink.decoration! as BoxDecoration;
}

Color? _textColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color;

void main() {
  testWidgets('selected band is soft blue with dark blue text, not a blue fill',
      (tester) async {
    var picked = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradeBandTabBar(
            selectedIndex: 3,
            onSelected: (i) => picked = i,
          ),
        ),
      ),
    );

    final selected = gradeBandLabels[3];
    expect(_pill(tester, selected).color, AppColors.primarySoft);
    expect(_textColor(tester, selected), AppColors.primaryDark);

    final other = gradeBandLabels[0];
    expect(_pill(tester, other).color, AppColors.surface);
    expect(_textColor(tester, other), AppColors.textSub);

    // 탭 화면 규칙: 본문에 파란 채움(AppColors.primary)이 없다.
    for (final label in gradeBandLabels) {
      expect(_pill(tester, label).color, isNot(AppColors.primary));
    }

    await tester.tap(find.text(other));
    expect(picked, 0);
  });

  testWidgets('screen readers hear which band is selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradeBandTabBar(selectedIndex: 3, onSelected: (_) {}),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text(gradeBandLabels[3])),
      matchesSemantics(
        label: gradeBandLabels[3],
        isSelected: true,
        hasSelectedState: true,
        isButton: false,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });
}
