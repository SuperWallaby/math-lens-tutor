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

  testWidgets('TagChip is a flat tint pill: 12% fill, no rim or shadow',
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
    expect(
      tester.widget<Text>(find.text('보완')).style!.color,
      tagChipTextColor(AppColors.accent),
    );
    expect(
      tester.widget<Text>(find.text('작게')).style!.color,
      tagChipTextColor(AppColors.success),
    );
  });

  group('TagChip text contrast', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    // 앱에서 TagChip에 넘기는 색 전부 + 기본값.
    const used = {
      'primary': AppColors.primary,
      'accent': AppColors.accent,
      'success': AppColors.success,
      'warning': AppColors.warning,
      'textMuted': AppColors.textMuted,
      'teacher': AppColors.teacher,
    };

    for (final entry in used.entries) {
      test('${entry.key} text is at least 4.5:1 on white and on mist', () {
        final text = tagChipTextColor(entry.value);
        for (final under in [Colors.white, AppColors.background]) {
          final fill = Color.alphaBlend(
            entry.value.withValues(alpha: 0.12),
            under,
          );
          expect(
            contrast(text, fill),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} on $under',
          );
        }
      });
    }

    test('green and orange were about 2:1 with their own color', () {
      for (final c in [AppColors.success, AppColors.accent]) {
        final fill = Color.alphaBlend(c.withValues(alpha: 0.12), Colors.white);
        expect(contrast(c, fill), lessThan(2.2));
      }
    });

    test('darkens at least as much as the old 0.25 mix, never past text', () {
      // 파랑은 0.25만 섞어도 충분해서 거기서 멈춘다.
      expect(
        tagChipTextColor(AppColors.primary),
        Color.lerp(AppColors.primary, AppColors.text, 0.25),
      );
      for (final c in used.values) {
        final l = tagChipTextColor(c).computeLuminance();
        expect(
          l,
          lessThanOrEqualTo(
            Color.lerp(c, AppColors.text, 0.25)!.computeLuminance(),
          ),
        );
        expect(l, greaterThanOrEqualTo(AppColors.text.computeLuminance()));
      }
    });
  });
}
