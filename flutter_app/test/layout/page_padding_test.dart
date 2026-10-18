import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/layout/tablet_layout.dart';

void main() {
  testWidgets('page padding clears the bottom inset', (tester) async {
    late EdgeInsets padding;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: 120),
        ),
        child: Builder(
          builder: (context) {
            padding = TabletLayout.pagePadding(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(padding.bottom, 24 + 120);
  });
}
