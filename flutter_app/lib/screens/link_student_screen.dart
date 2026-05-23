import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../services/api_client.dart';

class LinkStudentScreen extends StatefulWidget {
  const LinkStudentScreen({
    super.key,
    required this.apiClient,
    this.skippable = false,
  });

  final ApiClient apiClient;
  final bool skippable;

  @override
  State<LinkStudentScreen> createState() => _LinkStudentScreenState();
}

class _LinkStudentScreenState extends State<LinkStudentScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '학생 고유번호를 입력해 주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.apiClient.linkStudent(code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('학생 연결')),
      body: SafeArea(
        child: TabletBody(
          child: Padding(
            padding: TabletLayout.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학생 고유번호 입력',
                  style: TextStyle(
                    fontSize: TabletLayout.titleSection(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '학생 계정에 표시된 WY-XXXXXX 코드를 입력하면 활동과 수준을 확인할 수 있습니다.',
                  style: TextStyle(color: Color(0xFFCBD5E1), height: 1.5),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'WY-7K3M9P',
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _link,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('학생 연결하기'),
                ),
                if (widget.skippable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('나중에 연결하기'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
