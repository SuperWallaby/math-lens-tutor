import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/layout/tablet_layout.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:math_lens_tutor/widgets/page_stage.dart';

Widget _frame({
  required int rows,
  double topInset = 0,
  double bottomInset = 0,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
        ),
        child: Scaffold(
          body: StageFrame(
            child: StageListView(
              stage: const PageStage.tab(title: '훈련'),
              children: [
                for (var i = 0; i < rows; i++)
                  SizedBox(key: Key('row-$i'), height: 80),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'frame shows the status-bar band after scrolling; frame region is dark',
    (t) async {
      await t.pumpWidget(_frame(rows: 40, topInset: 47));
      expect(
        t.widget<GlassStatusBarBand>(find.byType(GlassStatusBarBand)).visible,
        isFalse,
      );
      await t.drag(find.byType(ListView), const Offset(0, -200));
      await t.pumpAndSettle();
      expect(
        t.widget<GlassStatusBarBand>(find.byType(GlassStatusBarBand)).visible,
        isTrue,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is AnnotatedRegion<SystemUiOverlayStyle> &&
              w.value == SystemUiOverlayStyle.dark,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('tablet: stage is full width, body is capped and centered', (
    t,
  ) async {
    t.view.physicalSize = const Size(2048, 1536);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(_frame(rows: 3));
    expect(t.getSize(find.byType(PageStage)).width, 1024);
    final row = t.getRect(find.byKey(const Key('row-0')));
    expect(
      row.width,
      lessThanOrEqualTo(
        TabletLayout.maxContentWidth(t.element(find.byType(ListView))),
      ),
    );
    expect((row.center.dx - 512).abs(), lessThan(1));
  });

  testWidgets('last row scrolls above a floating tab bar', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    // extendBody 탭바가 body에 넘기는 아래 여백(126 = 30 + 72 + 24)을 흉내 낸다.
    await t.pumpWidget(_frame(rows: 30, bottomInset: 126));
    final position = t.state<ScrollableState>(find.byType(Scrollable)).position;
    // 지연 빌드라 끝 길이가 늘어날 수 있어, 멈출 때까지 끝으로 간다.
    for (var i = 0; i < 5; i++) {
      position.jumpTo(position.maxScrollExtent);
      await t.pump();
    }
    expect(
      t.getRect(find.byKey(const Key('row-29'))).bottom,
      lessThanOrEqualTo(844 - 126),
    );
  });
}
