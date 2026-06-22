# 온보딩 홍보 이미지 프롬프트

세로형(9:16) 기능 홍보 카드. **스마트폰 목업 X**, **앱 UI 스크린샷 X** —  
**3D 기하학(clay) 일러스트**로 기능을 상징적으로 표현.

파일명: `{role}/01_*.png` … `{role}/04_*.png`  
역할: `student` · `parent` · `teacher`  
권장 크기: **1024×1536**

기존 3D 아이콘(`assets/icons/3d/`)과 톤 통일: soft matte clay, 둥근 형태, 2~3색 이내.

---

## 공통 (master prompt)

모든 장에 아래를 앞에 붙여서 사용.

```
Vertical promotional illustration for Korean math learning app "우열" (WooYeol).
Portrait 9:16, onboarding slide, generous padding.
Bright EdTech backdrop #F5F5F5, clean and airy.

STYLE — 3D geometric math illustration (NOT a phone mockup, NOT flat UI screenshot):
- Soft matte clay / plasticine look, smooth rounded 3D shapes
- Math & learning metaphors: cubes, fraction blocks, coordinate axes, bar charts,
  graphs, magnifying glass, checkmarks, camera lens — as abstract 3D objects
- One clear hero composition centered (~70% canvas), readable at a glance
- At most 2–3 flat brand colors + white; role accent as highlight color
- Subtle soft ground shadow under hero group only
- Optional: 1 short Korean headline below hero (max 6 words), bold sans-serif

AVOID: smartphone frame, app screen mockup, realistic photo, dark mode,
busy scene, many tiny labels, neon, watermark, emoji, human faces, sparkle clutter.
```

역할별 accent: 학생 `#007BFF` · 학부모 `#2ECC40` · 교사 `#9370DB`

---

## 학생 (student)

### 01 — 틀린 문제 · AI 분석 · 맞춤 훈련
**파일:** `student/01_wrong_analysis.png`

```
Student role, blue #007BFF accent.
3D clay composition: open notebook page as soft white slab,
equation "2x+5=13" embossed in gentle 3D type,
orange clay X mark on wrong answer, green clay check on correct "x=4",
small blue clay flag labeled "약점" pointing at equation block.
Headline optional: "틀린 이유를 알려줘요"
```

### 02 — 사진 찍고 · 유사 문제 생성
**파일:** `student/02_photo_upload.png`

```
Student role, blue accent.
Chunky 3D clay camera pointing at floating math worksheet tile,
arrow of soft blue blocks flowing from photo into two new problem cards
(simple fraction or equation shapes on white clay tiles).
Headline optional: "사진 한 장으로 연습"
```

### 03 — 단원별 학습 진행
**파일:** `student/03_unit_progress.png`

```
Student role, blue accent.
Three stacked 3D progress blocks like LEGO steps:
green block tallest "완료", gold medium "학습중", orange short "보완",
each with simple math symbol (π, ÷, x) embossed on face.
Small clay tabs for grade levels as flat pills in background.
Headline optional: "내 진도 한눈에"
```

### 04 — 학습 분석 리포트
**파일:** `student/04_analysis_report.png`

```
Student role, blue accent.
3D clay line chart rising on soft white board,
green upward arrow badge "+4%",
two small concept chips as rounded clay pills (일차방정식, 이항),
minimal weekly calendar dots in background.
Headline optional: "성장이 보여요"
```

---

## 학부모 (parent)

### 01 — 아이 오답 분석
**파일:** `parent/01_wrong_analysis.png`

```
Parent role, green #2ECC40 accent.
3D clay heart shape gently embracing a small report card tile,
wrong step highlighted with soft orange clay highlight bar,
green concept tags as rounded pills floating nearby.
Warm, reassuring — not alarming.
Headline optional: "아이 약점 파악"
```

### 02 — 풀이 사진 분석
**파일:** `parent/02_photo_upload.png`

```
Parent role, green accent.
Large clay magnifying glass over handwritten math lines on white slab,
spark-free: use soft green glow ring instead of particles,
below — two generated practice tiles as simple 3D cards.
Headline optional: "풀이 사진 분석"
```

### 03 — 단원별 진도 확인
**파일:** `parent/03_unit_progress.png`

```
Parent role, green accent.
3D clay dashboard: horizontal progress bars as rounded green tubes
(filled at different levels), linked by thin clay chain to small name tag,
unit labels as minimal embossed text on bar ends.
Headline optional: "자녀 진도 확인"
```

### 04 — 성장 · 주간 리포트
**파일:** `parent/04_analysis_report.png`

```
Parent role, green accent.
3D clay growth chart with gentle upward curve,
floating speech bubble tile "이번 주 부모님 팁" as soft white card,
small green heart clay icon (single object, not emoji).
Headline optional: "주간 성장 리포트"
```

---

## 교사 (teacher)

### 01 — 학생별 맞춤 보충
**파일:** `teacher/01_wrong_analysis.png`

```
Teacher role, purple #9370DB accent.
3D clay classroom metaphor: row of small student dots on ascending steps,
two purple alert flags on lower steps, magnifying glass on weak-concept tile,
no realistic desks — abstract geometry only.
Headline optional: "학생별 맞춤 보충"
```

### 02 — 풀이 AI 분석
**파일:** `teacher/02_photo_upload.png`

```
Teacher role, purple accent.
Submitted solution as white clay scroll tile,
purple highlight bar on wrong step in 3D embossed lines,
stack of similar-problem cards fanning out to the right.
Headline optional: "풀이 AI 분석"
```

### 03 — 반 단원별 진도
**파일:** `teacher/03_unit_progress.png`

```
Teacher role, purple accent.
3D bar chart as chunky purple clay columns of different heights,
class average line as soft white rod across bars,
small counter badge "24명" as rounded clay pill.
Headline optional: "반 진도 한눈에"
```

### 04 — 학습 분석 리포트
**파일:** `teacher/04_analysis_report.png`

```
Teacher role, purple accent.
3D analytics board: dual bar + dot plot on white clay panel,
at-risk list as three small red-orange clay markers on lower tier,
export icon as simple purple clay share arrow (one object).
Headline optional: "수업 설계에 활용"
```

---

## 생성 팁

- **SDXL / gpt-image** 모두: master prompt + 역할 accent + 장면만 붙여서 생성
- 아이콘과 같이 `npm run generate:icons` 파이프라인을 쓰려면 별도 onboarding manifest 추가 가능
- 재생성 시 **동일 master prompt** 유지 → 시리즈 톤 통일
- 텍스트가 깨지면 headline을 빼고 Flutter에서 `Text`로 올리는 것도 OK
