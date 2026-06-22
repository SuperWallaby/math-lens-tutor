---
name: 우열 (WooYeol)
inspired_by: Flat Design Educacional Vibrante · Korean EdTech mobile
colors:
  background: "#F5F5F5"
  surface: "#FFFFFF"
  surface-elevated: "#FAFAFA"
  surface-muted: "#EEEEEE"
  primary: "#007BFF"
  primary-dark: "#0062CC"
  primary-tint: "rgba(0,123,255,0.12)"
  accent: "#FF8C00"
  accent-tint: "rgba(255,140,0,0.12)"
  success: "#2ECC40"
  success-tint: "rgba(46,204,64,0.12)"
  warning: "#B8860B"
  warning-tint: "rgba(184,134,11,0.14)"
  teacher: "#9370DB"
  teacher-tint: "rgba(147,112,219,0.12)"
  parent: "#2ECC40"
  magenta: "#FF00CC"
  text: "#1A1A2E"
  text-sub: "#5A6278"
  text-muted: "#949BB0"
  border: "rgba(0,0,0,0.08)"
  border-strong: "rgba(0,0,0,0.12)"
typography:
  font-family-ui: "Noto Sans KR"
  font-family-display: "Noto Sans KR"
  hero:
    fontSize: 28px
    fontWeight: 800
  title:
    fontSize: 20px
    fontWeight: 700
  body:
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.6
  caption:
    fontSize: 12px
    fontWeight: 600
rounded:
  sm: 10px
  md: 14px
  lg: 16px
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

Bright, approachable Korean math learning UI. Inspired by **Flat Design Educacional Vibrante** (Duolingo/Khan-style: bold primaries, no gradients, minimal shadow, generous whitespace).

## Overview

- Mobile-first Korean EdTech: scan → diagnose → practice loop.
- **Light canvas** with solid, high-saturation colors for CTAs and learning states.
- Encouraging tone — color maps to category/progress, not decoration.
- No dark mode in v1 of this system.

## Colors

| Token | Hex | Usage |
|-------|-----|-------|
| background | `#F5F5F5` | Scaffold, page base |
| surface | `#FFFFFF` | Cards, sheets, inputs |
| surface-elevated | `#FAFAFA` | Nested panels |
| primary | `#007BFF` | Primary CTA, active tab, links |
| success | `#2ECC40` | Correct answers, strong concepts, parent role |
| warning | `#B8860B` | Streaks, 학습 중, caution labels |
| accent | `#FF8C00` | Errors, weak concepts, alerts |
| teacher | `#9370DB` | Teacher role, class overview |
| text | `#1A1A2E` | Headlines, body |
| text-sub | `#5A6278` | Secondary copy |
| text-muted | `#949BB0` | Placeholders, inactive nav |
| border | `rgba(0,0,0,0.08)` | Card outlines, dividers |

Use `{colors.*-tint}` for chips/tags. Limit palette to 4–6 bold hues per screen.

## Typography

- **All UI copy:** Noto Sans KR — 400 (body), 600 (labels), 700–800 (titles).
- Max line length ~72ch for long explanatory text.
- Monospace only for codes/stats when needed.

## Layout & Spacing

- Page horizontal padding: **16–20px** (tablet max width ~560px centered).
- Section gap: **32px**; card inner padding: **18px**.
- Minimum tap target: **44px**; primary buttons **52px** tall (+20% for key actions).

## Shapes

- Cards & inputs: **14px** (`rounded.md`).
- Small chips: **10px** or pill (`999px`).
- No 24px+ card radius mixed with 14px buttons.

## Elevation & Depth

- **Flat:** `elevation: 0`, no drop shadows (max 2px subtle border if needed).
- Depth via white cards on `#F5F5F5` background, not layering dark surfaces.
- No gradients on buttons or backgrounds.

## Components

### App card
- Background `{colors.surface}`, border `{colors.border}`, radius `{rounded.md}`.
- No shadows.

### Tag / status chip
- Tint background (~12–18% opacity) + saturated label text.
- Weak concept → accent tint; strong → success tint; teacher → teacher tint.

### Bottom navigation
- White surface, inactive `{colors.text-muted}`, active `{colors.primary}` with primary tint indicator.

### Progress bars & charts
- Track: `{colors.surface-muted}`; fill: primary or semantic color matching status.

## Role accents

| Role | Color | When |
|------|-------|------|
| Student (default) | primary | Training, upload, practice |
| Parent | success | Reports, linked student |
| Teacher | teacher | Class overview, recommendations |

Do not recolor the entire app per role — use accent pills and section headers only.

## Do's and Don'ts

**Do**
- Use ONLY tokens above for new UI.
- Keep one primary filled CTA per screen.
- Prefer bordered white cards on light gray scaffold.
- Use saturated colors to signal learning state (correct/warning/error).

**Don't**
- Don't use dark scaffold (`#09090F`, `#0F172A`, slate-950) — legacy, removed.
- Don't use violet `#7C6FF7` or Material `#2563EB` — replaced by `{colors.primary}`.
- Don't use heavy shadows or gradients.
- Don't use pure `#000` text; use `{colors.text}`.

## Code locations

| Platform | Tokens / theme |
|----------|----------------|
| Flutter | `flutter_app/lib/theme/app_design_system.dart` |
| Next.js / web | `src/app/globals.css` CSS variables |
| Cursor rule | `.cursor/rules/design.mdc` |
