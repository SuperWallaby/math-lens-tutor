import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/student_hub_screen.dart';
import 'package:math_lens_tutor/screens/student_training_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/services/oauth_service.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pixel_probe.dart';

/// Every tinted pill drawn around [label]: its text color and its see-through
/// fill. A pill is the nearest [Container] with a colored [BoxDecoration] whose
/// color is not opaque and whose corners are [AppRadii.pill].
List<({Color ink, Color tint})> _tintedPills(String label) {
  final pills = <({Color ink, Color tint})>[];
  for (final element in find.text(label).evaluate()) {
    BoxDecoration? deco;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is Container && widget.decoration is BoxDecoration) {
        final d = widget.decoration! as BoxDecoration;
        if (d.color != null) {
          deco = d;
          return false;
        }
      }
      return true;
    });
    final d = deco;
    if (d == null || d.color!.a >= 1) continue;
    if (d.borderRadius != BorderRadius.circular(AppRadii.pill)) continue;
    pills.add((ink: (element.widget as Text).style!.color!, tint: d.color!));
  }
  return pills;
}

/// The pills around each label reach 4.5:1 on white cards and on mist.
void _expectReadable(Iterable<String> labels) {
  for (final label in labels) {
    final pills = _tintedPills(label);
    expect(pills, isNotEmpty, reason: 'no tinted pill around 「$label」');
    for (final pill in pills) {
      for (final under in [Colors.white, AppColors.background]) {
        final fill = composite(pill.tint, under);
        expect(
          contrastRatio(pill.ink, fill),
          greaterThanOrEqualTo(4.5),
          reason: '「$label」 ${hex(pill.ink)} on ${hex(fill)} '
              '(tint over ${hex(under)})',
        );
      }
    }
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

  testWidgets('recent submission concept chip on the home tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentHubScreen(
            apiClient: ApiClient(authSession: AuthSession()),
            oauthService: OAuthService(),
            demoProfile: designReviewProfileReturning(),
            demoSubmissions: designReviewSubmissionsRecent(),
            demoUser: designReviewUser(),
            demoToday: DateTime(2026, 10, 17),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 최근 기록 두 줄의 주황 개념 칩.
    _expectReadable(['일차방정식', '소인수분해']);
  });

  testWidgets('feed card tags on the training tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentTrainingScreen(
            apiClient: ApiClient(authSession: AuthSession()),
            demoProfile: designReviewProfileFirstVisit(),
            demoFeed: const TrainingFeedResponse(
              source: 'precomputed',
              updatedAt: '2026-10-17T00:00:00Z',
              refreshPending: false,
              items: [
                TrainingFeedItem(
                  id: 'feed_1',
                  bankItemId: 'bank_linear',
                  concept: '일차방정식',
                  difficulty: 'medium',
                  reason: '오답 2회 복습',
                  title: '일차방정식 이항',
                  promptPreview: '2x + 5 = 13 일 때, x의 값은?',
                  problemCount: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 개념(파랑) · 난이도(주황) · 문제 수(회색).
    _expectReadable(['일차방정식', '보통', '3문제']);
  });
}
