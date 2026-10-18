import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 화면을 그대로 그려 픽셀을 읽는 검사용 도구.
///
/// `MaterialApp`을 [RepaintBoundary](key: [key])로 감싸 두고 [capture]를 부르면
/// 실제로 칠해진 RGBA 값을 얻는다. 투명하게 남은 곳은 알파가 0이다.
class PixelProbe {
  PixelProbe._(this.width, this.height, this._rgba);

  final int width;
  final int height;
  final ByteData _rgba;

  static Future<PixelProbe> capture(WidgetTester tester, GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage();
      final data = (await image.toByteData())!;
      final probe = PixelProbe._(image.width, image.height, data);
      image.dispose();
      return probe;
    }))!;
  }

  /// (x, y)의 색. 알파가 0이면 아무것도 칠해지지 않은 곳이다.
  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      _rgba.getUint8(i + 3),
      _rgba.getUint8(i),
      _rgba.getUint8(i + 1),
      _rgba.getUint8(i + 2),
    );
  }
}

/// WCAG 2.x 상대 휘도 대비 (1:1 ~ 21:1).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 반투명 [top]을 [bottom] 위에 합성한 색.
Color composite(Color top, Color bottom) {
  final a = top.a;
  return Color.from(
    alpha: 1,
    red: top.r * a + bottom.r * (1 - a),
    green: top.g * a + bottom.g * (1 - a),
    blue: top.b * a + bottom.b * (1 - a),
  );
}

/// 6자리 16진수 문자열 (진단 출력용).
String hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
