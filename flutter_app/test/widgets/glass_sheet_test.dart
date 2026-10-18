import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/glass.dart';

void main() {
  testWidgets('glass sheet uses the clear preset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGlassSheet<void>(
              context: context,
              builder: (_) => const Text('시트 내용'),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('시트 내용'), findsOneWidget);
    expect(
      tester
          .widget<GlassSurface>(
            find.ancestor(
              of: find.text('시트 내용'),
              matching: find.byType(GlassSurface),
            ),
          )
          .preset,
      GlassPreset.clear,
    );
  });

  testWidgets('glass dialog is one clear glass plate', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassDialog(title: Text('삭제할까요?'), content: Text('되돌릴 수 없어요.')),
      ),
    );
    expect(find.text('삭제할까요?'), findsOneWidget);
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(
      tester.widget<GlassSurface>(find.byType(GlassSurface)).preset,
      GlassPreset.clear,
    );
  });

  testWidgets('glass sheet has 26 top corners and a see-through sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGlassSheet<void>(
              context: context,
              builder: (_) => const SizedBox(height: 120, child: Text('시트 내용')),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    final surface = tester.widget<GlassSurface>(
      find.ancestor(of: find.text('시트 내용'), matching: find.byType(GlassSurface)),
    );
    expect(
      surface.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(26)),
    );
    // 시트 자체의 Material 은 투명이라 유리 뒤가 비친다.
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, Colors.transparent);
    expect(sheet.elevation, 0);
  });

  testWidgets('glass sheet is capped at 9/16 unless scroll controlled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Future<double> sheetHeight({required bool scrollControlled}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGlassSheet<void>(
                context: context,
                isScrollControlled: scrollControlled,
                builder: (_) => const SizedBox(height: 800, child: Text('긴 시트')),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final height = tester.getSize(find.byType(GlassSurface)).height;
      Navigator.of(tester.element(find.text('긴 시트'))).pop();
      await tester.pumpAndSettle();
      return height;
    }

    expect(await sheetHeight(scrollControlled: false), lessThanOrEqualTo(844 * 9 / 16));
    expect(await sheetHeight(scrollControlled: true), greaterThan(844 * 9 / 16));
  });

  testWidgets('glass sheet pops with a value', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showGlassSheet<bool>(
                context: context,
                builder: (ctx) => TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('저장'),
                ),
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('저장'), findsNothing);
  });

  testWidgets('glass dialog is a clear 26 plate that keeps title, content and actions', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (ctx) => GlassDialog(
                  title: const Text('계정 탈퇴'),
                  content: const Text('정말 탈퇴하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('탈퇴'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('계정 탈퇴'), findsOneWidget);
    expect(find.text('정말 탈퇴하시겠습니까?'), findsOneWidget);
    final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
    expect(surface.preset, GlassPreset.clear);
    expect(surface.borderRadius, BorderRadius.circular(26));
    // 판 폭은 안쪽 글자에 맞추되 280 아래로는 줄지 않고, 화면 안에 들어온다.
    final width = tester.getSize(find.byType(GlassSurface)).width;
    expect(width, greaterThanOrEqualTo(280));
    expect(width, lessThanOrEqualTo(390));

    // 두 버튼은 한 줄에 나란히 서고, 판 안에 들어온다.
    final cancel = tester.getRect(find.widgetWithText(TextButton, '취소'));
    final confirm = tester.getRect(find.widgetWithText(FilledButton, '탈퇴'));
    expect(cancel.right, lessThan(confirm.left));
    expect(cancel.center.dy, closeTo(confirm.center.dy, 0.5));
    expect(confirm.right, lessThanOrEqualTo(tester.getRect(find.byType(GlassSurface)).right));

    await tester.tap(find.text('탈퇴'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(GlassDialog), findsNothing);
  });

  testWidgets('glass dialog works without actions or content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlassDialog(title: Text('알림'))),
    );
    expect(find.text('알림'), findsOneWidget);
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass dialog title and content use the app font', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const GlassDialog(
          title: Text('계정 탈퇴'),
          content: Text('정말 탈퇴하시겠습니까?'),
        ),
      ),
    );

    // Text 가 실제로 그리는 스타일(상속된 DefaultTextStyle 와 합친 값)을 읽는다.
    String? family(String text) =>
        tester.renderObject<RenderParagraph>(find.text(text)).text.style?.fontFamily;
    expect(family('계정 탈퇴'), AppFonts.family);
    expect(family('정말 탈퇴하시겠습니까?'), AppFonts.family);
    // 크기와 굵기는 팝업 값 그대로다.
    final title = tester.renderObject<RenderParagraph>(find.text('계정 탈퇴')).text.style!;
    expect(title.fontSize, 20);
    expect(title.fontWeight, FontWeight.w800);
  });

  group('assistive tech', () {
    Widget opener(void Function(BuildContext) open) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    testWidgets('glass dialog is its own named route, like AlertDialog', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        opener(
          (context) => showDialog<void>(
            context: context,
            builder: (_) => const GlassDialog(
              title: Text('계정을 삭제할까요?'),
              content: Text('되돌릴 수 없어요.'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      final route = find.descendant(
        of: find.byType(GlassDialog),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.namesRoute == true,
        ),
      );
      expect(route, findsOneWidget);
      expect(
        tester.getSemantics(route),
        containsSemantics(label: '알림', namesRoute: true, scopesRoute: true),
      );
      // 제목과 내용은 따로 읽힌다.
      expect(find.semantics.byLabel('계정을 삭제할까요?'), findsOne);
      expect(find.semantics.byLabel('되돌릴 수 없어요.'), findsOne);
      semantics.dispose();
    });

    testWidgets('glass sheet handle is a 닫기 button for screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        opener(
          (context) => showGlassSheet<void>(
            context: context,
            builder: (_) => const Text('시트 내용'),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('시트 내용'), findsOneWidget);

      final handle = find.semantics.byLabel('닫기');
      expect(handle, findsOne);
      expect(
        handle.evaluate().single,
        containsSemantics(label: '닫기', isButton: true, hasTapAction: true),
      );
      tester.semantics.tap(handle);
      await tester.pumpAndSettle();
      expect(find.text('시트 내용'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a sheet that draws its own handle has no extra 닫기', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        opener(
          (context) => showGlassSheet<void>(
            context: context,
            showDragHandle: false,
            builder: (_) => const Text('시트 내용'),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('닫기'), findsNothing);
      semantics.dispose();
    });
  });
}
