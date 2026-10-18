import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/app_card.dart';

BoxDecoration _firstDecoration(WidgetTester tester, Type owner) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(of: find.byType(owner), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  testWidgets('AppCard is a flat white card without blur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppCard(child: Text('카드'))),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    final deco = _firstDecoration(tester, AppCard);
    expect(deco.color, Colors.white);
    expect(deco.border, Border.all(color: AppColors.border));
    expect(deco.borderRadius, BorderRadius.circular(16));
    expect(deco.boxShadow, anyOf(isNull, isEmpty));
    expect(find.text('카드'), findsOneWidget);
  });

  testWidgets('AppChoiceTile highlights when selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppChoiceTile(
          label: const Text('중1'),
          selected: true,
          onTap: () {},
        ),
      ),
    );
    final deco = _firstDecoration(tester, AppChoiceTile);
    expect(deco.color, AppColors.primarySoft);
    expect(deco.border, Border.all(color: AppColors.primary, width: 1.5));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('AppChoiceTile is a plain white tile when not selected and taps',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppChoiceTile(
            label: const Text('중2'),
            selected: false,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    final deco = _firstDecoration(tester, AppChoiceTile);
    expect(deco.color, Colors.white);
    expect(deco.border, Border.all(color: AppColors.border));
    await tester.tap(find.text('중2'));
    expect(taps, 1);
  });

  testWidgets('AppGlyph is a soft primary circle with a primary icon',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AppGlyph(icon: Icons.bolt))),
    );
    expect(tester.getSize(find.byType(AppGlyph)), const Size(44, 44));
    final deco = _firstDecoration(tester, AppGlyph);
    expect(deco.color, AppColors.primarySoft);
    expect(deco.shape, BoxShape.circle);
    final icon = tester.widget<Icon>(find.byIcon(Icons.bolt));
    expect(icon.color, AppColors.primary);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('AppInfoRow shows glyph, title and subtitle on a white card',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppInfoRow(
            icon: Icons.photo_camera_outlined,
            title: '사진 찍기',
            subtitle: '문제를 한 장 찍어요',
          ),
        ),
      ),
    );
    expect(find.text('사진 찍기'), findsOneWidget);
    expect(find.text('문제를 한 장 찍어요'), findsOneWidget);
    expect(find.byType(AppGlyph), findsOneWidget);
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('TagChip is a flat tint pill: 12% fill, own-color text, no rim or shadow',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TagChip('보완', color: AppColors.accent),
              TagChip('작게', color: AppColors.success, compact: true),
            ],
          ),
        ),
      ),
    );
    final chips = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(TagChip),
        matching: find.byType(Container),
      ),
    ).toList();
    expect(chips, hasLength(2));
    final colors = [AppColors.accent, AppColors.success];
    for (var i = 0; i < chips.length; i++) {
      final deco = chips[i].decoration! as BoxDecoration;
      expect(deco.color, colors[i].withValues(alpha: 0.12));
      expect(deco.border, isNull);
      expect(deco.boxShadow, anyOf(isNull, isEmpty));
      expect(deco.borderRadius, BorderRadius.circular(AppRadii.pill));
    }
    expect(tester.widget<Text>(find.text('보완')).style!.color, AppColors.accent);
    expect(tester.widget<Text>(find.text('작게')).style!.color, AppColors.success);
  });
}
