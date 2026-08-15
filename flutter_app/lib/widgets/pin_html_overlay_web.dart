// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/widgets.dart';

class PinHtmlOverlay extends StatefulWidget {
  const PinHtmlOverlay({
    super.key,
    required this.screen,
    required this.onAction,
  });

  final String screen;
  final ValueChanged<String> onAction;

  @override
  State<PinHtmlOverlay> createState() => _PinHtmlOverlayState();
}

class _PinHtmlOverlayState extends State<PinHtmlOverlay> {
  html.IFrameElement? _frame;
  html.EventListener? _listener;

  @override
  void initState() {
    super.initState();
    _mount();
  }

  @override
  void didUpdateWidget(covariant PinHtmlOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screen != widget.screen) {
      _frame?.src = _srcFor(widget.screen);
    }
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  String _srcFor(String screen) {
    final name = switch (screen) {
      'practice' => 'practice',
      'analysis' => 'analysis',
      'home' => 'home',
      _ => 'login',
    };
    return 'pin/$name.html?v=4';
  }

  void _onMessage(html.Event raw) {
    final event = raw as html.MessageEvent;
    final data = event.data;
    Map<String, dynamic>? payload;
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        payload = decoded.cast<String, dynamic>();
      }
    } else if (data is Map) {
      payload = data.map((key, value) => MapEntry('$key', value));
    }
    if (payload == null || payload['source'] != 'wooyeol-pin') return;
    final action = payload['action']?.toString();
    if (action == null || action.isEmpty) return;
    widget.onAction(action);
  }

  void _mount() {
    if (html.document.getElementById('wooyeol-pin') != null) {
      return;
    }
    final frame = html.IFrameElement()
      ..src = _srcFor(widget.screen)
      ..style.position = 'fixed'
      ..style.left = '0'
      ..style.top = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.zIndex = '2147483647'
      ..allowFullscreen = true;
    _listener = _onMessage;
    html.window.addEventListener('message', _listener);
    html.document.body?.append(frame);
    _frame = frame;
  }

  void _teardown() {
    if (_listener != null) {
      html.window.removeEventListener('message', _listener);
      _listener = null;
    }
    _frame?.remove();
    _frame = null;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
