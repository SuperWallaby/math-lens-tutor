import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/analysis_screen.dart';
import 'package:math_lens_tutor/screens/practice_screen.dart';
import 'package:math_lens_tutor/screens/signup_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/services/oauth_service.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pixel_probe.dart';

/// 분석 요청이 바로 실패하는 API (분석 화면의 오류 분기를 연다).
class _FailingApi extends ApiClient {
  _FailingApi() : super(authSession: AuthSession());

  @override
  Future<AnalyzeResult> analyzeImageBytes(
    Uint8List bytes, {
    required String filename,
    AnalyzeQualityMode qualityMode = AnalyzeQualityMode.balanced,
    void Function(String progressMessage)? onProgress,
    void Function(Map<String, dynamic> event)? onStreamEvent,
  }) async => throw Exception('boom');
}

/// 올라가는 동안 보여 줄 사진 자리에 쓰이는 1x1 PNG.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

ApiClient _api() => ApiClient(authSession: AuthSession());

final _boundary = GlobalKey();

Widget _app(Widget home) => RepaintBoundary(
  key: _boundary,
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

/// 화면 맨 위, 앱바 줄의 빈 곳 (제목·뒤로가기 화살표와 겹치지 않는다).
const _topStripe = (x: 600, y: 20);

/// 라우트가 불투명이라 앱바 밑에는 Scaffold 배경밖에 없다. 투명하면 iOS에서는
/// 검정, 웹에서는 파랑 띠가 비친다. 그래서 배경이 흐린 안개색으로 칠해져야 한다.
Future<void> _expectOpaqueFogBehindAppBar(WidgetTester tester) async {
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
  expect(
    scaffold.backgroundColor == null ||
        scaffold.backgroundColor!.a == 1.0,
    isTrue,
    reason: 'Scaffold.backgroundColor must not be transparent: '
        '${scaffold.backgroundColor}',
  );

  final probe = await PixelProbe.capture(tester, _boundary);
  final px = probe.at(_topStripe.x, _topStripe.y);
  expect(px, AppColors.background, reason: 'pixel under the app bar: ${hex(px)}');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

  testWidgets('analysis result: app bar sits on the fog background', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AnalysisScreen(
          apiClient: _api(),
          result: designReviewAnalyzeResultWeak(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
    await _expectOpaqueFogBehindAppBar(tester);
  });

  testWidgets('analysis error branch: app bar sits on the fog background', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AnalysisScreen(
          apiClient: _FailingApi(),
          imageBytes: _onePixelPng,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    await _expectOpaqueFogBehindAppBar(tester);
  });

  testWidgets('practice: app bar sits on the fog background', (tester) async {
    await tester.pumpWidget(
      _app(
        PracticeScreen(
          apiClient: _api(),
          problemSet: designReviewProblemSetQuestion(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    await _expectOpaqueFogBehindAppBar(tester);
  });

  testWidgets('signup: page background is the fog, not transparent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SignupScreen(
          apiClient: _api(),
          oauthService: OAuthService(),
          onSignedIn: () {},
        ),
      ),
    );
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(
      scaffold.backgroundColor == null || scaffold.backgroundColor!.a == 1.0,
      isTrue,
      reason: 'Scaffold.backgroundColor: ${scaffold.backgroundColor}',
    );
    final probe = await PixelProbe.capture(tester, _boundary);
    expect(probe.at(_topStripe.x, _topStripe.y), AppColors.background);
  });
}
