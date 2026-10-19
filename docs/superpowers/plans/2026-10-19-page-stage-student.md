# 탭 화면 파란 무대 1단계 (학생 탭) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 학생 탭 중 홈을 뺀 훈련·성장·설정 위쪽에 홈과 같은 파란 무대를 깐다. 같은 코드를 쓰는 학부모 진도 탭과 학부모·선생님 설정 탭도 함께 바뀐다. 밀어서 여는 화면(분석, 풀이, 업로드, 세트 결과, 학습 통계 등)은 건드리지 않는다.

**Architecture:**
- 새 파일 `lib/widgets/page_stage.dart` 하나에 무대를 모은다.
  - 그림: 배경, 글자 스타일, 무대용 유리 카드·칸·알약·원 버튼, `PageStage.tab`.
  - 스크롤 틀: `StageFrame`(스크롤을 지켜 상태바 흐림 띠를 보임), `StageListView`(무대 + 무대 아래 목록 여백).
- 탭 화면은 `GlassSurface(`를 직접 쓰지 않고 이 부품만 쓴다. 디자인 규칙 허용 목록에는 `page_stage.dart` 하나만 더한다.
- 상태바 글자색은 `AnnotatedRegion`으로 정한다. 무대가 흰색, 틀이 검정이다. 무대가 상태바 밑에서 빠지면 저절로 검정이 된다.

**Tech Stack:** Flutter (Dart SDK ^3.11.5), `flutter_test`. 새 패키지 없음. 서버·API 변경 없음.

**Spec:** `docs/superpowers/specs/2026-10-19-page-stage-design.md` (1단계 = 2장, 3.1장, 3.2·3.3의 「1단계」 표시 줄, 4장, 7장). 2단계(학부모·선생님 전용 탭)는 이 계획에 없다.

## Global Constraints

- **무대 배경**: `AppGradients.stage`(165° `#5EB7EB` → `#2A72E5` → `#1E46AA`), 아래 모서리 32, 번짐 장식 없음. 무대는 콘텐츠와 함께 스크롤된다.
- **여백과 글자**
  - 위 = 안전 영역 + 14, 좌우 18, 아래 24.
  - 제목 24/700 흰색 + 홈 인사와 같은 그림자.
  - 설명 13.5/600 흰색 86%.
- **버튼**
  - 무대 위 주 버튼: `AppButtonStyles.white()`.
  - 무대 아래 주 버튼: `AppButtonStyles.soft()`.
  - 떠 있는 층(탭바, 시트, 팝업) 규칙은 그대로.
- **유리**
  - 무대 위 카드·칸·알약·원은 무대용 유리(`GlassPreset.onBlue`). 무대 아래는 흰 카드(`AppCard`).
  - `GlassSurface(`는 `glass.dart`와 허용 목록 파일에서만 쓴다. `BackdropFilter(`는 `glass.dart`에서만 쓴다.
- **아이콘**: `AppIcons`(MingCute)만 쓴다.
- **문구**
  - 무대로 올리는 문구와 숫자는 그 탭이 지금 보여주는 것만 쓴다. 이 계획이 따옴표로 적은 문자열만 예외다.
  - 해요체. 새 문구에 「AI」·「맞춤 추천」·「대시보드」를 쓰지 않는다.
- **불러오는 중·오류·빈 상태**
  - 무대(제목·설명)는 항상 그린다. 스켈레톤·오류·빈 안내는 무대 아래.
  - 데이터가 와야 생기는 유리 칸은 데이터가 올 때까지 그리지 않는다. 0으로 채우지 않는다.
- **건드리지 않는 화면**
  - 밀어서 여는 화면: `analysis_screen.dart`, `practice_screen.dart`, `upload_screen.dart`, `loop_result_screen.dart`, `dashboard_screen.dart`, `practice_generating_screen.dart`, `link_student_screen.dart`, `parent_explain_screen.dart`의 상세 화면.
  - 학부모·선생님 전용 탭(2단계).
  - 로그인·가입·온보딩·막는 화면: 다른 세션이 같은 작업 트리에서 작업 중이다.
- **커밋**
  - 모든 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - `.cursor/debug-6366de.log`는 커밋하지 않는다. 푸시하지 않는다.
  - 시뮬레이터 빌드 뒤 `flutter_app/ios/Podfile`, `Podfile.lock`, `Runner.xcodeproj/project.pbxproj` 변경은 되돌린다.

## Review Focus

1. **긴 값과 큰 글자**: 긴 이름·학교, 긴 자녀 이름, 훈련 카드의 긴 개념 줄이 폭 320, 글자 1.3배에서도 넘치지(overflow) 않고 말줄임(…)으로 끝나야 한다. → Task 1, Task 6 테스트
2. **태블릿 폭**: 폭 1024에서 무대는 화면 끝까지 차고, 무대 아래 내용은 `TabletLayout.maxContentWidth` 안에 가운데로 모인다. → Task 2 테스트
3. **탭바에 가려지는 마지막 줄**: 무대를 얹은 뒤에도 각 탭의 마지막 줄이 떠 있는 탭바 위로 스크롤되어 보여야 한다. → Task 2 테스트
4. **당겨서 새로고침**: 무대가 맨 위에 있어도 훈련·성장 탭을 아래로 당기면 다시 불러온다. → Task 4, Task 5 테스트
5. **상태바 글자**: 무대 위에서는 흰색, 무대가 지나가면 검정. → Task 1, Task 2 테스트

---

### Task 1: 무대 부품 (`page_stage.dart`)

**Files:**
- Create: `flutter_app/lib/widgets/page_stage.dart`
- Modify:
  - `flutter_app/lib/widgets/home_stage.dart`: 배경·그림자를 공유하고 `_stageTextShadows`를 지운다.
  - `flutter_app/lib/screens/student_hub_screen.dart`: `_StatTile` → `StageTile`.
  - `flutter_app/test/design_rules_test.dart`: 허용 목록에 `page_stage.dart`를 더한다.
- Test: `flutter_app/test/widgets/page_stage_test.dart`

**Interfaces:**
- Produces (모두 `page_stage.dart`):
  - `const List<Shadow> kStageTextShadows`: 지금 `home_stage.dart`의 `_stageTextShadows`와 같은 값.
  - `abstract final class StageText`:
    - `Color sub = Color(0xDBFFFFFF)`, `Color muted = Color(0xCCFFFFFF)`
    - `TextStyle title`: 24/700 흰색 + 그림자
    - `TextStyle subtitle`: 13.5/600 `sub` + 그림자
    - `TextStyle eyebrow`: 12.5/700 `muted`
    - `TextStyle body`: 14/600, 높이 1.45, 흰색
    - `TextStyle cardTitle`: 18/700, 높이 1.35, 흰색
  - `StageBackground({required Widget child})`: 그라데이션 + 아래 모서리 32. `HomeStage`도 이걸 쓴다.
  - `StageGlass({required Widget child, BorderRadius borderRadius = 알약, EdgeInsetsGeometry padding = EdgeInsets.zero})`: `GlassSurface(preset: GlassPreset.onBlue)`를 감싼다.
  - `StageCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(18)})`: `StageGlass`, 모서리 `AppRadii.lg`.
  - `StageTile({required String label, required String value})`: 홈 `_StatTile`과 같은 모양. 라벨 12/700 `muted`, 값 26/800 한 줄 말줄임, `MergeSemantics`.
  - `StageTileRow({required List<StageTile> tiles})`: `Expanded` 칸, 사이 `AppSpacing.md`.
  - `StagePill({required String label, required bool selected, required VoidCallback onTap})`
    - 높이 40, 좌우 14, 13/700.
    - 고른 것: 흰 바탕 + `AppColors.primaryDark` 글자, 유리 없음.
    - 아닌 것: `StageGlass` + 흰 글자.
    - `Semantics(button: true, selected: selected)`.
  - `StageCircleButton({required IconData icon, required String tooltip, required VoidCallback onPressed})`: 지름 36 원형 `StageGlass`, 흰 아이콘 20.
  - `PageStage.tab({required String title, String? subtitle, Widget? trailing, List<Widget> children = const []})`
    - `AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light)`로 자신을 감싼다.
    - 배치: 위 = 안전 영역 + 14, 좌우 18, 아래 24.
    - 제목 줄 = `Row[Expanded(제목(한 줄 말줄임) + 4 + 설명(최대 2줄 말줄임)), trailing]`.
    - `children`은 위 16, 사이 12, 무대 폭을 꽉 채운다.

- [ ] **Step 1: 실패하는 테스트 작성** (`test/widgets/page_stage_test.dart`)

```dart
testWidgets('tab stage: title, subtitle, blue background, light status bar', (t) async {
  await t.pumpWidget(_host(const PageStage.tab(title: '훈련', subtitle: '막힌 개념만 모아서 다시 풀어봐요'),
      topInset: 47));
  final title = t.widget<Text>(find.text('훈련'));
  expect(title.style!.fontSize, 24);
  expect(title.style!.fontWeight, FontWeight.w700);
  expect(title.style!.color, Colors.white);
  expect(t.getTopLeft(find.text('훈련')).dy, greaterThanOrEqualTo(47 + 14));
  final deco = t.widget<DecoratedBox>(find.descendant(
      of: find.byType(StageBackground), matching: find.byType(DecoratedBox)).first).decoration as BoxDecoration;
  expect(deco.gradient, AppGradients.stage);
  expect(deco.borderRadius, const BorderRadius.vertical(bottom: Radius.circular(32)));
  expect(find.byWidgetPredicate((w) =>
      w is AnnotatedRegion<SystemUiOverlayStyle> && w.value == SystemUiOverlayStyle.light),
      findsOneWidget);
});

testWidgets('tiles, pills, circle button: glass on blue, selected pill is white', (t) async {
  var taps = 0;
  await t.pumpWidget(_host(PageStage.tab(
    title: '내 진도',
    trailing: StageCircleButton(icon: AppIcons.chart, tooltip: '학습 통계', onPressed: () => taps++),
    children: [
      const StageTileRow(tiles: [StageTile(label: '정답률', value: '72%'), StageTile(label: '풀 문제', value: '5개')]),
      StagePill(label: '중1', selected: true, onTap: () {}),
      StagePill(label: '중2', selected: false, onTap: () {}),
    ],
  )));
  final tileGlass = find.descendant(of: find.byType(StageTile), matching: find.byType(GlassSurface));
  expect(tileGlass, findsNWidgets(2));
  expect(t.widget<GlassSurface>(tileGlass.first).preset, GlassPreset.onBlue);
  expect(t.widget<Text>(find.text('중1')).style!.color, AppColors.primaryDark);
  expect(t.widget<Text>(find.text('중2')).style!.color, Colors.white);
  expect(find.descendant(of: find.widgetWithText(StagePill, '중1'),
      matching: find.byType(GlassSurface)), findsNothing);
  await t.tap(find.byTooltip('학습 통계'));
  expect(taps, 1);
});

testWidgets('long title and subtitle ellipsize at 320 wide with 1.3x text', (t) async {
  t.view.physicalSize = const Size(960, 2400); t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(_host(PageStage.tab(
    title: '김가나다라마바사아자차카타파하님의 아주 긴 제목',
    subtitle: '서울특별시립한빛국제중학교 · 중1 · ' * 4,
    trailing: StageCircleButton(icon: AppIcons.chart, tooltip: '학습 통계', onPressed: () {}),
    children: const [StageTileRow(tiles: [StageTile(label: '끝낸 단원', value: '120 / 135'), StageTile(label: '정답률', value: '100%')])],
  ), textScale: 1.3));
  expect(t.takeException(), isNull);
});
```
`_host(child, {topInset = 0, textScale = 1})`는 `MaterialApp(home: MediaQuery(위 안전 영역, textScaler) → Scaffold(body: SingleChildScrollView(child)))`.

- [ ] **Step 2: 실패 확인**

Run: `cd flutter_app && flutter test test/widgets/page_stage_test.dart`
Expected: FAIL (`page_stage.dart` 없음)

- [ ] **Step 3: `page_stage.dart` 구현**
위 Interfaces 그대로 만든다. 그 다음:
- `HomeStage`가 `StageBackground`와 `kStageTextShadows`를 쓰게 한다. 홈 동작·모양은 바꾸지 않는다.
- 홈의 `_StatTile` 두 개를 `StageTile`로 바꾼다. 라벨·값은 그대로다. `_StatTile` 클래스를 지운다.
- `design_rules_test.dart`의 `_glassSurfaceAllowlist`에 이 줄을 더한다: `'lib/widgets/page_stage.dart': '탭 화면 위 파란 무대: 무대 카드·칸·알약·원이 파란 바탕을 비춘다'`.

- [ ] **Step 4: 통과 확인**

Run: `cd flutter_app && flutter test test/widgets/page_stage_test.dart test/widgets/home_stage_test.dart test/screens/student_hub_test.dart test/design_rules_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: 커밋**

```bash
git add flutter_app/lib/widgets/page_stage.dart flutter_app/lib/widgets/home_stage.dart flutter_app/lib/screens/student_hub_screen.dart flutter_app/test/widgets/page_stage_test.dart flutter_app/test/design_rules_test.dart
git commit -m "Add the shared blue stage parts and use them on home."
```

---

### Task 2: `StageFrame`과 `StageListView`

**Files:**
- Modify: `flutter_app/lib/widgets/page_stage.dart`
- Test: `flutter_app/test/widgets/stage_frame_test.dart`

**Interfaces:**
- Consumes: Task 1의 `PageStage`.
- Produces:
  - `StageFrame({required Widget child})`
    - `AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.dark)`가 `Stack[NotificationListener(child), Positioned(top: 0, left: 0, right: 0) GlassStatusBarBand(visible: scrolled)]`를 감싼다.
    - `scrolled` = 깊이 0, 세로 스크롤 `pixels > 8`(홈 `_kScrolledThreshold`와 같은 값).
  - `StageListView({required Widget stage, required List<Widget> children, ScrollPhysics physics = const AlwaysScrollableScrollPhysics()})`
    - `ListView(padding: EdgeInsets.only(bottom: TabletLayout.pagePadding(context).bottom))`
    - 자식 순서: `stage` → `SizedBox(height: AppSpacing.xl)` → `children`.
    - `children` 각 줄은 좌우 `TabletLayout.pageHorizontalPadding`, 폭 상한 `TabletLayout.maxContentWidth`, 가운데 정렬. 무대는 화면 폭 전체.
  - `EdgeInsets stageBodyPadding(BuildContext context)`: 좌우 = `pageHorizontalPadding`, 위 = `AppSpacing.xl`, 아래 = `pagePadding.bottom`. `CustomScrollView`를 쓰는 화면용.

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
testWidgets('frame shows the status-bar band after scrolling; frame region is dark', (t) async {
  await t.pumpWidget(_frame(rows: 40, topInset: 47));
  expect(t.widget<GlassStatusBarBand>(find.byType(GlassStatusBarBand)).visible, isFalse);
  await t.drag(find.byType(ListView), const Offset(0, -200)); await t.pumpAndSettle();
  expect(t.widget<GlassStatusBarBand>(find.byType(GlassStatusBarBand)).visible, isTrue);
  expect(find.byWidgetPredicate((w) =>
      w is AnnotatedRegion<SystemUiOverlayStyle> && w.value == SystemUiOverlayStyle.dark),
      findsOneWidget);
});

testWidgets('tablet: stage is full width, body is capped and centered', (t) async {
  t.view.physicalSize = const Size(2048, 1536); t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(_frame(rows: 3));
  expect(t.getSize(find.byType(PageStage)).width, 1024);
  final row = t.getRect(find.byKey(const Key('row-0')));
  expect(row.width, lessThanOrEqualTo(TabletLayout.maxContentWidth(t.element(find.byType(ListView)))));
  expect((row.center.dx - 512).abs(), lessThan(1));
});

testWidgets('last row scrolls above a floating tab bar', (t) async {
  // extendBody 탭바가 body에 넘기는 아래 여백(126 = 30 + 72 + 24)을 흉내 낸다.
  await t.pumpWidget(_frame(rows: 30, bottomInset: 126, size: const Size(390, 844)));
  await t.drag(find.byType(ListView), const Offset(0, -5000)); await t.pumpAndSettle();
  expect(t.getRect(find.byKey(const Key('row-29'))).bottom, lessThanOrEqualTo(844 - 126));
});
```
헬퍼 `_frame`은 `StageFrame(child: StageListView(stage: const PageStage.tab(title: '훈련'), children: [for i: SizedBox(key: Key('row-$i'), height: 80)]))`를 `MediaQuery`(위·아래 안전 영역)와 `Scaffold` 안에 넣는다.

- [ ] **Step 2: 실패 확인**: `cd flutter_app && flutter test test/widgets/stage_frame_test.dart` → FAIL
- [ ] **Step 3: `StageFrame`, `StageListView`, `stageBodyPadding` 구현** (`page_stage.dart`)
- [ ] **Step 4: 통과 확인**: 같은 명령 → `All tests passed!`
- [ ] **Step 5: 커밋**

```bash
git add flutter_app/lib/widgets/page_stage.dart flutter_app/test/widgets/stage_frame_test.dart
git commit -m "Add the stage frame and the list that sits under a stage."
```

---

### Task 3: 무대용 학년 알약과 자녀 고르기

**Files:**
- Modify:
  - `flutter_app/lib/widgets/learning_profile_widgets.dart`: `GradeBandTabBar`, 413-471줄 근처.
  - `flutter_app/lib/widgets/student_picker.dart`
- Test:
  - `flutter_app/test/widgets/grade_band_tab_bar_test.dart`: 테스트를 더한다.
  - `flutter_app/test/widgets/student_picker_stage_test.dart`: 새 파일.

**Interfaces:**
- Consumes: `StagePill`, `StageGlass`, `StageText`.
- Produces:
  - `GradeBandTabBar({…, bool onStage = false})`: `onStage`면 각 칸을 `StagePill`로 그린다. 높이 40, 가로 스크롤, 간격 8은 그대로.
  - `StudentPicker({…, bool onStage = false})`
    - `onStage`면 칩을 `StageGlass`(모서리 `AppRadii.lg`, 높이 `AppSizes.buttonHeight`)로 그린다. 이름은 흰색 15/800 한 줄 말줄임, 꺾쇠는 `StageText.sub`.
    - 자녀 추가는 지름 `AppSizes.buttonHeight`의 원형 `StageGlass` 안 흰 `AppIcons.personAdd`로 그린다.
    - 시트를 여는 동작, 고르는 방식, 아바타는 그대로.

- [ ] **Step 1: 실패하는 테스트**
- `GradeBandTabBar(onStage: true, selectedIndex: 3)`:
  - '중1' 글자색은 `AppColors.primaryDark`, 바탕은 흰색.
  - '중2'는 `GlassSurface(preset: onBlue)` 안에 있고 글자는 흰색.
  - semantics(selected 표시) 검사가 `onStage`에서도 통과한다.
- `StudentPicker(onStage: true)`, 자녀 둘('지민', '서준'), `apiClient` 있음:
  - '지민' 글자는 흰색이고 칩 조상에 `GlassSurface`가 있다.
  - 자녀 추가 아이콘 색은 흰색.
  - 칩을 누르면 시트가 열린다. '서준'을 누르면 `authSession.viewAsStudentId`가 서준 id로 바뀌고 `onChanged`가 한 번 불린다.
- 긴 자녀 이름(30자), 폭 320, 글자 1.3배: 예외 없음.
- 기본값(`onStage: false`)일 때 기존 테스트가 그대로 통과한다.

- [ ] **Step 2: 실패 확인**: `cd flutter_app && flutter test test/widgets/grade_band_tab_bar_test.dart test/widgets/student_picker_stage_test.dart` → FAIL
- [ ] **Step 3: `onStage` 구현**
- [ ] **Step 4: 통과 확인**: 같은 명령 + `flutter test test/screens/floating_layer_test.dart` → 통과
- [ ] **Step 5: 커밋**: `git commit -m "Give grade pills and the child picker an on-stage look."`

---

### Task 4: 훈련 탭

**Files:**
- Modify:
  - `flutter_app/lib/screens/student_training_screen.dart`
  - `flutter_app/test/screens/empty_states_test.dart`: 훈련 부분.
  - `flutter_app/test/screens/student_flow_surfaces_test.dart`: 282-303줄.
- Test: `flutter_app/test/screens/training_stage_test.dart`

**Interfaces:**
- Consumes: `StageFrame`, `StageListView`, `stageBodyPadding`, `PageStage.tab`, `StageCard`, `StageTileRow`, `StageTile`, `StageText`.
- Produces: `int feedProblemCount(TrainingFeedResponse feed)` = `feed.items`의 `problemCount` 합. 같은 파일 top-level에 둔다.

**바뀐 뒤**
- 화면 전체를 `StageFrame`으로 감싼다. `GlassScrollEdge`, `_scrolled`, `_onScroll`, `_scrollEdgeThreshold`는 지운다. `RefreshIndicator`는 그대로 둔다(`StageListView` / `CustomScrollView`를 감싼다).
- 무대: `PageStage.tab(title: '훈련', subtitle: '막힌 개념만 모아서 다시 풀어봐요')`. `_TrainingHeader`는 지운다.
- 무대 카드(`StageCard`)는 지금 위쪽 분기 그대로 고른다. 순서대로 처음 맞는 줄을 쓴다.

| 조건 | 카드 내용 | 흰 주 버튼 |
|------|-----------|------------|
| A. `available && activeSetId != null && remainingCount > 0` | eyebrow: `focusConcepts.take(3).join(' · ')`(비면 생략)<br>`cardTitle`: 지금 히어로 메시지(`training.headline` → 「이름님, 막힌 개념으로 문제를 준비했어요.」 → 「막힌 개념으로 문제를 준비했어요.」)<br>`body`: 「누적 오답 N건」(N > 0일 때), 「틀렸던 개념 문제 · N개 남음」 | 「이어서 복습하기」 → `_startTraining` |
| B. `available` | A와 같되 남은 줄 없음 | `FilledButton.icon(AppIcons.play, '5문제 세트로 복습')` → `_startTraining` |
| C. `!available && feed.items.isNotEmpty` | `cardTitle`: 「풀 문제 N개가 준비됐어요」(N = `feedProblemCount`) | 없음 |
| D. `training.hasLearningData` | `cardTitle`: 「막힌 문제를 다 풀었어요.」 / `body`: 「새로 막히면 여기에 모여요.」 | 없음 |
| E. 그 밖 | `cardTitle`: 「아직 훈련할 문제가 없어요」 / `body`: 「숙제를 찍으면 막힌 개념이 여기에 모여요.」 | 없음 |

- 카드 본문에 「재학습 성공」·「다시 맞힘」 숫자를 쓰지 않는다.
- 유리 칸(`StageTileRow`)은 `training.hasLearningData || feed.items.isNotEmpty`일 때만 카드 아래에 그린다.
  - `StageTile(label: '풀 문제', value: '${feedProblemCount(feed)}개')`
  - `StageTile(label: '다시 맞힘', value: '${training.relearnedCount}건')`
- 무대 아래(A·B·C):
  - `feed.refreshPending`이면 `_FeedStatusChip`.
  - `SectionLabel('풀 문제')`(지금 「맞춤 문제」 라벨을 바꾼다) + 피드 카드(그대로).
  - 「훈련 대상」 + `_TrainingFocusList`.
- 지울 것: `_TrainingHeroCard`, `_ContinueTrainingCard`, 본문의 「5문제 세트로 복습」 버튼.
- D: 무대 아래 내용 없음.
- E(빈 상태):
  - `CustomScrollView(AlwaysScrollable)[SliverToBoxAdapter(무대), SliverPadding(stageBodyPadding) → SliverFillRemaining(hasScrollBody: false)]`.
  - 그 안에 지금의 「이런 식으로 쌓여요 · 예시」 줄 두 개, `Spacer`, 「가운데 카메라로 시작해요」. `_TrainingEmptyState` 안의 연필 원 카드는 지운다(무대 카드로 옮김).
- 불러오는 중: 같은 무대(제목·설명만) + 무대 아래 `_TrainingHeroCardSkeleton`, 버튼 높이 `SkeletonBox`, `SectionLabel('풀 문제')`, 피드 카드 스켈레톤 3개.
- 오류: 같은 무대 + 무대 아래 `ProfileLoadingError`. 당겨서 새로고침이 되도록 `StageListView` 안에 둔다.

- [ ] **Step 1: 실패하는 테스트** (`training_stage_test.dart`)
- 화면은 `demoProfile`/`demoFeed`로 띄운다. `training`·피드 값은 JSON 픽스처로 만든다.
- B:
  - `find.descendant(of: find.byType(PageStage), matching: find.text('5문제 세트로 복습'))` → 하나.
  - 그 `FilledButton`의 `style.backgroundColor` = 흰색, `foregroundColor` = `AppColors.primary`.
  - '누적 오답 4건'은 무대 안에 있다. '재학습 성공'은 없다.
  - '풀 문제' 칸 '3개'(`problemCount` 1+2), '다시 맞힘' 칸 '2건'.
  - `SectionLabel` '풀 문제'는 `PageStage` 밖에 있다.
- A: '이어서 복습하기' 흰 버튼과 '틀렸던 개념 문제 · 2개 남음'이 무대 안에 있다. '5문제 세트로 복습'은 없다.
- C: 무대 안에 '풀 문제 3개가 준비됐어요'.
- D: 무대 안에 '막힌 문제를 다 풀었어요.'. `StageTile`이 둘 있다.
- E:
  - 무대 안에 '아직 훈련할 문제가 없어요'.
  - '가운데 카메라로 시작해요'는 `PageStage` 밖에 있다.
  - `StageTile`은 없다.
- 불러오는 중(첫 프레임, 응답을 `Completer`로 붙잡음): 무대 안 '훈련' 하나, `SkeletonBox`가 있다, `StageTile`은 없다.
- 새로고침: API 호출 수를 세는 가짜 `ApiClient`로 띄운 뒤 `t.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000)` → `pumpAndSettle` → `getLearningProfile` 호출이 하나 늘어난다.
- `GlassScrollEdge`는 없다.

`empty_states_test.dart`:
- 설명 문구 검사(100, 167, 248줄)를 '막힌 개념만 모아서 다시 풀어봐요'로 바꾼다.
- 171-175줄 `GlassScrollEdge` 검사와 254-273줄 스크롤 가장자리 검사를 `GlassStatusBarBand` visible 검사로 바꾼다(false → 끌어올린 뒤 true).
- 그 밖의 문구 검사는 그대로.

`student_flow_surfaces_test.dart` 282-303줄:
- 「5문제 세트로 복습」 기대를 흰 바탕 + `AppColors.primary` 글자로 바꾼다.
- `GlassPrimaryButton` 없음은 그대로.

- [ ] **Step 2: 실패 확인**: `cd flutter_app && flutter test test/screens/training_stage_test.dart` → FAIL
- [ ] **Step 3: 훈련 탭 구현**
- [ ] **Step 4: 통과 확인**: `cd flutter_app && flutter test test/screens/training_stage_test.dart test/screens/empty_states_test.dart test/screens/student_flow_surfaces_test.dart test/screens/chip_contrast_test.dart` → 통과
- [ ] **Step 5: 커밋**: `git commit -m "Put the training tab on the blue stage."`

---

### Task 5: 성장 탭 (학생 + 학부모 진도)

**Files:**
- Modify:
  - `flutter_app/lib/screens/student_progress_screen.dart`
  - `flutter_app/test/screens/empty_states_test.dart`: 성장 부분, 279-367줄.
- Test: `flutter_app/test/screens/progress_stage_test.dart`

**Interfaces:**
- Consumes: `StageFrame`, `StageListView`, `PageStage.tab`, `StageTileRow`, `StageTile`, `StageCircleButton`, `GradeBandTabBar(onStage: true)`, `StudentPicker(onStage: true)`.
- Produces: `({int done, int total}) finishedUnits(List<CurriculumUnitProgress> unitsInBand)`. `done`은 `percent >= 100`인 단원 수, `total`은 목록 길이. 같은 파일 top-level에 둔다.

**바뀐 뒤**
- 학생 보기:
  - 짜임새: `StageFrame(child: RefreshIndicator(StageListView(stage: PageStage.tab(…), children: [기존 단원 목록, 미션 블록])))`.
  - 제목 '내 진도'.
  - 설명: 시작 전이면 '숙제를 찍으면 그 단원부터 채워져요.', 아니면 '2022 개정 교육과정 · ${gradeBandLabels[gradeTab]}'. 시작 전 = 지금 `_ProgressIntroCard`를 띄우던 조건.
  - trailing = `StageCircleButton(icon: AppIcons.chart, tooltip: '학습 통계', onPressed: () => DashboardScreen.open(context, apiClient))`.
  - `children` = `GradeBandTabBar(onStage: true, …)` → `StageTileRow`:
    - `StageTile('끝낸 단원', '$done / $total')`. 고른 학년 구간의 단원으로 `finishedUnits`를 쓴다.
    - `StageTile('정답률', accuracy > 0 ? '$accuracy%' : '시작 전')`. 홈 정답률 칸과 같은 규칙이고, 값은 `profile.stats.accuracy`다.
  - 지울 것: `_ProgressIntroCard`, `GlassScrollEdge`·스크롤 감시 코드, 본문의 제목 줄과 `IconButton`.
- 학부모 보기(`viewAsGuardian`):
  - 같은 짜임새로 그리고 `ParentLinkedScrollView`는 쓰지 않는다.
  - 제목 '교육과정 진도', 설명 '단원을 눌러 자녀에게 어떻게 도와줄지 확인하세요'.
  - trailing tooltip은 '학생 학습 통계'.
  - `children` 맨 앞에 `StudentPicker(onStage: true, apiClient: …, onChanged: 다시 불러오기)`.
  - 단원 탭 동작(부모 가이드)은 그대로.
  - `GuardianLearningGate` 감싸기와 자녀가 없을 때의 화면은 그대로 둔다(2단계).
- 불러오는 중: 같은 무대(제목·설명만, 알약·칸 없음) + 무대 아래 스켈레톤 상자(지금 `ProfileLoadingView`와 같은 모양). '진도 불러오는 중' 제목은 쓰지 않는다. `ProfileLoadingView` 자체는 그대로 둔다(다른 곳에서 쓸 수 있음).
- 오류: 무대 + 무대 아래 `ProfileLoadingError`.

- [ ] **Step 1: 실패하는 테스트**
- `designReviewProfileGradeM1()`, 탭 3:
  - 무대 안에 '내 진도', '2022 개정 교육과정 · 중1', `GradeBandTabBar`, tooltip '학습 통계'.
  - '끝낸 단원' 칸 값이 픽스처의 중1 구간을 `finishedUnits`로 센 값과 같다.
  - '정답률' 칸이 `stats.accuracy`에서 나온 값과 같다.
- `designReviewProfileFirstVisit()`, 탭 3:
  - 무대 설명 '숙제를 찍으면 그 단원부터 채워져요.'.
  - '끝낸 단원' 값 '0 / 9'.
  - '0 / 9 단원'은 없다.
- 학부모 보기, 자녀 둘:
  - '지민'이 `PageStage` 안에 있다.
  - '교육과정 진도'가 있고 '내 진도'는 없다.
  - tooltip '학생 학습 통계'가 있다.
- '학습 통계'를 누르면 `DashboardScreen`이 push된다.
- 불러오는 중: 무대 안 '내 진도' 하나, '진도 불러오는 중' 없음, `StageTile` 없음.
- 새로고침: 가짜 `ApiClient`로 당기면 `getLearningProfile` 호출이 하나 늘어난다.
- `empty_states_test.dart` 성장 검사(279-367줄)를 위 문구와 `GlassStatusBarBand` 검사로 맞춘다.

- [ ] **Step 2: 실패 확인**: `cd flutter_app && flutter test test/screens/progress_stage_test.dart` → FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인**: `cd flutter_app && flutter test test/screens/progress_stage_test.dart test/screens/empty_states_test.dart test/widgets/grade_band_tab_bar_test.dart` → 통과
- [ ] **Step 5: 커밋**: `git commit -m "Put the growth tab on the blue stage."`

---

### Task 6: 설정 탭

**Files:**
- Modify:
  - `flutter_app/lib/screens/settings_screen.dart`
  - `flutter_app/test/screens/floating_layer_test.dart`: 130-134줄.
- Test: `flutter_app/test/screens/settings_stage_test.dart`

**Interfaces:**
- Consumes: `StageFrame`, `StageListView`, `PageStage.tab`, `StageCard`, `StageText`, `StudentPicker(onStage: true)`.

**바뀐 뒤**
- 짜임새: `StageFrame(child: StageListView(stage: PageStage.tab(title: '설정', children: […]), children: […]))`.
- `user`·`isGuest`·`studentCode`는 `ListenableBuilder` 안에서 읽는다(무대가 세션 변화를 따라가게).
- 무대 `children` 순서:
  1. 학부모이고 연결된 자녀가 있으면 `StudentPicker(onStage: true, apiClient: …, onChanged: setState)`. 조건은 지금과 같다.
  2. 프로필 줄 `Row`:
     - `ProfileAvatar`(크기 64). 편집 표시·`onTap` 조건·올리는 중 표시는 지금과 같다.
     - 이름: 흰색 20/700, 한 줄 말줄임.
     - 그 아래 '학년 · 학교': `StageText.subtitle`, 한 줄 말줄임. 빈 값은 빼고, 둘 다 없으면 줄을 숨긴다.
  3. 게스트가 아니고 로그인했으면 흰 작은 버튼 `FilledButton.icon(AppIcons.edit, '기본 정보 수정')` → `_openEditProfile`.
     - 스타일: `AppButtonStyles.white().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 36)), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)))`.
     - 왼쪽 정렬.
  4. 학생이면 `StageCard`:
     - 라벨 '학생 코드'(`StageText.eyebrow`).
     - 코드: 흰 22/800, 자간 1.2, 눌러서 복사.
     - 도움말 '탭하거나 복사해서 학부모·교사에게 보내주세요.'(`StageText.subtitle`).
     - 흰 작은 버튼 「복사」 → `_copyStudentCode`. 스타일은 3번과 같다.
     - 불러오는 중이면 흰색 `LinearProgressIndicator`. 코드가 없으면 지금의 두 문구 중 하나(`StageText.body`).
- 무대 아래 첫 줄: 역할 칩 하나(`user?.role?.label ?? '역할 미설정'`, 지금 `_SettingsProfileChip` 모양). 게스트면 그 아래 지금의 게스트 안내 상자.
- 그 아래(학생 연결 관리, 학습, 알림, 로그아웃, 계정 탈퇴)는 그대로.
- 지울 것: 지금의 '설정' 제목 텍스트, 맨 위 `StudentPicker`, 프로필 `AppCard`, 학생 코드 `AppCard`.

- [ ] **Step 1: 실패하는 테스트**
- 학생, 로그인, 코드 있음:
  - 무대 안에 '설정', 이름, '중1 · 한빛중학교', '학생 코드', 코드 문자열, `FilledButton` '복사'(흰 바탕), `FilledButton` '기본 정보 수정'.
  - 역할 칩 '학생'은 무대 밖에 있다.
- '복사'를 누르면 '학생 고유번호가 복사되었습니다.' 스낵바가 뜬다.
- 게스트: '로그인하지 않은 게스트 모드입니다.'가 무대 밖에 있다. '기본 정보 수정'이 없다.
- 학부모, 자녀 둘: `StudentPicker`가 무대 안에 있다. '학생 코드'가 없다.
- 긴 이름(20자)과 긴 학교 이름, 폭 320, 글자 1.3배: 예외 없음.
- `floating_layer_test.dart` 130-134줄: 「기본 정보 수정」 시트의 유리 개수를 시트 안으로 좁혀 센다. `find.descendant(of: find.byType(BottomSheet), matching: find.byType(GlassSurface))` → findsOneWidget. 이제 무대에도 유리가 있기 때문이다.

- [ ] **Step 2: 실패 확인**: `cd flutter_app && flutter test test/screens/settings_stage_test.dart` → FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인**: `cd flutter_app && flutter test test/screens/settings_stage_test.dart test/screens/floating_layer_test.dart` → 통과
- [ ] **Step 5: 커밋**: `git commit -m "Put the settings tab on the blue stage."`

---

### Task 7: 디자인 리뷰 키와 문서

**Files:**
- Modify:
  - `flutter_app/lib/dev/design_review_shell.dart`
  - `flutter_app/lib/dev/design_review_data.dart`
  - `DESIGN.md`
  - `.cursor/rules/design.mdc`
  - `docs/superpowers/specs/2026-10-17-liquid-glass-renewal-design.md`

**리뷰 셸**
- 훈련·성장 키도 홈처럼 `SafeArea` 없이 `Scaffold(backgroundColor: AppColors.background, body: …)`로 띄운다. 무대가 위 안전 영역을 채우기 때문이다.
- `designReviewCaptureKeys`에 `'student_training__feed'`를 더한다. 화면은 `StudentTrainingScreen(demoProfile: designReviewProfileReturning(), demoFeed: designReviewTrainingFeed())`.

**문서**: 「예외는 홈 상단의 파란 무대 하나뿐」 규칙을 「탭 화면 위쪽의 파란 무대」로 바꾼다.
- `DESIGN.md`:
  - 116, 127, 145, 162, 167, 184, 192줄을 고친다.
  - 「파란 무대를 홈 밖에서 쓰지 않는다」를 「파란 무대는 탭 화면에만. 밀어서 여는 화면과 로그인·가입에는 쓰지 않는다」로 바꾼다.
  - 「흰 주 버튼: 파란 무대 위에서」로 바꾼다.
  - 「파란 무대」 절에 탭 무대 규칙(Global Constraints 첫 두 줄)과 `PageStage.tab` 사용법을 더한다.
  - 파일 지도에 `flutter_app/lib/widgets/page_stage.dart`를 넣는다.
- `.cursor/rules/design.mdc`: 29, 40, 46, 50, 60줄을 같은 뜻으로 고친다.
- `2026-10-17-liquid-glass-renewal-design.md`:
  - 38줄 「예외는 홈 상단의 파란 무대 하나뿐이다」 뒤에 「(2026-10-19 스펙으로 탭 화면 위쪽의 파란 무대로 바뀜)」을 붙인다.
  - 51줄 「파란 무대를 홈 밖에서 쓰기」를 「파란 무대를 탭 화면 밖에서 쓰기」로 바꾼다.

- [ ] **Step 1: 확인**: `cd flutter_app && flutter analyze lib/dev` → `error •` 없음
- [ ] **Step 2: 확인**: `grep -n "홈 밖에서" DESIGN.md .cursor/rules/design.mdc` → 결과 없음
- [ ] **Step 3: 커밋**: `git commit -m "Document the tab-screen blue stage and add a training review key."`

---

### Task 8: 전체 확인

- [ ] **Step 1: 분석기**: `cd flutter_app && flutter analyze` → `error •` 없음. 경고는 기존 `home_screen.dart` 하나 외에 새로 생기지 않는다.
- [ ] **Step 2: 전체 테스트**: `cd flutter_app && flutter test` → `All tests passed!` 밀어서 여는 화면의 기존 테스트(`student_flow_surfaces_test.dart`의 분석·풀이·업로드·세트 결과, `scaffold_background_test.dart`)는 고치지 않고 통과해야 한다.
- [ ] **Step 3: 손대지 않은 파일 확인**: `git diff --stat d87d70d -- flutter_app/lib/screens/analysis_screen.dart flutter_app/lib/screens/practice_screen.dart flutter_app/lib/screens/upload_screen.dart flutter_app/lib/screens/loop_result_screen.dart flutter_app/lib/screens/dashboard_screen.dart flutter_app/lib/screens/practice_generating_screen.dart` → 출력 없음
- [ ] **Step 4: 웹 리뷰 키**
  - 로컬 API(3737)와 웹(`.claude/launch.json`의 `flutter-web`, 8080)을 띄운다.
  - 모바일 375×812에서 아래 키마다 첫 화면을 캡처한다. 무대가 위 안전 영역까지 차는지, 글자가 넘치지 않는지 본다.
    - `student_training__empty`, `student_training__feed`
    - `student_progress__grade_m1`, `student_progress__empty`
    - `student_hub__returning`
  - 주소 예: `http://127.0.0.1:8080/?design_review=student_training__feed`
- [ ] **Step 5: 더미 계정 둘러보기**
  - 개발 메뉴 `</>` → 「빈 계정 로그인」 → 「빈 계정 · 민준」으로 들어간다.
  - 홈 → 훈련 → 성장 → 설정을 오가며 무대 높이·제목 위치가 탭마다 같은지 본다.
  - 각 탭을 스크롤해 상태바 띠가 나타나는지 본다.
  - 성장의 학습 통계 원을 눌러 학습 통계가 지금 모습 그대로 열리는지 본다.
  - 실제 계정 OAuth 칩과 「OAuth 계정 탈퇴·데이터 삭제」는 누르지 않는다.
- [ ] **Step 6: 시뮬레이터**
  - `cd flutter_app && flutter build ios --simulator --debug --dart-define-from-file=dev/local-defines.json --dart-define=API_BASE_URL=http://127.0.0.1:3737`
  - iPhone 17 Pro에 설치·실행해 Step 5를 반복한다. 상태바 글자가 무대 위에서 흰색이고 무대가 지나가면 검정인지 본다.
  - 빌드 뒤 `git checkout -- flutter_app/ios/Podfile flutter_app/ios/Podfile.lock flutter_app/ios/Runner.xcodeproj/project.pbxproj`.
- [ ] **Step 7: 사용자 확인 요청**: 탭별 캡처를 보여주고 1단계 확인을 받는다. 2단계(학부모·선생님 전용 탭)는 그 뒤에 따로 계획한다.
