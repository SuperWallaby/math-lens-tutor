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
```

Uses deployment `kaja-gpt-image-15` (`gpt-image-1.5`) by default. Override with `AZURE_OPENAI_IMAGE_DEPLOYMENT`.

Generated PNGs request `background: transparent` from the API. If the model still returns a solid backdrop, the script runs `scripts/fix-icon-transparency.py` as a fallback.

Fix existing icons without regenerating:

```bash
npm run fix:icon-transparency
```

## Flutter usage

```dart
Image.asset('assets/icons/3d/training_empty_new.png', width: 72)
```

Registered in `pubspec.yaml` under `assets/icons/3d/`.
