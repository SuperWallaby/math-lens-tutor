# 우열 3D Hero Icons

Ultra-minimal soft clay 3D empty-state / hero icons for the WooYeol app.

Style: **one chunky object**, matte clay, 2 flat colors max, readable at 48px. No scenes, stacks, or sparkle clutter.

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Icon IDs, prompts, brand colors, Azure deployment |
| `generation-log.json` | Last run output (auto-generated) |
| `*.png` | 1024×1024 PNG assets |

## Regenerate

From repo root (requires `.env.local` with Azure OpenAI):

```bash
# Priority 1 icons only (~10)
npm run generate:icons -- --priority 1

# All icons in manifest
npm run generate:icons

# Single icon
npm run generate:icons -- --id training_empty_new

# Overwrite existing
npm run generate:icons -- --force

# PNG → WebP (앱은 .webp 사용)
npm run optimize:flutter-assets
```

Uses deployment `gpt-image-2` by default. Override with `AZURE_OPENAI_IMAGE_DEPLOYMENT`.

Generated PNGs request `background: transparent` when the deployment supports it (`gpt-image-1.5`). For `gpt-image-2`, the script omits that flag and runs `scripts/fix-icon-transparency.py` after generation.

Fix existing icons without regenerating:

```bash
npm run fix:icon-transparency
```

## Flutter usage

```dart
Image.asset('assets/icons/3d/training_empty_new.webp', width: 72)
```

Registered in `pubspec.yaml` under `assets/icons/3d/`.
