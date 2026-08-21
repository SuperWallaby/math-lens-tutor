// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

const _viewType = 'wooyeol-css-glass-v2';

bool _registered = false;
final _nodes = <int, html.DivElement>{};

void _ensureRegistered() {
  if (_registered) return;
  _registered = true;
  ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
    final el = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.boxSizing = 'border-box'
      ..style.pointerEvents = 'none'
      ..style.overflow = 'hidden';
    _style(el, 'clear', 26);
    _nodes[viewId] = el;
    return el;
  });
}

void _style(html.DivElement el, String tone, double radius) {
  // Match iOS folder glass: translucent + heavy saturate blur
  final bg = switch (tone) {
    'blue' => 'rgba(183, 212, 240, 0.30)',
    'sunken' => 'rgba(255, 255, 255, 0.12)',
    _ => 'rgba(255, 255, 255, 0.18)',
  };
  final blur = tone == 'sunken'
      ? 'blur(14px) saturate(160%)'
      : 'blur(28px) saturate(185%)';
  el.style
    ..background = bg
    ..border = '1.15px solid rgba(255, 255, 255, 0.92)'
    ..borderRadius = '${radius}px';
  el.style.setProperty('backdrop-filter', blur);
  el.style.setProperty('-webkit-backdrop-filter', blur);
  el.style.setProperty('background-clip', 'padding-box');
}

/// Real CSS frosted glass. Painted Flutter fills cannot do this alone on web.
Widget? buildCssGlassLayer({
  required String tone,
  required double radius,
}) {
  _ensureRegistered();
  return HtmlElementView(
    viewType: _viewType,
    onPlatformViewCreated: (id) {
      final el = _nodes[id];
      if (el != null) _style(el, tone, radius);
    },
  );
}
