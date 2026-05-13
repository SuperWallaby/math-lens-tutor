import 'package:flutter_test/flutter_test.dart';

import 'package:math_lens_tutor/main.dart';
import 'package:math_lens_tutor/services/api_client.dart';

void main() {
  testWidgets('renders native home screen', (WidgetTester tester) async {
    await tester.pumpWidget(MathLensTutorApp(apiClient: ApiClient()));

    await tester.pump();

    expect(find.text('우열'), findsOneWidget);
    expect(find.text('풀이 사진 분석하기'), findsOneWidget);
  });
}
