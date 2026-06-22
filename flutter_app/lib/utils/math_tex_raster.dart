import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';

final _rasterCache = <String, Uint8List>{};

Future<void> _waitFrames([int count = 2]) async {
  for (var i = 0; i < count; i++) {
    await WidgetsBinding.instance.endOfFrame;
  }
}

Future<Uint8List?> _capturePng(GlobalKey key, {double pixelRatio = 2.5}) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// LaTeX 수식을 PNG로 rasterize (PDF·인쇄용)
Future<Uint8List?> rasterizeTexToPng(
  OverlayState overlay,
  String latex, {
  required double fontSize,
  bool display = false,
}) async {
  final trimmed = latex.trim();
  if (trimmed.isEmpty) return null;

  final cacheKey = '${display ? 'd' : 'i'}|$fontSize|$trimmed';
  final cached = _rasterCache[cacheKey];
  if (cached != null) return cached;

  final repaintKey = GlobalKey();
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: -10000,
      child: Material(
        color: Colors.white,
        child: RepaintBoundary(
          key: repaintKey,
          child: Math.tex(
            trimmed,
            mathStyle: display ? MathStyle.display : MathStyle.text,
            textStyle: TextStyle(
              fontSize: fontSize,
              color: Colors.black,
            ),
            onErrorFallback: (error) => Text(
              trimmed,
              style: TextStyle(fontSize: fontSize, color: Colors.black),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  await _waitFrames();
  final png = await _capturePng(repaintKey);
  entry.remove();
  if (png != null) {
    _rasterCache[cacheKey] = png;
  }
  return png;
}
