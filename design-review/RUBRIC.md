# Design Review Rubric (DESIGN.md)

10-point scale. **Pass: total ≥ 9 and zero critical violations.**

| Category | Points | Pass criteria |
|----------|--------|---------------|
| Color tokens | 2 | `#007BFF` primary, `#F5F5F5` scaffold, `#FFFFFF` cards, semantic tints only. No violet `#7C6FF7`, legacy `#2563EB`, dark scaffold. |
| Typography & spacing | 2 | Noto Sans KR; clear title/body/caption hierarchy; tap targets ≥ 44px; card padding ~18px. |
| Shapes & depth | 1.5 | 14px card radius, flat borders, no drop shadows or gradients. |
| Components | 2 | `AppCard` / `TagChip` patterns; one primary filled CTA per screen. |
| State & hierarchy | 1.5 | Empty/loading/error distinct; section headers; readable information order. |
| EdTech tone | 1 | Flat Material icons (no emoji UI chrome); semantic progress/chips. |

## Auto-deduct (critical)

- Emoji as status/list icons (−1 to −2)
- Material default black-outline chips (−0.5)
- Dark scaffold or heavy shadow (−2, fail)
- Wrong brand blue / violet accents (−1)

## Feedback template

```
Score: X/10
Critical: ...
High: ...
Medium: ...
Files: ...
Next: ...
```
