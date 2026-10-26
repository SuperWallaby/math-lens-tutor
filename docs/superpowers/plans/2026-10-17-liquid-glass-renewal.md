# 우열 Liquid Glass 리뉴얼 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 유리를 떠 있는 층(탭바, 가운데 카메라, 스크롤 상단, 시트, 사진 위 조작부)에만 쓰고, 홈 상단을 파란 무대로 바꾸고, 첫 로그인 빈 상태를 새로 만든다.

**Architecture:** 토큰(유리 프리셋 3종, 무대 그라데이션, 버튼 3종)을 `app_design_system.dart`에 두고, 떠 있는 층 위젯만 `glass.dart`에 남긴다. 홈 상단은 새 `HomeStage` 위젯 하나가 맡는다. 앱 셸은 `extendBody`로 콘텐츠가 탭바 아래로 지나가게 한다. 콘텐츠 유리는 흰 카드(`AppCard`)와 버튼 3종으로 바꾸고, 소스 검사 테스트로 다시 들어오지 못하게 막는다.

**Tech Stack:** Flutter (Dart SDK ^3.11.5), `flutter_test`. 새 패키지는 추가하지 않는다. Next.js는 색 3곳만 고친다.

**Spec:** `docs/superpowers/specs/2026-10-17-liquid-glass-renewal-design.md`

## Global Constraints

- 색: 주색 `#2A72E5`, 진파랑 `#1E46AA`, 연파랑 `#E8F1FC`, 배경 `#EEF3F8`, 카드 `#FFFFFF`, 카드 테두리 `#EFEFF1`, 글자 `#111111` / `#494C4F` / `#999999`, 하늘 `#5EB7EB`, 노랑 `#FEB231`. 모두 `AppColors`에 이미 있다.
- 폰트: 본문 SUIT, 큰 제목 IBM Plex Sans KR. Noto Sans KR을 UI 기본 폰트로 쓰지 않는다.
- 유리 규칙: 콘텐츠 위에 떠 있으면 유리, 아니면 흰 카드. 예외는 홈 파란 무대 하나다. 배경화면 이미지, 색 번짐(blob), 노란 번짐을 쓰지 않는다.
- 버튼: 탭 화면에서는 가운데 카메라만 파란 채움이다. 탭 화면 본문의 주 버튼은 연파랑(`AppButtonStyles.soft`)이고, 홈 무대 위에서는 흰 버튼(`AppButtonStyles.white`)이다. 파란 유리 주 버튼(`GlassPrimaryButton`)은 탭바가 없는 전체 화면 흐름에서 화면당 하나만 쓴다.
- 말투: 해요체. 숙제 · 찍기 · 막힌 곳 · 이어서 풀기를 쓰고, 「AI」·「맞춤 추천」·「인사이트」·「대시보드」 말투를 새 문구에 쓰지 않는다.
- 유리는 `BackdropFilter` 흐림으로 만든다. 웹에서 `HtmlElementView`로 유리를 만들지 않는다. 굴절 셰이더는 쓰지 않는다.
- 런처 아이콘 `assets/brand/app_icon.png`는 바꾸지 않는다.
- 모든 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`를 붙인다. `.cursor/debug-6366de.log`는 커밋하지 않는다.

## Review Focus

1. **긴 이름·학교 이름**: 「김가나다라마바사님」, 「서울특별시립한빛국제중학교」 같은 값이 와도 사용자 줄은 한 줄 말줄임(…)으로 끝나고, 오른쪽 앱 아이콘과 겹치지 않아야 한다. → Task 4 테스트
2. **값이 빠진 사용자**: 게스트가 아닌데 `displayName`이 비었으면 이름 자리에 「반가워요」를 보여준다. 학년과 학교가 둘 다 없으면 아래 줄을 숨긴다. → Task 4 테스트
3. **프로필 사진 로드 실패**: URL이 깨지면 이름 첫 글자 원으로 대체되고, 화면에 오류 아이콘이 남지 않아야 한다. → Task 4 테스트
4. **좁은 폭과 큰 글자**: 폭 320, 글자 배율 1.3에서도 탭바 4칸 라벨과 가운데 카메라가 넘치지(overflow) 않아야 한다. → Task 3 테스트
5. **탭바에 가려지는 마지막 줄**: `extendBody` 뒤에도 각 탭의 마지막 콘텐츠가 탭바 위로 스크롤되어 보여야 한다(하단 여백에 탭바 높이 포함). → Task 3 테스트

---

### Task 0: 이전 리스킨 작업을 기반으로 커밋

계획 전체가 이 변경(토큰 `#2A72E5`, SUIT/IBM 폰트, 홈 문구) 위에서 진행된다.

**Files:**
- Commit: `.cursor/rules/design.mdc`, `DESIGN.md`, `flutter_app/analysis_options.yaml`, `flutter_app/lib/screens/student_hub_screen.dart`, `flutter_app/lib/theme/app_design_system.dart`, `flutter_app/lib/widgets/app_card.dart`, `flutter_app/lib/widgets/glass.dart`, `flutter_app/pubspec.lock`, `flutter_app/pubspec.yaml`, `flutter_app/web/index.html`, `src/app/auth/magic/page.tsx`, `src/app/globals.css`, `src/app/layout.tsx`, `src/lib/email.ts`, `src/lib/learning-profile.ts`, `flutter_app/assets/fonts/IBMPlexSansKR-Bold.ttf`, `flutter_app/assets/fonts/SUIT-Variable.ttf`

- [ ] **Step 1: 분석기 확인**

Run: `cd flutter_app && flutter analyze lib`
Expected: `error •` 줄이 없다(정보·경고만 있음).

- [ ] **Step 2: 기존 테스트 확인**

Run: `cd flutter_app && flutter test`
Expected: `All tests passed!`

- [ ] **Step 3: 커밋 (디버그 로그 제외)**

```bash
git add .cursor/rules/design.mdc DESIGN.md flutter_app/analysis_options.yaml flutter_app/lib/screens/student_hub_screen.dart flutter_app/lib/theme/app_design_system.dart flutter_app/lib/widgets/app_card.dart flutter_app/lib/widgets/glass.dart flutter_app/pubspec.lock flutter_app/pubspec.yaml flutter_app/web/index.html src/app/auth/magic/page.tsx src/app/globals.css src/app/layout.tsx src/lib/email.ts src/lib/learning-profile.ts flutter_app/assets/fonts/IBMPlexSansKR-Bold.ttf flutter_app/assets/fonts/SUIT-Variable.ttf
git commit -m "Reskin to app-icon blue with SUIT and IBM Plex Sans KR."
git status --short   # .cursor/debug-6366de.log만 남아야 한다
```

---

### Task 1: 유리 프리셋, 무대 그라데이션, 버튼 스타일 토큰

**Files:**
- Modify: `flutter_app/lib/theme/app_design_system.dart`
- Test: `flutter_app/test/theme/glass_tokens_test.dart`

**Interfaces:**
- Produces:
  - `enum GlassPreset { clear, onBlue, prominent }`
  - `class GlassSpec { const GlassSpec({required Color fill, required double blur, required Color rim, required List<BoxShadow> shadows, required bool topHighlight}); static GlassSpec of(GlassPreset preset); }`
  - `abstract final class AppGradients { static const LinearGradient stage; }`
  - `AppButtonStyles.soft() → ButtonStyle`, `AppButtonStyles.white() → ButtonStyle`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
void main() {
  test('glass presets match the spec', () {
    final clear = GlassSpec.of(GlassPreset.clear);
    expect(clear.fill, const Color(0x4DFFFFFF)); // 흰색 30%
    expect(clear.blur, 14);
    expect(clear.rim, const Color(0xA8FFFFFF)); // 흰색 66%
    expect(clear.topHighlight, isTrue);

    final onBlue = GlassSpec.of(GlassPreset.onBlue);
    expect(onBlue.fill, const Color(0x24FFFFFF)); // 흰색 14%
    expect(onBlue.blur, 16);
    expect(onBlue.rim, const Color(0x61FFFFFF)); // 흰색 38%

    final prominent = GlassSpec.of(GlassPreset.prominent);
    expect(prominent.fill, const Color(0xE02A72E5)); // #2A72E5 88%
    expect(prominent.blur, 10);
    expect(prominent.rim, const Color(0x47FFFFFF)); // 흰색 28%
    expect(prominent.topHighlight, isTrue);
  });

  test('stage gradient runs sky to cobalt', () {
    expect(AppGradients.stage.colors, const [
      Color(0xFF5EB7EB), Color(0xFF2A72E5), Color(0xFF1E46AA),
    ]);
  });

  test('soft and white button styles', () {
    final soft = AppButtonStyles.soft();
    expect(soft.backgroundColor!.resolve({}), AppColors.primarySoft);
    expect(soft.foregroundColor!.resolve({}), AppColors.primaryDark);
    final white = AppButtonStyles.white();
    expect(white.backgroundColor!.resolve({}), Colors.white);
    expect(white.foregroundColor!.resolve({}), AppColors.primary);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd flutter_app && flutter test test/theme/glass_tokens_test.dart`
Expected: FAIL (`GlassPreset`가 정의되지 않음)

- [ ] **Step 3: 구현**

`app_design_system.dart`에 위 Interfaces를 추가한다. 그림자 값은 스펙 3장 표를 따른다.
- 맑은 유리: `BoxShadow(color: Color(0x24112850), offset: Offset(0, 8), blurRadius: 24)`
- 무대용 유리: `Color(0x380A1E5A), (0, 10), 26`
- 파란 유리: `Color(0x522A72E5), (0, 8), 18`

`AppGradients.stage`는 165°에 맞춰 `begin: Alignment(-0.27, -1)`, `end: Alignment(0.27, 1)`로 둔다. `soft`와 `white`는 기존 `AppButtonStyles.filled(backgroundColor:, foregroundColor:)`를 재사용한다.

- [ ] **Step 4: 통과 확인**

Run: `cd flutter_app && flutter test test/theme/glass_tokens_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add flutter_app/lib/theme/app_design_system.dart flutter_app/test/theme/glass_tokens_test.dart
git commit -m "Add glass presets, stage gradient, and soft/white button styles."
```

---

### Task 2: 떠 있는 층 위젯

기존 콘텐츠용 위젯(`GlassPanel` 등)은 Task 8에서 지운다. 이 태스크에서는 새 위젯만 추가한다.

**Files:**
- Modify: `flutter_app/lib/widgets/glass.dart`
- Test: `flutter_app/test/widgets/glass_widgets_test.dart`

**Interfaces:**
- Consumes: `GlassPreset`, `GlassSpec.of` (Task 1)
- Produces:
  - `GlassSurface({Key? key, required Widget child, GlassPreset preset = GlassPreset.clear, BorderRadius borderRadius = const BorderRadius.all(Radius.circular(AppRadii.pill)), EdgeInsetsGeometry padding = EdgeInsets.zero})`
  - `GlassPrimaryButton({Key? key, required String label, required VoidCallback? onPressed, IconData? icon})`: 높이 52, 파란 유리, 흰 글씨 16/700
  - `GlassCoachBubble({Key? key, required String text})`: 맑은 유리 말풍선, 아래쪽 꼬리
  - `GlassScrollEdge({Key? key, required bool visible, required String title})`: 높이 84, 위는 `#EEF3F8` 82%에서 아래로 0, 흐림 10, 가운데 제목 15/700. `visible`이 false면 투명도 0, 200ms 전환

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
void main() {
  testWidgets('GlassSurface blurs with the preset sigma', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GlassSurface(child: SizedBox(width: 10, height: 10))));
    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter;
    expect(filter.toString(), contains('14.0'));
  });

  testWidgets('GlassPrimaryButton shows label, is 52 tall, and taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: GlassPrimaryButton(label: '분석하기', onPressed: () => taps++)))));
    expect(find.text('분석하기'), findsOneWidget);
    expect(tester.getSize(find.byType(GlassPrimaryButton)).height, 52);
    await tester.tap(find.text('분석하기'));
    expect(taps, 1);
  });

  testWidgets('GlassScrollEdge hides when not visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GlassScrollEdge(visible: false, title: '훈련')));
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0);
  });

  testWidgets('GlassCoachBubble shows its text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: GlassCoachBubble(text: '여기를 눌러 숙제 한 장 찍어요'))));
    expect(find.text('여기를 눌러 숙제 한 장 찍어요'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd flutter_app && flutter test test/widgets/glass_widgets_test.dart`
Expected: FAIL (`GlassPrimaryButton` 등이 정의되지 않음)

- [ ] **Step 3: 구현**

`GlassSurface`는 바깥 `DecoratedBox`(그림자) 안에 `ClipRRect` → `BackdropFilter(ImageFilter.blur(sigmaX: blur, sigmaY: blur))` → `DecoratedBox`(채움, 1px 테두리) 순서로 쌓는다. `topHighlight`가 true면 위쪽 1px 안쪽 하이라이트(흰색 90% → 0 세로 그라데이션 띠)를 그린다. 기존 private `_GlassSurface`를 쓰던 곳(`GlassTabBar` 등)은 Task 3에서 교체한다.

- [ ] **Step 4: 통과 확인**

Run: `cd flutter_app && flutter test test/widgets/glass_widgets_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add flutter_app/lib/widgets/glass.dart flutter_app/test/widgets/glass_widgets_test.dart
git commit -m "Add floating-layer glass widgets: surface, primary button, coach bubble, scroll edge."
```

---

### Task 3: 학생 탭바와 가운데 카메라

**Files:**
- Modify: `flutter_app/lib/widgets/glass.dart` (`GlassTabBar`, `GlassNavBar`, `GlassAtmosphere`)
- Modify: `flutter_app/lib/screens/app_shell.dart`
- Modify: `flutter_app/lib/layout/tablet_layout.dart:28-39`
- Test: `flutter_app/test/widgets/glass_tab_bar_test.dart`, `flutter_app/test/layout/page_padding_test.dart`

**Interfaces:**
- Consumes: `GlassSurface`, `GlassPreset` (Task 1, 2)
- Produces:
  - `GlassTabBar({Key? key, required List<String> labels, required List<IconData> icons, required int selectedIndex, required ValueChanged<int> onSelected, VoidCallback? onCenterAction, int? badgeIndex, int badgeCount = 0})`
    - `onCenterAction`이 있으면 `labels.length`는 짝수여야 하고(assert), 가운데 카메라 칸이 `labels.length ~/ 2` 위치에 들어간다. `selectedIndex`와 `onSelected`의 번호는 카메라를 뺀 탭 번호다.
  - 학생 탭 번호: 홈 0, 훈련 1, 성장 2, 설정 3

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
Widget _bar({required ValueChanged<int> onSelected, required VoidCallback onCamera, double width = 390, double scale = 1}) =>
    MaterialApp(home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
      child: Scaffold(bottomNavigationBar: GlassTabBar(
        labels: const ['홈', '훈련', '성장', '설정'],
        icons: const [Icons.home_rounded, Icons.edit_note_rounded, Icons.menu_book_rounded, Icons.settings_rounded],
        selectedIndex: 0, onSelected: onSelected, onCenterAction: onCamera)),
    ));

void main() {
  testWidgets('student bar shows four tabs and a center camera', (tester) async {
    int? selected; var camera = 0;
    await tester.pumpWidget(_bar(onSelected: (i) => selected = i, onCamera: () => camera++));
    for (final t in ['홈', '훈련', '찍기', '성장', '설정']) { expect(find.text(t), findsOneWidget); }
    await tester.tap(find.text('찍기'));
    expect(camera, 1);
    await tester.tap(find.text('성장'));
    expect(selected, 2);
  });

  testWidgets('no overflow at 320 wide with 1.3x text', (tester) async {
    await tester.pumpWidget(_bar(onSelected: (_) {}, onCamera: () {}, width: 320, scale: 1.3));
    expect(tester.takeException(), isNull);
  });
}
```

`page_padding_test.dart`:

```dart
testWidgets('page padding clears the bottom inset', (tester) async {
  late EdgeInsets padding;
  await tester.pumpWidget(MediaQuery(
    data: const MediaQueryData(size: Size(390, 844), padding: EdgeInsets.only(bottom: 120)),
    child: Builder(builder: (context) { padding = TabletLayout.pagePadding(context); return const SizedBox(); }),
  ));
  expect(padding.bottom, 24 + 120);
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd flutter_app && flutter test test/widgets/glass_tab_bar_test.dart test/layout/page_padding_test.dart`
Expected: FAIL (`onCenterAction` 인자 없음, 하단 여백 24)

- [ ] **Step 3: `GlassTabBar` 다시 만들기**

치수는 스펙 5장을 따른다.
- 맑은 유리 알약. 좌우 12, 아래 16 + 안전 영역, 높이 64.
- 선택된 탭: 아이콘·글자 `AppColors.primary` + `primary` 12% 알약 배경.
- 가운데 카메라: `GlassPreset.prominent` 58px 원, 30 위로 솟음, 흰 테두리 3px, 아이콘 `Icons.photo_camera_rounded`, 아래 글자 「찍기」(`primary`, 10.5/700).
- 위젯 전체 높이에 카메라 솟음 30을 포함한다. 그래야 `extendBody`의 하단 여백 계산이 맞는다. 빈 영역은 터치를 통과시킨다.
- 배지는 기존처럼 `primaryDark` 원.
- `GlassNavBar`는 지운다.

- [ ] **Step 4: 셸 바꾸기**

- `app_shell.dart` 학생 탭을 [홈, 훈련, 성장, 설정]으로 바꾸고 `UploadScreen` 탭을 뺀다. `_studentTrainingTabIndex = 1`, `_studentProgressTabIndex = 2`로 바꾼다.
- `onCenterAction`은 학생일 때만 넘긴다. `Navigator.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => UploadScreen(apiClient: widget.apiClient)))` 후 `_studentHubKey.currentState?.refreshFromTab(forceRefresh: true)`를 부른다.
- `StudentHubScreen` 생성 시 `matchPinPreview: true`를 지운다.
- `Scaffold(extendBody: true)`로 바꾼다.
- `GlassAtmosphere`는 번짐 원 두 개를 지우고 `AppColors.background` 단색만 칠한다.

- [ ] **Step 5: 하단 여백**

`TabletLayout.pagePadding`의 아래 값(24 / 24 / 28)에 `MediaQuery.paddingOf(context).bottom`을 더한다.

- [ ] **Step 6: 통과 확인**

Run: `cd flutter_app && flutter test && flutter analyze lib`
Expected: `All tests passed!`, `error •` 없음

- [ ] **Step 7: 커밋**

```bash
git add flutter_app/lib/widgets/glass.dart flutter_app/lib/screens/app_shell.dart flutter_app/lib/layout/tablet_layout.dart flutter_app/test/widgets/glass_tab_bar_test.dart flutter_app/test/layout/page_padding_test.dart
git commit -m "Float the student tab bar with a center camera and let content scroll beneath it."
```

---

### Task 4: 앱 아이콘 자산과 `HomeStage`

**Files:**
- Create: `flutter_app/assets/brand/app_icon_cutout.png` (`docs/superpowers/specs/assets/2026-10-17-liquid-glass/app_icon_cutout.png`를 복사)
- Create: `flutter_app/lib/utils/korean_date.dart`
- Create: `flutter_app/lib/widgets/home_stage.dart`
- Test: `flutter_app/test/utils/korean_date_test.dart`, `flutter_app/test/widgets/home_stage_test.dart`

**Interfaces:**
- Consumes: `GlassPreset.onBlue`, `GlassSurface`, `AppGradients.stage` (Task 1, 2)
- Produces:
  - `String formatKoreanDate(DateTime date)` → 「10월 17일 토요일」
  - `enum HomeStageMode { firstVisit, returning }`
  - `class HomeStageUser`
    - 생성자: `const HomeStageUser({String name = '', String grade = '', String organization = '', String? imageUrl, int streakWeeks = 0, bool isGuest = false})`
    - `factory HomeStageUser.from(AppUser? user, LearningProfile profile, {required bool isGuest})`: `grade`는 `user?.grade`가 비면 `profile.grade`, `streakWeeks`는 `profile.stats.streakWeeks`
  - `String homeStageTitle(HomeStageUser u)` → 게스트·이름 없음: 「반가워요」, 그 외: 「{name}님」
  - `String? homeStageSubline(HomeStageUser u)` → 게스트: 「둘러보는 중」, 그 외: 학년 · 학교 중 비지 않은 값을 「 · 」로 연결, 둘 다 없으면 `null`
  - `bool homeStageShowsStreak(HomeStageMode mode, HomeStageUser u)` → `mode == returning && !u.isGuest && u.streakWeeks >= 1`
  - `String homeStageHeadline(HomeStageMode mode)` → 「오늘은 한 장만\n올려도 돼요」 / 「어제 막힌 곳부터\n이어가요」
  - `HomeStage({Key? key, required HomeStageMode mode, required HomeStageUser user, required DateTime today, required Widget card, Widget? footer})`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// korean_date_test.dart
test('formats month, day, and weekday', () {
  expect(formatKoreanDate(DateTime(2026, 10, 17)), '10월 17일 토요일');
  expect(formatKoreanDate(DateTime(2026, 10, 19)), '10월 19일 월요일');
});
```

```dart
// home_stage_test.dart
const jimin = HomeStageUser(name: '지민', grade: '중1', organization: '한빛중학교', streakWeeks: 3);

test('title, subline, and streak rules', () {
  expect(homeStageTitle(jimin), '지민님');
  expect(homeStageSubline(jimin), '중1 · 한빛중학교');
  expect(homeStageSubline(const HomeStageUser(name: '지민', organization: '한빛중학교')), '한빛중학교');
  expect(homeStageSubline(const HomeStageUser(name: '지민')), isNull);
  expect(homeStageTitle(const HomeStageUser()), '반가워요');
  expect(homeStageTitle(const HomeStageUser(name: '지민', isGuest: true)), '반가워요');
  expect(homeStageSubline(const HomeStageUser(isGuest: true)), '둘러보는 중');
  expect(homeStageShowsStreak(HomeStageMode.returning, jimin), isTrue);
  expect(homeStageShowsStreak(HomeStageMode.firstVisit, jimin), isFalse);
  expect(homeStageShowsStreak(HomeStageMode.returning, const HomeStageUser(name: '지민')), isFalse);
});

Widget _stage(HomeStageUser user, {double width = 390}) => MaterialApp(home: MediaQuery(
  data: MediaQueryData(size: Size(width, 800)),
  child: Scaffold(body: SingleChildScrollView(child: HomeStage(
    mode: HomeStageMode.returning, user: user, today: DateTime(2026, 10, 17), card: const SizedBox(height: 40)))),
));

testWidgets('returning stage shows date, name, subline, streak, headline', (tester) async {
  await tester.pumpWidget(_stage(jimin));
  for (final t in ['10월 17일 토요일', '지민님', '중1 · 한빛중학교', '3주 연속', '어제 막힌 곳부터\n이어가요']) {
    expect(find.text(t), findsOneWidget);
  }
  expect(find.text('우열'), findsNothing);
});

testWidgets('long name and school ellipsize without overflow at 320 wide', (tester) async {
  await tester.pumpWidget(_stage(const HomeStageUser(name: '김가나다라마바사', grade: '중1', organization: '서울특별시립한빛국제중학교'), width: 320));
  expect(tester.takeException(), isNull);
  final name = tester.widget<Text>(find.text('김가나다라마바사님'));
  expect(name.maxLines, 1);
  expect(name.overflow, TextOverflow.ellipsis);
  final nameRight = tester.getTopRight(find.text('김가나다라마바사님')).dx;
  final iconLeft = tester.getTopLeft(find.byKey(const Key('home-stage-icon'))).dx;
  expect(nameRight, lessThanOrEqualTo(iconLeft));
});

testWidgets('broken profile photo falls back to the initial', (tester) async {
  await tester.pumpWidget(_stage(const HomeStageUser(name: '지민', imageUrl: 'https://invalid.invalid/x.png')));
  await tester.pumpAndSettle();
  expect(find.text('지'), findsOneWidget);
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd flutter_app && flutter test test/utils/korean_date_test.dart test/widgets/home_stage_test.dart`
Expected: FAIL (`formatKoreanDate`, `HomeStage`가 정의되지 않음)

- [ ] **Step 3: 자산 복사**

`app_icon_cutout.png`를 `flutter_app/assets/brand/`에 복사한다. `pubspec.yaml`이 이미 `assets/brand/`를 포함하므로 등록은 필요 없다.

- [ ] **Step 4: 구현**

`formatKoreanDate`는 `['월','화','수','목','금','토','일'][date.weekday - 1]`로 요일을 만든다.

`HomeStage` 배치는 스펙 6.1장을 따른다.
- 배경: `AppGradients.stage`, 아래 모서리 32, 위 여백은 안전 영역 + 14.
- 오른쪽 위 아이콘: `Image.asset('assets/brand/app_icon_cutout.png', key: Key('home-stage-icon'))` 108px, 8° 회전(`Transform.rotate(angle: 0.14)`), 그림자.
- 왼쪽 위 칸: 아이콘 폭만큼 오른쪽을 비우고 세로로 쌓는다.
  1. 날짜: 13/600, 흰색 86%
  2. 사용자 줄: 아바타 40 + 제목 17/700 + 아래 줄 12.5/600 흰색 80%. 모두 `maxLines: 1`, 말줄임.
  3. 연속 칩: `homeStageShowsStreak`일 때, `GlassPreset.onBlue`, 불꽃 아이콘 `AppColors.spark`, 「{n}주 연속」
- 그 아래 인사 문장 22/700 흰색, 다음에 `card`, `footer`.
- 아바타: `imageUrl`이 있으면 `Image.network(..., errorBuilder:)`로 실패 시 이니셜(`name.characters.first`, 연주황 그라데이션 원 + 흰 테두리 2). 게스트는 `GlassPreset.onBlue` 원 + `Icons.person_rounded`.

- [ ] **Step 5: 통과 확인**

Run: `cd flutter_app && flutter test test/utils/korean_date_test.dart test/widgets/home_stage_test.dart`
Expected: PASS

- [ ] **Step 6: 커밋**

```bash
git add flutter_app/assets/brand/app_icon_cutout.png flutter_app/lib/utils/korean_date.dart flutter_app/lib/widgets/home_stage.dart flutter_app/test/utils/korean_date_test.dart flutter_app/test/widgets/home_stage_test.dart
git commit -m "Add the home blue stage with the cut-out icon, date, and user row."
```

---

### Task 5: 학생 홈 (처음 / 다시 / 게스트)

**Files:**
- Modify: `flutter_app/lib/screens/student_hub_screen.dart`
- Modify: `flutter_app/lib/dev/design_review_shell.dart`, `flutter_app/lib/dev/design_review_data.dart` (키 `student_hub__guest` 추가)
- Modify: `flutter_app/lib/dev/store_screenshot_student_shell.dart:69` (`matchPinPreview` 인자 제거)
- Modify: `flutter_app/test/widget_test.dart`
- Test: `flutter_app/test/screens/student_hub_test.dart`

**Interfaces:**
- Consumes: `HomeStage`, `HomeStageUser.from`, `HomeStageMode` (Task 4), `GlassCoachBubble`, `GlassSurface` (Task 2), `AppButtonStyles.white` (Task 1)
- Produces: `StudentHubScreen`에 `AppUser? demoUser`, `DateTime? demoToday`를 추가하고 `matchPinPreview`는 지운다. 사용자는 `demoUser ?? apiClient.authSession.user`, 날짜는 `demoToday ?? DateTime.now()`다.

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
Widget _hub({required LearningProfile profile, required List<SubmissionSummary> subs, bool guest = false}) {
  final auth = AuthSession();
  return MaterialApp(home: Scaffold(body: StudentHubScreen(
    apiClient: ApiClient(authSession: auth), oauthService: OAuthService(),
    demoProfile: profile, demoSubmissions: subs, demoIsGuest: guest,
    demoUser: const AppUser(id: 'u1', displayName: '지민', profileComplete: true, grade: '중1', organizationName: '한빛중학교'),
    demoToday: DateTime(2026, 10, 17))));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first visit: steps, example, coach, no wordmark or upload button', (tester) async {
    await tester.pumpWidget(_hub(profile: designReviewProfileFirstVisit(), subs: designReviewSubmissionsEmpty()));
    await tester.pumpAndSettle();
    for (final t in ['오늘은 한 장만\n올려도 돼요', '숙제 한 장 찍기', '막힌 곳 짚기', '이어서 풀기',
        '앨범에서 사진 고르기', '이렇게 짚어줘요', '여기를 눌러 숙제 한 장 찍어요']) {
      expect(find.text(t), findsWidgets);
    }
    expect(find.text('우열'), findsNothing);
    expect(find.text('숙제 올리기'), findsNothing);
  });

  testWidgets('returning: mission, white continue button, streak, recent', (tester) async {
    await tester.pumpWidget(_hub(profile: designReviewProfileReturning(), subs: designReviewSubmissionsRecent()));
    await tester.pumpAndSettle();
    expect(find.text('어제 막힌 곳부터\n이어가요'), findsOneWidget);
    expect(find.text('2주 연속'), findsOneWidget); // designReviewProfileReturning streakWeeks = 2
    expect(find.text('최근'), findsOneWidget);
    final cta = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '이어서 풀기'));
    expect(cta.style!.backgroundColor!.resolve({}), Colors.white);
  });

  testWidgets('guest with history: guest row and signup row', (tester) async {
    await tester.pumpWidget(_hub(profile: designReviewProfileReturning(), subs: designReviewSubmissionsRecent(), guest: true));
    await tester.pumpAndSettle();
    expect(find.text('반가워요'), findsOneWidget);
    expect(find.text('둘러보는 중'), findsOneWidget);
    expect(find.text('2주 연속'), findsNothing);
    expect(find.text('가입하기'), findsOneWidget);
  });
}
```

`widget_test.dart`의 `expect(find.text('우열'), findsOneWidget)`를 `expect(find.text('오늘은 한 장만\n올려도 돼요'), findsOneWidget)`로 바꾼다.

- [ ] **Step 2: 실패 확인**

Run: `cd flutter_app && flutter test test/screens/student_hub_test.dart test/widget_test.dart`
Expected: FAIL (`demoUser` 인자 없음)

- [ ] **Step 3: `_FirstTimeHome` 다시 만들기**

- `HomeStage(mode: firstVisit, card: 3단계 카드)`를 둔다. 3단계 카드는 `GlassSurface(preset: onBlue)`이고 스펙 6.2장 문구를 쓴다. 카드 아래에 흰 글자 링크 「앨범에서 사진 고르기」(`onPickGallery`)를 둔다.
- 무대 밑에 「이렇게 짚어줘요 · 예시」 흰 카드를 둔다. 예시 풀이 `x/4 − x/12 = 20`의 「= 20」에 빨간 원(`Color(0xFFE5484D)`)을 치고, 「여기서 막혔어요 / 분과 시간 단위를 섞었어요. 20분은 1/3시간이에요.」를 쓴다.
- 화면 아래 가운데에 `GlassCoachBubble('여기를 눌러 숙제 한 장 찍어요')`를 `Positioned(bottom: MediaQuery.paddingOf(context).bottom + 8)`로 띄운다.
- 「숙제 올리기」 버튼과 「우열」 글자는 없앤다.

- [ ] **Step 4: `_ReturningHome` 다시 만들기**

- `HomeStage(mode: returning, card: 미션 카드 + 통계)`를 둔다.
  - 미션 카드: `GlassSurface(onBlue)` 안에 단원 · 남은 문제 수, 제목, 흰 진행 막대, `FilledButton(style: AppButtonStyles.white())` 「이어서 풀기」.
  - 통계: 정답률, 해결한 문제를 `onBlue` 유리 칸 2개로 나란히.
- 무대 밑에 「최근」 흰 카드 리스트를 둔다. 기존 `_RecentSubmissionTile`을 쓰되, 상태 칩은 「N문제 남음」(연파랑) / 「다 풀었어요」(연초록 `Color(0xFFE6F6EA)` + `Color(0xFF1F7A33)`)로 한다.

- [ ] **Step 5: 게스트**

게스트면 `HomeStageUser.from(..., isGuest: true)`를 쓰고, `footer`에 `GlassSurface(onBlue)` 줄을 넣는다: 「둘러보는 중이에요. 가입하면 기록이 남아요.」 + 「가입하기」(`_openSignup`). 기존 `_GuestSaveBanner`는 지운다.

- [ ] **Step 6: `matchPinPreview` 제거**

`StudentHubScreen`에서 `matchPinPreview`와 `_openPinAnalysis`를 지우고, 컴파일 에러가 나는 호출부에서 인자를 지운다. 디자인 리뷰에 `student_hub__guest` 키를 추가한다(`designReviewProfileReturning()` + `designReviewSubmissionsRecent()` + `demoIsGuest: true`). 기존 `returning` 키는 `demoIsGuest: false`로 바꾼다.

- [ ] **Step 7: 통과 확인**

Run: `cd flutter_app && flutter test && flutter analyze lib`
Expected: `All tests passed!`, `error •` 없음

- [ ] **Step 8: 커밋**

```bash
git add flutter_app/lib/screens/student_hub_screen.dart flutter_app/lib/dev flutter_app/test/screens/student_hub_test.dart flutter_app/test/widget_test.dart
git commit -m "Rebuild student home on the blue stage for first visit, returning, and guest."
```

---

### Task 6: 훈련·성장 빈 상태

**Files:**
- Modify: `flutter_app/lib/screens/student_training_screen.dart:405-470` (`_TrainingEmptyState`)
- Modify: `flutter_app/lib/screens/student_progress_screen.dart:170-205`
- Modify: `flutter_app/lib/dev/design_review_shell.dart`, `flutter_app/lib/dev/design_review_data.dart` (키 `student_training__empty`, `student_progress__empty`)
- Test: `flutter_app/test/screens/empty_states_test.dart`

**Interfaces:**
- Consumes: `AppCard`(흰 카드, Task 7에서 바뀌지만 API는 같다), `GlassScrollEdge` (Task 2)
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
testWidgets('training empty state, no learning data', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: StudentTrainingScreen(
    apiClient: ApiClient(authSession: AuthSession()),
    demoProfile: designReviewProfileFirstVisit(),
    demoFeed: const TrainingFeedResponse(items: [], source: 'precomputed', updatedAt: '2026-10-17T00:00:00Z', refreshPending: false)))));
  await tester.pumpAndSettle();
  for (final t in ['훈련', '아직 훈련할 문제가 없어요', '숙제를 찍으면 막힌 개념이 여기에 모여요.',
      '이런 식으로 쌓여요', '가운데 카메라로 시작해요']) {
    expect(find.text(t), findsOneWidget);
  }
  expect(find.text('아직 훈련할 항목이 없습니다'), findsNothing);
});

testWidgets('progress empty state', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: StudentProgressScreen(
    apiClient: ApiClient(authSession: AuthSession()),
    demoProfile: designReviewProfileFirstVisit(), demoInitialGradeTab: 3))));
  await tester.pumpAndSettle();
  expect(find.text('내 진도'), findsOneWidget);
  expect(find.text('내 진도 현황'), findsNothing);
  expect(find.textContaining('숙제를 찍으면 그 단원부터 채워져요.'), findsOneWidget);
  expect(find.textContaining(RegExp(r'^0 / \d+ 단원$')), findsOneWidget);
  expect(find.text('시작 전'), findsWidgets);
});

testWidgets('scroll edge appears after scrolling the progress tab', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: StudentProgressScreen(
    apiClient: ApiClient(authSession: AuthSession()),
    demoProfile: designReviewProfileFirstVisit(), demoInitialGradeTab: 3))));
  await tester.pumpAndSettle();
  expect(tester.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible, isFalse);
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
  await tester.pumpAndSettle();
  expect(tester.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible, isTrue);
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd flutter_app && flutter test test/screens/empty_states_test.dart`
Expected: FAIL (「아직 훈련할 문제가 없어요」 없음)

- [ ] **Step 3: 훈련 빈 상태**

`_TrainingEmptyState`를 스펙 7장대로 다시 만든다.
- 맨 위: 제목 「훈련」 24/700, 설명 「막힌 개념만 모아서 다시 풀어보는 곳이에요.」
- 빈 카드(흰): 연파랑 원 아이콘(`Icons.edit_note_rounded`), 「아직 훈련할 문제가 없어요」, 「숙제를 찍으면 막힌 개념이 여기에 모여요.」
- 「이런 식으로 쌓여요 · 예시」: 투명도 55% 점선 테두리 줄 2개(「단위 바꾸기 (분 → 시간) · 일차방정식의 활용 · 3문제」, 「분배법칙 부호 · 문자와 식 · 2문제」)
- 맨 아래: 파란 글자 「가운데 카메라로 시작해요」(아래 화살표 아이콘)
- `hasLearningData`가 true면 빈 카드 문구만 「막힌 문제를 다 풀었어요.」 / 「새로 막히면 여기에 모여요.」로 바꾸고, 예시 줄과 카메라 안내는 숨긴다.

- [ ] **Step 4: 성장 빈 상태**

- 제목을 「내 진도」로 바꾼다(학생일 때만, 보호자 화면 문구는 그대로).
- `units.where((u) => u.percent > 0).length == 0`이면 구간 선택 아래에 흰 안내 카드를 둔다: 「0 / {units.length} 단원」(18/700) + 「숙제를 찍으면 그 단원부터 채워져요.」
- `CurriculumProgressList`에서 `percent == 0`인 줄의 상태 글자가 「시작 전」인지 확인하고, 아니면 그렇게 바꾼다.

- [ ] **Step 5: 스크롤 상단 흐림**

훈련(빈 상태와 목록 모두)과 성장 탭의 본문을 `Stack`으로 감싸고, 맨 위에 `GlassScrollEdge(visible: _scrolled, title: '훈련' / '내 진도')`를 둔다. `NotificationListener<ScrollNotification>`에서 `metrics.pixels > 30`일 때 `_scrolled`를 true로 바꾼다.

- [ ] **Step 6: 디자인 리뷰 키 추가 후 통과 확인**

Run: `cd flutter_app && flutter test && flutter analyze lib`
Expected: `All tests passed!`, `error •` 없음

- [ ] **Step 7: 커밋**

```bash
git add flutter_app/lib/screens/student_training_screen.dart flutter_app/lib/screens/student_progress_screen.dart flutter_app/lib/widgets/learning_profile_widgets.dart flutter_app/lib/dev flutter_app/test/screens/empty_states_test.dart
git commit -m "Add first-login empty states for training and progress."
```

---

### Task 7: 콘텐츠 유리를 흰 카드로 (학생 흐름)

**Files:**
- Modify: `flutter_app/lib/widgets/app_card.dart`
- Modify: `flutter_app/lib/screens/analysis_screen.dart`, `practice_screen.dart`, `loop_result_screen.dart`, `upload_screen.dart`, `student_training_screen.dart`, `dashboard_screen.dart`, `student_hub_screen.dart`
- Test: `flutter_app/test/widgets/app_card_test.dart`

**Interfaces:**
- Consumes: `GlassPrimaryButton` (Task 2), `AppButtonStyles.soft` (Task 1)
- Produces (`app_card.dart`):
  - `AppCard`: 흰색, 테두리 `#EFEFF1` 1px, 모서리 16, 그림자 없음. API는 그대로.
  - `AppChoiceTile({Key? key, required Widget label, required bool selected, required VoidCallback onTap})`: 선택되면 `primarySoft` 배경 + `primary` 테두리 1.5
  - `AppGlyph({Key? key, required IconData icon, double size = 44})`: `primarySoft` 원 + `primary` 아이콘
  - `AppInfoRow({Key? key, required IconData icon, required String title, required String subtitle})`: `GlassInfoRow`와 같은 배치, 흰 카드

**바꾸는 규칙**

| 지금 | 바꿀 것 |
|------|---------|
| `GlassPanel` | `AppCard` |
| `GlassButton(primary: true)`, 탭바 없는 화면 | `GlassPrimaryButton` (화면당 하나) |
| `GlassButton(primary: true)`, 탭 화면 | `FilledButton(style: AppButtonStyles.soft())` |
| `GlassButton(primary: false)` | `OutlinedButton` (테마 기본) |
| `GlassField`, `GlassSunken` | `TextField` (테마 입력칸: 흰 채움, 테두리 `#EFEFF1`) |
| `GlassChoice` | `AppChoiceTile` |
| `GlassGlyph` | `AppGlyph` |
| `GlassInfoRow` | `AppInfoRow` |
| 사진 위에 떠 있는 버튼·라벨 | 그대로 유리(`GlassSurface`, `GlassCircleButton`) |

탭바 없는 화면: analysis, practice, loop_result, upload, dashboard. 탭 화면: student_hub, student_training.

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
testWidgets('AppCard is a flat white card without blur', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: AppCard(child: Text('카드'))));
  expect(find.byType(BackdropFilter), findsNothing);
  final box = tester.widget<DecoratedBox>(find.descendant(of: find.byType(AppCard), matching: find.byType(DecoratedBox)).first);
  final deco = box.decoration as BoxDecoration;
  expect(deco.color, Colors.white);
  expect(deco.border, Border.all(color: AppColors.border));
  expect(deco.boxShadow, anyOf(isNull, isEmpty));
});

testWidgets('AppChoiceTile highlights when selected', (tester) async {
  await tester.pumpWidget(MaterialApp(home: AppChoiceTile(label: const Text('중1'), selected: true, onTap: () {})));
  final deco = tester.widget<DecoratedBox>(find.descendant(of: find.byType(AppChoiceTile), matching: find.byType(DecoratedBox)).first).decoration as BoxDecoration;
  expect(deco.color, AppColors.primarySoft);
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd flutter_app && flutter test test/widgets/app_card_test.dart`
Expected: FAIL (`BackdropFilter` 발견)

- [ ] **Step 3: `app_card.dart` 구현 후 테스트 통과 확인**

Run: `cd flutter_app && flutter test test/widgets/app_card_test.dart`
Expected: PASS

- [ ] **Step 4: 위 7개 화면에 바꾸는 규칙 적용**

Run: `cd flutter_app && grep -nE "GlassPanel\(|GlassButton\(|GlassField\(|GlassSunken\(|GlassChoice\(|GlassGlyph\(|GlassInfoRow\(" lib/screens/{analysis,practice,loop_result,upload,student_training,dashboard,student_hub}_screen.dart`
Expected: 출력 없음

- [ ] **Step 5: 화면 확인**

Run: `cd flutter_app && flutter run -d chrome --dart-define=DESIGN_REVIEW=analysis__result_weak` (같은 방법으로 `practice__question`, `practice__feedback_wrong`, `upload__idle`)
Expected: 콘텐츠는 흰 카드이고, 파란 채움 버튼은 화면당 하나다.

- [ ] **Step 6: 전체 테스트 후 커밋**

Run: `cd flutter_app && flutter test && flutter analyze lib`

```bash
git add flutter_app/lib/widgets/app_card.dart flutter_app/lib/screens flutter_app/test/widgets/app_card_test.dart
git commit -m "Move student-flow content off glass onto white cards."
```

---

### Task 8: 콘텐츠 유리 제거 마무리 (학부모·선생님·가입·설정), 유리 시트·팝업, 규칙 테스트

**Files:**
- Modify: `flutter_app/lib/screens/teacher_screens.dart`, `parent_screens.dart`, `parent_explain_screen.dart`, `settings_screen.dart`, `signup_screen.dart`, 그 밖에 남은 호출부(`grep`으로 찾기)
- Modify (시트·팝업 호출부): `loop_result_screen.dart`, `open_practice_flow.dart`, `practice_screen.dart`, `profile_onboarding_screen.dart`, `settings_screen.dart`, `widgets/edit_profile_sheet.dart`, `widgets/linked_children_panel.dart`, `widgets/parent_tab_scaffold.dart`, `widgets/student_picker.dart`
- Modify: `flutter_app/lib/widgets/glass.dart` (`GlassPanel`, `GlassButton`, `GlassField`, `GlassSunken`, `GlassChoice`, `GlassGlyph`, `GlassInfoRow`, `_GlassSurface` 삭제, 시트·팝업 추가)
- Test: `flutter_app/test/design_rules_test.dart`, `flutter_app/test/widgets/glass_sheet_test.dart`

**Interfaces:**
- Consumes: Task 7의 `AppCard`, `AppChoiceTile`, `AppGlyph`, `AppInfoRow`, 바꾸는 규칙 표
- Produces (`glass.dart`):
  - `Future<T?> showGlassSheet<T>({required BuildContext context, required WidgetBuilder builder, bool isScrollControlled = false})`: `showModalBottomSheet`에 투명 배경을 주고, 내용을 위쪽 모서리 26의 `GlassSurface(clear)`로 감싼다.
  - `GlassDialog({Key? key, Widget? title, Widget? content, List<Widget>? actions})`: `AlertDialog`와 같은 인자, 모서리 26의 맑은 유리 판. 호출부는 `AlertDialog(`을 `GlassDialog(`로 바꾸면 된다.

- [ ] **Step 1: 실패하는 규칙 테스트 작성**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content never uses glass widgets (spec 3장)', () {
    const banned = ['GlassPanel(', 'GlassButton(', 'GlassField(', 'GlassSunken(', 'GlassChoice(', 'GlassGlyph(', 'GlassInfoRow(',
        'showModalBottomSheet', 'AlertDialog('];
    final files = [
      ...Directory('lib/screens').listSync(recursive: true),
      ...Directory('lib/widgets').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.endsWith('glass.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final b in banned) {
        expect(src.contains(b), isFalse, reason: '${f.path} uses $b');
      }
    }
  });

  test('no blob atmosphere or wallpaper assets', () {
    final glass = File('lib/widgets/glass.dart').readAsStringSync();
    expect(glass.contains('RadialGradient'), isFalse);
    expect(Directory('assets/glass').existsSync(), isFalse);
  });
}
```

`glass_sheet_test.dart`:

```dart
testWidgets('glass sheet and dialog use the clear preset', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
    onPressed: () => showGlassSheet<void>(context: context, builder: (_) => const Text('시트 내용')),
    child: const Text('열기')))));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  expect(find.text('시트 내용'), findsOneWidget);
  expect(tester.widget<GlassSurface>(find.ancestor(of: find.text('시트 내용'), matching: find.byType(GlassSurface))).preset, GlassPreset.clear);

  await tester.pumpWidget(const MaterialApp(home: GlassDialog(title: Text('삭제할까요?'), content: Text('되돌릴 수 없어요.'))));
  expect(find.text('삭제할까요?'), findsOneWidget);
  expect(find.byType(GlassSurface), findsOneWidget);
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd flutter_app && flutter test test/design_rules_test.dart test/widgets/glass_sheet_test.dart`
Expected: FAIL (`teacher_screens.dart uses GlassPanel(` 등, `showGlassSheet` 정의 없음)

- [ ] **Step 3: 시트·팝업 헬퍼를 만들고 호출부 9곳을 바꾸기**

`showModalBottomSheet` → `showGlassSheet`, `AlertDialog(` → `GlassDialog(`. `lib/dev`는 규칙 테스트 대상이 아니므로 그대로 둔다.

- [ ] **Step 4: 남은 화면에 바꾸는 규칙 적용**

학부모·선생님 탭 화면과 설정은 탭 화면 규칙(연파랑 주 버튼)을 따르고, 가입 화면은 탭바 없는 화면 규칙(`GlassPrimaryButton`)을 따른다. 위젯 폴더(`learning_profile_widgets.dart`, `linked_children_panel.dart` 등)의 호출부도 바꾼다.

- [ ] **Step 5: `glass.dart`에서 콘텐츠용 위젯 삭제**

남는 위젯: `GlassSurface`, `GlassPrimaryButton`, `GlassCoachBubble`, `GlassScrollEdge`, `GlassTabBar`, `GlassAtmosphere`, `GlassCircleButton`, `GlassDialog`, `showGlassSheet`, `GlassTone`/`GlassPreset` 중 쓰이는 것.

- [ ] **Step 6: 통과 확인**

Run: `cd flutter_app && flutter test && flutter analyze lib`
Expected: `All tests passed!`, `error •` 없음

- [ ] **Step 7: 커밋**

```bash
git add flutter_app/lib flutter_app/test/design_rules_test.dart flutter_app/test/widgets/glass_sheet_test.dart
git commit -m "Finish moving content off glass and guard the rule with a source test."
```

---

### Task 9: 이어지는 정리 (색, PDF 폰트, 문서)

**Files:**
- Modify: `src/app/auth/magic/page.tsx`, `src/lib/email.ts`, `src/lib/sample.ts`
- Modify: `flutter_app/lib/utils/problem_set_pdf.dart:134`
- Modify: `flutter_app/pubspec.yaml` (Noto 등록 제거, 조건부)
- Delete: `flutter_app/assets/fonts/NotoSansKR-Variable.ttf` (조건부)
- Modify: `DESIGN.md`, `.cursor/rules/design.mdc`

- [ ] **Step 1: 웹 옛 색 교체**

`#5a6278` → `#494C4F`, `#949bb0` → `#999999`, `#007bff` → `#2A72E5`

Run: `grep -rniE "5a6278|949bb0|007bff" src`
Expected: 출력 없음

- [ ] **Step 2: PDF 오프라인 대체 폰트를 SUIT로**

`problem_set_pdf.dart`의 `rootBundle.load('assets/fonts/NotoSansKR-Variable.ttf')`를 `'assets/fonts/SUIT-Variable.ttf'`로 바꾼다.

- [ ] **Step 3: 오프라인 PDF 확인 (수동)**

1. 기기 네트워크를 끈다. 웹이면 Chrome DevTools에서 Offline으로 둔다.
2. 비슷한 문제 PDF를 만든다(`buildSimilarProblemsPdf`를 부르는 화면에서 PDF 저장).
3. 한글이 보통 굵기로 또렷하게 나오는지 본다.
   - 나오면: `pubspec.yaml`에서 `Noto Sans KR` 패밀리를 지우고 `NotoSansKR-Variable.ttf`를 삭제한다.
   - 깨지거나 너무 가늘면: 2단계를 되돌리고 Noto를 PDF 전용으로 남긴다. `pubspec.yaml`의 패밀리 등록만 지우고 파일은 `assets/fonts/`에 둔다.
4. 결과를 커밋 메시지에 적는다.

- [ ] **Step 4: 문서 갱신**

`DESIGN.md`와 `.cursor/rules/design.mdc`의 「Elevation & Depth」·「Patterns」 부분을 스펙 3·4·5·6.1장 요약으로 바꾼다.
- 유리 규칙 한 줄 + 표
- 버튼 3종
- 학생 탭바(홈 · 훈련 · [찍기] · 성장 · 설정)
- 홈 무대
- 금지 목록에 「콘텐츠 위 유리」, 「배경화면·번짐」 추가
- 스펙 경로를 링크한다.

- [ ] **Step 5: 확인 후 커밋**

Run: `cd flutter_app && flutter test && flutter analyze lib`

```bash
git add src flutter_app/lib/utils/problem_set_pdf.dart flutter_app/pubspec.yaml flutter_app/assets/fonts DESIGN.md .cursor/rules/design.mdc
git commit -m "Clean up legacy colors, PDF fallback font, and design docs for Liquid Glass."
```

---

### Task 10: 전체 확인

**Files:** 없음 (확인만)

- [ ] **Step 1: 자동 확인**

Run: `cd flutter_app && flutter analyze lib && flutter test`
Expected: `error •` 없음, `All tests passed!`

- [ ] **Step 2: iOS 시뮬레이터**

Run: `cd flutter_app && flutter run -d "iPhone 17" --dart-define=DESIGN_REVIEW=student_hub__first_visit` (같은 방법으로 `student_hub__returning`, `student_hub__guest`, `student_training__empty`, `student_progress__empty`)
Expected:
- 스크린샷이 시안과 같은 배치다.
- 스크롤하면 탭바와 상단 흐림 아래로 콘텐츠가 비친다.
- 마지막 줄이 탭바에 가리지 않는다.

- [ ] **Step 3: Android 에뮬레이터**

Step 2와 같은 키로 실행한다.
Expected: 유리 흐림이 보이고, 스크롤이 끊기지 않는다.

- [ ] **Step 4: 웹**

Run: `cd flutter_app && flutter run -d chrome --web-port 8080`, 이어서 `http://localhost:8080/?design_review=student_hub__first_visit`
Expected: 첫 프레임이 바로 그려진다(멈춤 없음).

- [ ] **Step 5: 실제 흐름**

로그인한 학생으로 가운데 카메라를 누르면 업로드 화면이 전체 화면으로 열린다. 사진을 올리고 돌아오면 홈이 「다시 왔을 때」로 바뀐다.
