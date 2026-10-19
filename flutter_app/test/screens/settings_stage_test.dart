import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/settings_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/services/oauth_service.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/page_stage.dart';
import 'package:math_lens_tutor/widgets/student_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _student = AppUser(
  id: 'student-1',
  displayName: '지민',
  profileComplete: true,
  role: AppUserRole.student,
  grade: '중1',
  organizationName: '한빛중학교',
  studentCode: 'WY-123456',
);

const _parent = AppUser(
  id: 'parent-1',
  displayName: '민준 어머니',
  profileComplete: true,
  role: AppUserRole.parent,
);

Future<AuthSession> _session(
  WidgetTester tester, {
  required AppUser user,
  bool guest = false,
  List<LinkedStudent> children = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    if (!guest) 'auth_token': 'token',
    if (guest) 'auth_guest_mode': true,
    'auth_user': jsonEncode(user.toJson()),
    if (children.isNotEmpty)
      'linked_students': jsonEncode([for (final s in children) s.toJson()]),
  });
  resetAppPrefsCache();
  final session = AuthSession();
  await tester.runAsync(session.load);
  return session;
}

Widget _settings(AuthSession session) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      extendBody: true,
      body: SettingsScreen(
        apiClient: ApiClient(authSession: session),
        oauthService: OAuthService(),
      ),
    ),
  );
}

Finder _onStage(Finder f) =>
    find.descendant(of: find.byType(PageStage), matching: f);

void main() {
  testWidgets('student: profile, edit button and student code on the stage', (
    tester,
  ) async {
    final session = await _session(tester, user: _student);
    await tester.pumpWidget(_settings(session));
    await tester.pumpAndSettle();

    expect(_onStage(find.text('설정')), findsOneWidget);
    expect(_onStage(find.text('지민')), findsOneWidget);
    expect(_onStage(find.text('중1 · 한빛중학교')), findsOneWidget);
    expect(_onStage(find.text('학생 코드')), findsOneWidget);
    expect(_onStage(find.text('WY-123456')), findsOneWidget);

    final copy = find.ancestor(
      of: _onStage(find.text('복사')),
      matching: find.byType(FilledButton),
    );
    expect(copy, findsOneWidget);
    expect(
      tester.widget<FilledButton>(copy).style!.backgroundColor!.resolve({}),
      Colors.white,
    );
    expect(
      find.ancestor(
        of: _onStage(find.text('기본 정보 수정')),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );

    // 역할 칩은 무대 아래 첫 줄.
    expect(find.text('학생'), findsOneWidget);
    expect(_onStage(find.text('학생')), findsNothing);
    expect(find.text('내 학생 고유번호'), findsNothing);
  });

  testWidgets('student: copy shows the copied snackbar', (tester) async {
    final session = await _session(tester, user: _student);
    await tester.pumpWidget(_settings(session));
    await tester.pumpAndSettle();

    // 클립보드 채널에 응답해 복사가 끝나게 한다.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(_onStage(find.text('복사')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('학생 고유번호가 복사되었습니다.'), findsOneWidget);
  });

  testWidgets('guest: guest notice below the stage, no edit button', (
    tester,
  ) async {
    final session = await _session(tester, user: _student, guest: true);
    await tester.pumpWidget(_settings(session));
    await tester.pumpAndSettle();

    expect(find.text('로그인하지 않은 게스트 모드입니다.'), findsOneWidget);
    expect(_onStage(find.text('로그인하지 않은 게스트 모드입니다.')), findsNothing);
    expect(find.text('기본 정보 수정'), findsNothing);
  });

  testWidgets('parent with two children: picker on the stage, no student code', (
    tester,
  ) async {
    final session = await _session(
      tester,
      user: _parent,
      children: const [
        LinkedStudent(id: 's1', displayName: '지민', studentCode: '123456'),
        LinkedStudent(id: 's2', displayName: '서연', studentCode: '654321'),
      ],
    );
    await tester.pumpWidget(_settings(session));
    await tester.pumpAndSettle();

    expect(_onStage(find.byType(StudentPicker)), findsOneWidget);
    expect(
      tester.widget<StudentPicker>(find.byType(StudentPicker)).onStage,
      isTrue,
    );
    expect(find.text('학생 코드'), findsNothing);
  });

  testWidgets('long name and school fit 320 wide at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final session = await _session(
      tester,
      user: const AppUser(
        id: 'student-1',
        displayName: '김가나다라마바사아자차카타파하가나다라',
        profileComplete: true,
        role: AppUserRole.student,
        grade: '중1',
        organizationName: '서울특별시립한빛국제중학교부설영재교육원',
        studentCode: 'WY-123456',
      ),
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 800),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _settings(session),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
