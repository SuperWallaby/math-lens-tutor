import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/widgets/glass.dart';

void main() {
  testWidgets('GlassSurface blurs with the preset sigma', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassSurface(child: SizedBox(width: 10, height: 10)),
      ),
    );
    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter;
    expect(filter.toString(), contains('14.0'));
  });

  testWidgets('GlassPrimaryButton shows label, is 52 tall, and taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassPrimaryButton(label: '분석하기', onPressed: () => taps++),
          ),
        ),
      ),
    );
    expect(find.text('분석하기'), findsOneWidget);
    expect(tester.getSize(find.byType(GlassPrimaryButton)).height, 52);
    await tester.tap(find.text('분석하기'));
    expect(taps, 1);
  });

  testWidgets('GlassScrollEdge hides when not visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlassScrollEdge(visible: false, title: '훈련')),
    );
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0);
  });

  testWidgets('GlassCoachBubble shows its text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: GlassCoachBubble(text: '여기를 눌러 숙제 한 장 찍어요')),
      ),
    );
    expect(find.text('여기를 눌러 숙제 한 장 찍어요'), findsOneWidget);
  });
}
