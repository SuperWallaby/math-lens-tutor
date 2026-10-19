import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/theme/app_icons.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:math_lens_tutor/widgets/student_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _parent = AppUser(
  id: 'parent-1',
  displayName: '민준 어머니',
  profileComplete: true,
  role: AppUserRole.parent,
);

Future<AuthSession> _parentWith(
  WidgetTester tester,
  List<LinkedStudent> children,
) async {
  SharedPreferences.setMockInitialValues({
    'auth_token': 'token',
    'auth_user': jsonEncode(_parent.toJson()),
    'linked_students': jsonEncode([for (final s in children) s.toJson()]),
  });
  resetAppPrefsCache();
  final session = AuthSession();
  await tester.runAsync(session.load);
  return session;
}

Widget _picker(AuthSession session, {VoidCallback? onChanged}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: StudentPicker(
        authSession: session,
        apiClient: ApiClient(authSession: session),
        onChanged: onChanged,
        onStage: true,
      ),
    ),
  );
}

void main() {
  const twoChildren = [
    LinkedStudent(id: 's1', displayName: '지민', studentCode: '123456'),
    LinkedStudent(id: 's2', displayName: '서준', studentCode: '654321'),
  ];

  testWidgets('on stage: white name on glass, white add-child icon', (
    tester,
  ) async {
    final session = await _parentWith(tester, twoChildren);
    await tester.pumpWidget(_picker(session));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('지민')).style!.color, Colors.white);
    expect(
      find.ancestor(of: find.text('지민'), matching: find.byType(GlassSurface)),
      findsOneWidget,
    );
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.personAdd)).color,
      Colors.white,
    );
    expect(
      find.ancestor(
        of: find.byIcon(AppIcons.personAdd),
        matching: find.byType(GlassSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('on stage: picking another child in the sheet switches', (
    tester,
  ) async {
    final session = await _parentWith(tester, twoChildren);
    var changed = 0;
    await tester.pumpWidget(_picker(session, onChanged: () => changed++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지민').first);
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    await tester.tap(find.descendant(of: sheet, matching: find.text('서준')));
    // 선택은 prefs 저장을 기다린 뒤 시트를 닫는다.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(session.viewAsStudentId, 's2');
    expect(changed, 1);
  });

  testWidgets('on stage: a long child name fits 320 wide at 1.3x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final session = await _parentWith(tester, const [
      LinkedStudent(
        id: 's1',
        displayName: '김가나다라마바사아자차카타파하가나다라마바사아자차카타파하',
        studentCode: '123456',
      ),
      LinkedStudent(id: 's2', displayName: '서준', studentCode: '654321'),
    ]);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 800),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _picker(session),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
