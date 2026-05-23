import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import 'link_student_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _missionAlerts = true;
  bool _weeklyReport = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _missionAlerts = prefs.getBool('notify_mission') ?? true;
      _weeklyReport = prefs.getBool('notify_weekly') ?? true;
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _copyStudentCode() async {
    final code = widget.apiClient.authSession.user?.studentCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('학생 고유번호가 복사되었습니다.')),
    );
  }

  Future<void> _logout() async {
    await widget.apiClient.authSession.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.authSession.user;

    return ListenableBuilder(
      listenable: widget.apiClient.authSession,
      builder: (context, _) {
        return ListView(
          padding: TabletLayout.pagePadding(context),
          children: [
            Text(
              '설정',
              style: TextStyle(
                fontSize: TabletLayout.titleSection(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.role?.label ?? '역할 미설정',
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  if (user?.grade != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '학년: ${user!.grade}',
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ],
                  if (user?.organizationName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user!.organizationName!,
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
            ),
            if (user?.isStudent == true && user?.studentCode != null) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '내 학생 고유번호',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user!.studentCode!,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _copyStudentCode,
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
            ],
            if (user?.isGuardian ?? false) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LinkStudentScreen(apiClient: widget.apiClient),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.link_rounded),
                label: const Text('학생 연결 관리'),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              '알림',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('오늘의 미션 알림'),
                    subtitle: const Text(
                      '남은 유사문제가 있을 때 알려드려요',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    value: _missionAlerts,
                    onChanged: (value) {
                      setState(() => _missionAlerts = value);
                      _setPref('notify_mission', value);
                    },
                  ),
                  const Divider(color: Color(0xFF1E293B)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('주간 보고서'),
                    subtitle: const Text(
                      '매주 학습 요약을 받아보세요',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    value: _weeklyReport,
                    onChanged: (value) {
                      setState(() => _weeklyReport = value);
                      _setPref('notify_weekly', value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }
}
