import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';
import '../utils/problem_answer_format.dart';

class ProblemAnswerInput extends StatefulWidget {
  const ProblemAnswerInput({
    super.key,
    required this.format,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ProblemAnswerFormat format;
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<ProblemAnswerInput> createState() => _ProblemAnswerInputState();
}

class _ProblemAnswerInputState extends State<ProblemAnswerInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant ProblemAnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value ?? '';
    if (next != _controller.text) {
      _controller.value = _controller.value.copyWith(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  InputDecoration _decoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.borderStrong, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.borderStrong, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.format == ProblemAnswerFormat.multipleChoice) {
      return const SizedBox.shrink();
    }

    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.text,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: _decoration(hint: answerInputHint(widget.format)),
    );
  }
}
