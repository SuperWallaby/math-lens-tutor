---
name: 우열 (WooYeol)
inspired_by: App-icon brand · Korean EdTech mobile
colors:
  background: "#EEF3F8"
  surface: "#FFFFFF"
  surface-elevated: "#FFFFFF"
  surface-muted: "#E8F1F8"
  primary: "#2A72E5"
  primary-dark: "#1E46AA"
  primary-soft: "#E8F1FC"
  sky: "#5EB7EB"
  spark: "#FEB231"
  accent: "#FF8C00"
  accent-tint: "rgba(255,140,0,0.12)"
  success: "#2ECC40"
  success-tint: "rgba(46,204,64,0.12)"
  warning: "#B8860B"
  warning-tint: "rgba(184,134,11,0.14)"
  teacher: "#9370DB"
  teacher-tint: "rgba(147,112,219,0.12)"
  text: "#111111"
  text-sub: "#494C4F"
  text-muted: "#999999"
  border: "#EFEFF1"
  border-strong: "#E0E0E4"
typography:
  font-family-ui: "SUIT"
  font-family-display: "IBM Plex Sans KR"
  hero:
    fontSize: 28px
    fontWeight: 700
  title:
    fontSize: 20px
    fontWeight: 700
  body:
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.6
  caption:
    fontSize: 13px
    fontWeight: 600
rounded:
  sm: 12px
  md: 16px
  lg: 26px
  pill: 999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
  xxl: 24px
  section: 32px
components:
  button-height: 52px
  card-padding: 18px
  app-bar: light-flat
  bottom-nav: floating-glass-pill+center-camera
---

# 우열 DESIGN.md

Korean math learning UI. Brand action color is the **app-icon blue** `#2A72E5`. Titles use **IBM Plex Sans KR**; body UI uses **SUIT**.

## Overview

- Mobile-first Korean EdTech: 찍기 → 짚기 → 풀기.
- Pale mist canvas `#EEF3F8`. Content on **white plates**. Blue for CTA / active only.
- 유리는 **콘텐츠 위에 떠 있는 층에만** 쓴다. 규칙과 표는 아래 Elevation & Depth.
- Copy: 숙제 · 찍기 · 막힌 곳 · 이어서 풀기. Avoid AI / insight / dashboard tone.
- No dark mode in v1 of this system.

## Colors

| Token | Hex | Usage |
|-------|-----|-------|
| background | `#EEF3F8` | Pale mist canvas |
| surface | `#FFFFFF` | Cards, sheets, inputs |
| primary | `#2A72E5` | App-icon CTA, active tab |
| primary-dark | `#1E46AA` | Pressed / cobalt |
| sky | `#5EB7EB` | Soft sky accent (icon) |
| spark | `#FEB231` | Splash / highlight spark |
| success | `#2ECC40` | Correct answers |
| warning | `#B8860B` | Caution labels |
| accent | `#FF8C00` | Errors, weak concepts |
| teacher | `#9370DB` | Teacher role |
| text | `#111111` | Headlines, body |
| text-sub | `#494C4F` | Secondary copy |
| text-muted | `#999999` | Placeholders, inactive nav |
| border | `#EFEFF1` | Card outlines, dividers |

## Typography

- **Body / UI:** SUIT — 400 (body), 600 (labels), 700 (titles, buttons).
- **Display / brand titles:** IBM Plex Sans KR Bold (700).
- Weights: prefer **400 / 600 / 700** only.

## Voice (home)

- First visit: 「오늘은 한 장만 올려도 돼요」. 본문에 「숙제 올리기」 버튼은 없다. 가운데 카메라가 그 역할을 한다.
- Returning: 「어제 막힌 곳부터 이어가요」 + 흰 주 버튼 **이어서 풀기**
- Avoid: 「중1 맞춤」, 「오늘 어떤문제를…」, 「최근 분석」 (AI / dashboard tone)

## Layout & Spacing

- Page horizontal padding: **16–20px** (tablet max width ~560px centered).
- Section gap: **32px**; card inner padding: **18px**.
- Minimum tap target: **44px**; primary buttons **52px** tall.

## Elevation & Depth

스펙: [`docs/superpowers/specs/2026-10-17-liquid-glass-renewal-design.md`](docs/superpowers/specs/2026-10-17-liquid-glass-renewal-design.md)

**콘텐츠 위에 떠 있으면 유리, 아니면 흰 카드.** 예외는 홈 상단의 파란 무대 하나뿐이다.

| 요소 | 표면 |
|------|------|
| 콘텐츠 카드, 리스트 줄, 통계, 입력칸 | 흰 카드 `#FFFFFF`, 테두리 `#EFEFF1` 1px, 모서리 16~18px, 그림자 없음 |
| 화면 배경 | 안개색 `#EEF3F8` 단색 |
| 아래 탭바 | 맑은 유리 |
| 탭바 가운데 카메라 | 파란 유리 |
| 스크롤하면 생기는 상단 | 흐림 가장자리(위는 진하고 아래로 사라짐) + 가운데 작은 제목 |
| 아래에서 올라오는 시트, 팝업 | 맑은 유리 |
| 사진 위 라벨, 버튼 (분석 화면 등) | 맑은 유리 |
| **예외**: 홈 파란 무대 위 카드 | 무대용 유리 |

유리 프리셋 (Flutter `GlassPreset`, `BackdropFilter` 흐림 기반)

| 프리셋 | 채움 | 흐림 | 테두리 | 그림자 |
|--------|------|------|--------|--------|
| 맑은 유리 | 흰색 30% | 14 (채도 1.8배, 가능하면) | 흰색 66% 1px + 위쪽 안쪽 하이라이트 | `0 8 24` 남색 14% |
| 무대용 유리 | 흰색 14% | 16 | 흰색 38% 1px | `0 10 26` 남색 22% |
| 파란 유리 | `#2A72E5` 88% | 10 | 흰색 28% 1px + 위쪽 안쪽 하이라이트 | `0 8 18` 파랑 32% |

- 진짜 굴절(렌즈) 효과는 쓰지 않는다. 모든 플랫폼에서 흐림 기반으로 통일한다.
- 웹에서 `HtmlElementView`로 유리를 만들지 않는다.

## Buttons

| 종류 | 모양 | 쓰는 곳 |
|------|------|---------|
| 파란 유리 주 버튼 | 파란 유리 + 흰 글씨, 높이 50~52, 완전 둥근 모서리 | 탭바가 없는 전체 화면 흐름(풀이, 분석, 업로드)에서 화면당 하나 |
| 흰 주 버튼 | 흰색 + 파란 글씨 | 홈 파란 무대 위에서만 (「이어서 풀기」) |
| 연파랑 주 버튼 | `#E8F1FC` + `#1E46AA` 글씨 | 탭 화면(홈 아래쪽, 훈련, 성장, 설정)의 본문 |
| 보조 | 흰 카드 버튼 또는 글자 링크 | 어디서나 |

탭 화면에서는 가운데 카메라가 그 화면의 유일한 파란 채움이다. 그래서 탭 화면 본문에는 파란 채움 버튼을 두지 않는다.

## Navigation

- **학생 탭바:** 홈 · 훈련 · [찍기] · 성장 · 설정
- 가운데 카메라는 탭 전환이 아니라 업로드 흐름을 **전체 화면으로** 연다.
- 떠 있는 알약 모양: 좌우 여백 12, 높이 72, 아래는 iOS 26처럼 홈 표시줄 영역 안으로 10 내려앉음(안전 영역 − 10, 표시줄이 없으면 12). 아이콘·글자는 검정 한 가지(당근 느낌). 선택된 탭은 꽉 찬 아이콘 + 회색 유리 방울(검정 7%).
- 가운데 카메라: 58px 원, 탭바보다 30px 위로 솟음, 흰 테두리 3px, 아래 글자 「찍기」.
- 콘텐츠는 탭바 아래까지 스크롤된다(유리 아래로 비쳐 보이게).
- 학부모(홈 · 설명 · 이번 주 · 진도 · 설정)와 선생님(홈 · 학생 · 반진도 · 설정)은 같은 유리 탭바를 쓰고, 가운데 카메라는 없다.

## Home stage

학생 홈 상단의 파란 무대. 유리 규칙의 유일한 예외다. 홈 밖에서 쓰지 않는다.

- 배경: 165° 그라데이션 `#5EB7EB` → `#2A72E5` → `#1E46AA`, 아래 모서리 32. 번짐 장식은 없다.
- 오른쪽 위: 앱 아이콘(흰 모서리를 뺀 버전) 108px, 8° 기울임.
- 왼쪽 위: 날짜, 사용자 줄(프로필 사진 40px + 「이름님」 + 「학년 · 학교」), 연속 칩(`streakWeeks` 1 이상이고 다시 온 상태일 때만), 인사 문장.
- 무대 안 카드는 무대용 유리, 주 버튼은 흰 주 버튼.
- 「우열」 글자 워드마크는 쓰지 않는다.

## Do's and Don'ts

**Do**
- Use ONLY tokens above for new UI.
- 화면마다 파란 채움 버튼은 하나. 탭 화면에서는 가운데 카메라가 그 하나라서 본문 주 버튼은 연파랑.
- 콘텐츠는 흰 카드, 떠 있는 층(탭바·시트·팝업·사진 위 라벨)만 유리.
- Keep loop language: 찍기 → 짚기 → 풀기.

**Don't**
- Don't use dusty `#7EAFD9` or Bootstrap `#007BFF` as primary.
- Don't use violet `#7C6FF7` or Material `#2563EB`.
- Don't lead with AI / insight / 정답률 dashboard copy on home.
- 콘텐츠 위 유리 금지: 카드, 리스트 줄, 통계, 입력칸에 `GlassPanel` 등 유리를 바르지 않는다.
- 배경화면 이미지와 큰 색 번짐(blob) 금지. 노란색 번짐도 금지(파랑과 섞여 회갈색이 된다).
- 파란 무대를 홈 밖에서 쓰지 않는다.

## Code locations

| Platform | Tokens / theme |
|----------|----------------|
| Flutter | `flutter_app/lib/theme/app_design_system.dart` (토큰, `GlassPreset`, 버튼 스타일) |
| Flutter 유리 위젯 | `flutter_app/lib/widgets/glass.dart` (떠 있는 층만) |
| Flutter 카드 · 홈 무대 | `flutter_app/lib/widgets/app_card.dart`, `flutter_app/lib/widgets/home_stage.dart` |
| 유리 규칙 검사 | `flutter_app/test/design_rules_test.dart` |
| Next.js / web | `src/app/globals.css` CSS variables |
| Cursor rule | `.cursor/rules/design.mdc` |
| Spec | `docs/superpowers/specs/2026-10-17-liquid-glass-renewal-design.md` |

## 아이콘

- MingCute(`flutter_mingcute`)의 둥근 선/채움 아이콘을 쓴다. 화면은 `Icons.*` 대신 `AppIcons.*`(`lib/theme/app_icons.dart`)를 쓰고, 묶음을 바꿀 때는 그 파일만 고친다.
- 선택 상태가 있는 곳(탭바)은 선 아이콘 ↔ `…Fill` 짝을 쓴다.
