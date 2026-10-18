import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:math_lens_tutor/theme/app_icons.dart';

const _labels = ['홈', '훈련', '성장', '설정'];
const _icons = [
  AppIcons.home,
  AppIcons.pencil,
  AppIcons.book,
  AppIcons.settings,
];

GlassTabBar _tabBar({
  required ValueChanged<int> onSelected,
  required VoidCallback onCamera,
  int? badgeIndex,
  int badgeCount = 0,
}) {
  return GlassTabBar(
    labels: _labels,
    icons: _icons,
    selectedIndex: 0,
    onSelected: onSelected,
    onCenterAction: onCamera,
    badgeIndex: badgeIndex,
    badgeCount: badgeCount,
  );
}

Widget _bar({
  required ValueChanged<int> onSelected,
  required VoidCallback onCamera,
  double scale = 1,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          bottomNavigationBar: _tabBar(
            onSelected: onSelected,
            onCamera: onCamera,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('student bar shows four tabs and a center camera', (
    tester,
  ) async {
    int? selected;
    var camera = 0;
    await tester.pumpWidget(
      _bar(onSelected: (i) => selected = i, onCamera: () => camera++),
    );
    for (final t in ['홈', '훈련', '찍기', '성장', '설정']) {
      expect(find.text(t), findsOneWidget);
    }
    await tester.tap(find.text('찍기'));
    expect(camera, 1);
    await tester.tap(find.text('성장'));
    expect(selected, 2);
    await tester.tap(find.text('설정'));
    expect(selected, 3);
    expect(camera, 1);
  });

  testWidgets('no overflow at 320 wide with 1.3x text', (tester) async {
    // MediaQueryData(size:) does not constrain layout, so shrink the real view.
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _bar(onSelected: (_) {}, onCamera: () {}, scale: 1.3),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(GlassTabBar)).width, 320);
    for (final t in ['홈', '훈련', '찍기', '성장', '설정']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('bar height includes the camera lift and the bottom inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 800),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Scaffold(
            extendBody: true,
            body: Builder(
              builder: (context) => Text(
                '${MediaQuery.paddingOf(context).bottom}',
                textDirection: TextDirection.ltr,
              ),
            ),
            bottomNavigationBar: _tabBar(onSelected: (_) {}, onCamera: () {}),
          ),
        ),
      ),
    );
    // 30 (camera lift) + 72 (pill) + 24 (sits 10 into the 34 home-indicator area)
    expect(tester.getSize(find.byType(GlassTabBar)).height, 30 + 72 + 24);
    // extendBody hands that height to the body as bottom padding.
    expect(find.text('126.0'), findsOneWidget);
  });

  testWidgets('without a home indicator the bar keeps a 12pt gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 800)),
          child: Scaffold(
            bottomNavigationBar: _tabBar(onSelected: (_) {}, onCamera: () {}),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(GlassTabBar)).height, 30 + 72 + 12);
  });

  testWidgets('empty space around the bar lets touches through', (
    tester,
  ) async {
    var bodyTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => bodyTaps++,
            child: const SizedBox.expand(),
          ),
          bottomNavigationBar: _tabBar(onSelected: (_) {}, onCamera: () {}),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(GlassTabBar));
    // Above the pill, left of the raised camera.
    await tester.tapAt(bar.topLeft + const Offset(24, 6));
    expect(bodyTaps, 1);
    // The 16px gap under the pill.
    await tester.tapAt(bar.bottomCenter - const Offset(0, 6));
    expect(bodyTaps, 2);
  });

  testWidgets('badge shows only on the badged tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: _tabBar(
            onSelected: (_) {},
            onCamera: () {},
            badgeIndex: 1,
            badgeCount: 3,
          ),
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('camera is a single labeled button node that taps', (
    tester,
  ) async {
    var camera = 0;
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _bar(onSelected: (_) {}, onCamera: () => camera++),
      );

      final cameraNodes = find.semantics.byLabel('찍기').evaluate().toList();
      expect(cameraNodes, hasLength(1));
      final data = cameraNodes.single.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      // Nothing is nested under it: no second 찍기 stop for screen readers.
      expect(cameraNodes.single.childrenCount, 0);

      // Every button in the bar (4 tabs + camera) carries a label.
      final buttons = <SemanticsNode>[];
      void collect(SemanticsNode node) {
        if (node.getSemanticsData().flagsCollection.isButton) {
          buttons.add(node);
        }
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
      expect(buttons, hasLength(5));
      for (final button in buttons) {
        expect(button.getSemanticsData().label, isNotEmpty);
      }

      tester.semantics.tap(find.semantics.byLabel('찍기'));
      expect(camera, 1);
    } finally {
      handle.dispose();
    }
  });

  test('center action needs an even number of tabs', () {
    expect(
      () => GlassTabBar(
        labels: const ['홈', '훈련', '설정'],
        icons: const [AppIcons.home, AppIcons.pencil, AppIcons.settings],
        selectedIndex: 0,
        onSelected: (_) {},
        onCenterAction: () {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets('selected tab shows the filled icon, others the line icon', (
    tester,
  ) async {
    await tester.pumpWidget(_motionBar(2));
    expect(find.byIcon(AppIcons.growthFill), findsOneWidget);
    expect(find.byIcon(AppIcons.growth), findsNothing);
    expect(find.byIcon(AppIcons.home), findsOneWidget);
    expect(find.byIcon(AppIcons.homeFill), findsNothing);
  });

  testWidgets('the drop slides to the new tab and settles under it', (
    tester,
  ) async {
    await tester.pumpWidget(_motionBar(0));
    final homeX = tester.getCenter(find.text('홈')).dx;
    expect(_dropCenterX(tester), moreOrLessEquals(homeX, epsilon: 1));

    await tester.pumpWidget(_motionBar(2));
    await tester.pump(const Duration(milliseconds: 120));
    final growthX = tester.getCenter(find.text('성장')).dx;
    final midX = _dropCenterX(tester);
    expect(midX, greaterThan(homeX + 1));
    expect(midX, lessThan(growthX - 1));

    await tester.pumpAndSettle();
    expect(_dropCenterX(tester), moreOrLessEquals(growthX, epsilon: 1));
  });

  testWidgets('with reduce motion the drop jumps without sliding', (
    tester,
  ) async {
    await tester.pumpWidget(_motionBar(0, reduceMotion: true));
    await tester.pumpWidget(_motionBar(3, reduceMotion: true));
    await tester.pump();
    final settingsX = tester.getCenter(find.text('설정')).dx;
    expect(_dropCenterX(tester), moreOrLessEquals(settingsX, epsilon: 1));
  });
}

const _selectedIcons = [
  AppIcons.homeFill,
  AppIcons.trainingFill,
  AppIcons.growthFill,
  AppIcons.settingsFill,
];

Widget _motionBar(int selected, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 800),
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(
        bottomNavigationBar: GlassTabBar(
          labels: _labels,
          icons: const [
            AppIcons.home,
            AppIcons.training,
            AppIcons.growth,
            AppIcons.settings,
          ],
          selectedIcons: _selectedIcons,
          selectedIndex: selected,
          onSelected: (_) {},
          onCenterAction: () {},
        ),
      ),
    ),
  );
}

double _dropCenterX(WidgetTester tester) =>
    tester.getCenter(find.byKey(const Key('glass-tab-drop'))).dx;
