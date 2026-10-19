import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/theme/app_icons.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:math_lens_tutor/widgets/page_stage.dart';

Widget _host(Widget child, {double topInset = 0, double textScale = 1}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(top: topInset),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('tab stage: title, subtitle, blue background, light status bar', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        const PageStage.tab(title: '훈련', subtitle: '막힌 개념만 모아서 다시 풀어봐요'),
        topInset: 47,
      ),
    );
    final title = t.widget<Text>(find.text('훈련'));
    expect(title.style!.fontSize, 24);
    expect(title.style!.fontWeight, FontWeight.w700);
    expect(title.style!.color, Colors.white);
    expect(find.text('막힌 개념만 모아서 다시 풀어봐요'), findsOneWidget);
    expect(t.getTopLeft(find.text('훈련')).dy, greaterThanOrEqualTo(47 + 14));
    final deco =
        t
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(StageBackground),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(deco.gradient, AppGradients.stage);
    expect(
      deco.borderRadius,
      const BorderRadius.vertical(bottom: Radius.circular(32)),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is AnnotatedRegion<SystemUiOverlayStyle> &&
            w.value.statusBarIconBrightness == Brightness.light &&
            // 안드로이드 아래 내비게이션 바는 건드리지 않는다.
            w.value.systemNavigationBarColor == null &&
            w.value.systemNavigationBarIconBrightness == null,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tiles, pills, circle button: glass on blue, selected pill is white',
    (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(
          PageStage.tab(
            title: '내 진도',
            trailing: StageCircleButton(
              icon: AppIcons.chart,
              tooltip: '학습 통계',
              onPressed: () => taps++,
            ),
            children: [
              const StageTileRow(
                tiles: [
                  StageTile(label: '정답률', value: '72%'),
                  StageTile(label: '풀 문제', value: '5개'),
                ],
              ),
              StagePill(label: '중1', selected: true, onTap: () {}),
              StagePill(label: '중2', selected: false, onTap: () {}),
            ],
          ),
        ),
      );
      final tileGlass = find.descendant(
        of: find.byType(StageTile),
        matching: find.byType(GlassSurface),
      );
      expect(tileGlass, findsNWidgets(2));
      expect(t.widget<GlassSurface>(tileGlass.first).preset, GlassPreset.onBlue);
      expect(t.widget<Text>(find.text('중1')).style!.color, AppColors.primaryDark);
      expect(t.widget<Text>(find.text('중2')).style!.color, Colors.white);
      expect(
        find.descendant(
          of: find.widgetWithText(StagePill, '중1'),
          matching: find.byType(GlassSurface),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(StagePill, '중2'),
          matching: find.byType(GlassSurface),
        ),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('학습 통계'));
      expect(taps, 1);
    },
  );

  testWidgets('the circle button can be pressed by a screen reader', (t) async {
    final handle = t.ensureSemantics();
    try {
      var taps = 0;
      await t.pumpWidget(
        _host(
          PageStage.tab(
            title: '내 진도',
            trailing: StageCircleButton(
              icon: AppIcons.chart,
              tooltip: '학습 통계',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('학습 통계')),
        matchesSemantics(
          label: '학습 통계',
          isButton: true,
          hasTapAction: true,
        ),
      );
      t.semantics.tap(find.semantics.byLabel('학습 통계'));
      expect(taps, 1);
      // 보이는 원은 36이지만 누르는 자리는 44.
      expect(t.getSize(find.byType(StageCircleButton)), const Size(44, 44));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('pills report their selected state to screen readers', (t) async {
    final handle = t.ensureSemantics();
    try {
      await t.pumpWidget(
        _host(
          PageStage.tab(
            title: 'x',
            children: [
              StagePill(label: '중1', selected: true, onTap: () {}),
              StagePill(label: '중2', selected: false, onTap: () {}),
            ],
          ),
        ),
      );
      // 학년 알약(GradeBandTabBar)과 같은 읽힘: 선택 상태가 있고, 버튼 표시는 없다.
      expect(
        t.getSemantics(find.text('중1')),
        matchesSemantics(
          label: '중1',
          isSelected: true,
          hasSelectedState: true,
          isButton: false,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        t.getSemantics(find.text('중2')),
        matchesSemantics(
          label: '중2',
          isSelected: false,
          hasSelectedState: true,
          isButton: false,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('long title and subtitle ellipsize at 320 wide with 1.3x text', (
    t,
  ) async {
    t.view.physicalSize = const Size(960, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(
        PageStage.tab(
          title: '김가나다라마바사아자차카타파하님의 아주 긴 제목',
          subtitle: '서울특별시립한빛국제중학교 · 중1 · ' * 4,
          trailing: StageCircleButton(
            icon: AppIcons.chart,
            tooltip: '학습 통계',
            onPressed: () {},
          ),
          children: const [
            StageTileRow(
              tiles: [
                StageTile(label: '끝낸 단원', value: '120 / 135'),
                StageTile(label: '정답률', value: '100%'),
              ],
            ),
          ],
        ),
        textScale: 1.3,
      ),
    );
    expect(t.takeException(), isNull);
  });
}
