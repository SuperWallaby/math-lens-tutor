import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/app_shell.dart';
import 'package:math_lens_tutor/screens/upload_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/services/oauth_service.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 셸과 탭 화면들이 처음 그릴 때 부르는 조회만 데모 데이터로 바꾼 API.
///
/// [ApiClient]는 구체 클래스라 하위 클래스로 덮어쓰는 것이 가장 좁은 이음새다
/// (리팩터링 없이 네트워크만 막는다). 아래 네 메서드가 탭 화면 `initState`와
/// 셸의 `addPostFrameCallback`이 부르는 전부다.
class _DemoApi extends ApiClient {
  _DemoApi(AuthSession session) : super(authSession: session);

  int profileCalls = 0;
  int feedCalls = 0;

  @override
  Future<LearningProfile> getLearningProfile({
    bool forceRefresh = false,
    LearningProfileScope scope = LearningProfileScope.full,
  }) async {
    profileCalls++;
    return authSession.user?.role == AppUserRole.parent
        ? designReviewProfileParent()
        : designReviewProfileReturning();
  }

  @override
  Future<List<SubmissionSummary>> getSubmissionSummaries({
    bool forceRefresh = false,
  }) async => designReviewSubmissionsRecent();

  @override
  Future<TrainingFeedResponse> getTrainingFeed({
    bool forceRefresh = false,
  }) async {
    feedCalls++;
    return designReviewTrainingFeed();
  }

  @override
  Future<({AppUser user, List<LinkedStudent> linkedStudents})>
  fetchMe() async => (user: authSession.user!, linkedStudents: const <LinkedStudent>[]);
}

class _RouteLog extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

AppUser _user(AppUserRole? role) => AppUser(
  id: 'u1',
  displayName: '지민',
  profileComplete: true,
  role: role,
  grade: '중1',
  organizationName: '한빛중학교',
  studentCode: '123456',
);

/// 앱이 읽는 것과 같은 prefs 로 로그인한 세션을 불러온다.
Future<AuthSession> _session(WidgetTester tester, AppUserRole? role) async {
  SharedPreferences.setMockInitialValues({
    'auth_token': 'token',
    'auth_user': jsonEncode(_user(role).toJson()),
  });
  resetAppPrefsCache();
  final session = AuthSession();
  await tester.runAsync(session.load);
  expect(session.user?.role, role);
  return session;
}

/// 폰 크기 화면에 셸을 띄우고 첫 조회가 끝날 때까지 돌린다.
Future<({_DemoApi api, _RouteLog routes})> _pumpShell(
  WidgetTester tester,
  AppUserRole? role,
) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final api = _DemoApi(await _session(tester, role));
  final routes = _RouteLog();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      navigatorObservers: [routes],
      home: AppShell(apiClient: api, oauthService: OAuthService()),
    ),
  );
  // 탭 화면들의 데모 조회와 셸의 post-frame 조회가 끝나게 몇 프레임 돌린다.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (api: api, routes: routes);
}

/// 업로드 화면이 위에 있어도 아래 셸의 탭바를 읽도록 오프스테이지도 찾는다.
GlassTabBar _bar(WidgetTester tester) => tester.widget<GlassTabBar>(
  find.byType(GlassTabBar, skipOffstage: false),
);

Finder _inBar(String label) =>
    find.descendant(of: find.byType(GlassTabBar), matching: find.text(label));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

  group('student shell', () {
    testWidgets('has 홈 훈련 찍기 성장 설정, camera in the middle', (tester) async {
      await _pumpShell(tester, AppUserRole.student);

      expect(_bar(tester).labels, ['홈', '훈련', '성장', '설정']);
      expect(_bar(tester).onCenterAction, isNotNull);
      for (final t in ['홈', '훈련', '찍기', '성장', '설정']) {
        expect(_inBar(t), findsOneWidget, reason: t);
      }
      expect(_bar(tester).selectedIndex, 0);
    });

    testWidgets('tapping 찍기 opens the upload flow as a full-screen route', (
      tester,
    ) async {
      final shell = await _pumpShell(tester, AppUserRole.student);
      expect(find.byType(UploadScreen), findsNothing);

      await tester.tap(_inBar('찍기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final route = shell.routes.pushed.last;
      expect(route, isA<MaterialPageRoute<void>>());
      expect((route as MaterialPageRoute<void>).fullscreenDialog, isTrue);
      expect(find.byType(UploadScreen), findsOneWidget);
      // 카메라는 탭 전환이 아니다: 선택된 탭은 그대로 홈.
      expect(_bar(tester).selectedIndex, 0);
    });

    testWidgets('tapping 훈련 then 성장 selects tab 1 then 2', (tester) async {
      await _pumpShell(tester, AppUserRole.student);

      await tester.tap(_inBar('훈련'));
      await tester.pump();
      expect(_bar(tester).selectedIndex, 1);

      await tester.tap(_inBar('성장'));
      await tester.pump();
      expect(_bar(tester).selectedIndex, 2);
    });

    testWidgets('the training tab shows the ready-problem badge until opened', (
      tester,
    ) async {
      final shell = await _pumpShell(tester, AppUserRole.student);
      final ready = designReviewTrainingFeed().items.length;
      expect(ready, greaterThan(0));
      expect(shell.api.feedCalls, greaterThan(0));
      expect(_bar(tester).badgeIndex, 1);
      expect(_bar(tester).badgeCount, ready);

      await tester.tap(_inBar('훈련'));
      await tester.pump();
      expect(_bar(tester).badgeCount, 0);
    });
  });

  group('other roles', () {
    testWidgets('a parent has no camera and no 찍기', (tester) async {
      await _pumpShell(tester, AppUserRole.parent);

      expect(_bar(tester).onCenterAction, isNull);
      expect(_bar(tester).labels, ['홈', '설명', '이번 주', '진도', '설정']);
      expect(_inBar('찍기'), findsNothing);
      expect(_bar(tester).badgeIndex, isNull);
    });

    testWidgets('a parent tab without a stage gets a dark status bar back', (
      tester,
    ) async {
      await _pumpShell(tester, AppUserRole.parent);

      // 무대가 있는 설정 탭 → 상태바 흰 글자.
      await tester.tap(_inBar('설정'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

      // 무대가 없는 홈 탭으로 돌아오면 검정 글자로 돌아와야 한다.
      await tester.tap(_inBar('홈'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    });

    testWidgets('a session without a role gets the student tabs and the camera', (
      tester,
    ) async {
      final shell = await _pumpShell(tester, null);

      // 역할이 비어 있으면 학생 탭이 보이므로 카메라·배지·새로고침도 학생과 같다.
      expect(_bar(tester).labels, ['홈', '훈련', '성장', '설정']);
      expect(_bar(tester).onCenterAction, isNotNull);
      expect(_inBar('찍기'), findsOneWidget);
      expect(_bar(tester).badgeIndex, 1);
      expect(_bar(tester).badgeCount, greaterThan(0));
      expect(shell.api.feedCalls, greaterThan(0));

      await tester.tap(_inBar('찍기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(UploadScreen), findsOneWidget);
      expect(
        (shell.routes.pushed.last as MaterialPageRoute<void>).fullscreenDialog,
        isTrue,
      );
    });
  });
}
