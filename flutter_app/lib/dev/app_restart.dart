import 'package:flutter/material.dart';

/// 디버그용 앱 트리 재시작 (hot restart 대용).
class AppRestart extends StatefulWidget {
  const AppRestart({super.key, required this.child});

  final Widget child;

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRestartState>()?.restart();
  }

  @override
  State<AppRestart> createState() => _AppRestartState();
}

class _AppRestartState extends State<AppRestart> {
  Key _key = UniqueKey();

  void restart() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}
