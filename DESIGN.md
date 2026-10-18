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
  bottom-nav: icon+label
---

# 우열 DESIGN.md

Korean math learning UI. Brand action color is the **app-icon blue** `#2A72E5`. Titles use **IBM Plex Sans KR**; body UI uses **SUIT**.

## Overview

- Mobile-first Korean EdTech: 찍기 → 짚기 → 풀기.
- Pale mist canvas `#EEF3F8`. Content on **white plates**. Blue for CTA / active only.
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

- First visit: 「오늘은 한 장만…」 + CTA **숙제 올리기**
- Returning: 「어제 막힌 곳부터 이어가요」 + CTA **이어서 풀기**
- Avoid: 「중1 맞춤」, 「오늘 어떤문제를…」, 「최근 분석」 (AI / dashboard tone)

## Layout & Spacing

- Page horizontal padding: **16–20px** (tablet max width ~560px centered).
- Section gap: **32px**; card inner padding: **18px**.
- Minimum tap target: **44px**; primary buttons **52px** tall.

## Elevation & Depth

- Prefer flat white plates on mist canvas.
- Soft lift shadows OK for glass/tab experiments; primary CTA is solid blue + white label.

## Do's and Don'ts

**Do**
- Use ONLY tokens above for new UI.
- One primary filled CTA per screen (없음: 숙제 올리기 / 있음: 이어서 풀기).
- Keep loop language: 찍기 → 짚기 → 풀기.

**Don't**
- Don't use dusty `#7EAFD9` or Bootstrap `#007BFF` as primary.
- Don't use violet `#7C6FF7` or Material `#2563EB`.
- Don't lead with AI / insight / 정답률 dashboard copy on home.

## Code locations

| Platform | Tokens / theme |
|----------|----------------|
| Flutter | `flutter_app/lib/theme/app_design_system.dart` |
| Next.js / web | `src/app/globals.css` CSS variables |
| Cursor rule | `.cursor/rules/design.mdc` |
