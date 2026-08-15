import 'package:flutter/widgets.dart';

class PinHtmlOverlay extends StatelessWidget {
  const PinHtmlOverlay({
    super.key,
    required this.screen,
    required this.onAction,
  });

  final String screen;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
