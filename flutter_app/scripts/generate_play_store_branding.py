#!/usr/bin/env python3
"""Play Store · 앱 아이콘 산출물 — branding/app-icon-master-source.png 기준.

입력: flutter_app/branding/app-icon-master-source.png (1024×1024 권장)
출력: play-store-icon-512, feature-graphic, android/ios/web 아이콘
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BRANDING = ROOT / "branding"
MASTER = BRANDING / "app-icon-master-source.png"
SCRIPT_DIR = Path(__file__).resolve().parent

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

GRADIENT_TOP = (0, 98, 204)
GRADIENT_BOTTOM = (0, 123, 255)


def square_master(im: Image.Image) -> Image.Image:
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    cropped = im.crop((left, top, left + side, top + side))
    return cropped.resize((1024, 1024), Image.Resampling.LANCZOS)


def save_rgb_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if im.mode == "RGBA":
        bg = Image.new("RGB", im.size, (255, 255, 255))
        bg.paste(im, mask=im.split()[3])
        im = bg
    elif im.mode != "RGB":
        im = im.convert("RGB")
    im.save(path, "PNG", optimize=True)


def load_korean_font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/AppleSDGothicNeo-Bold.ttf",
        "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
    ]
    if not bold:
        candidates = [
            "/System/Library/Fonts/Supplemental/AppleSDGothicNeo-Regular.ttf",
        ] + candidates
    for path in candidates:
        p = Path(path)
        if p.is_file():
            try:
                return ImageFont.truetype(str(p), size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def write_play_icon(master: Image.Image) -> Path:
    out = BRANDING / "play-store-icon-512.png"
    icon = master.resize((512, 512), Image.Resampling.LANCZOS)
    save_rgb_png(icon, out)
    return out


def write_feature_graphic(master: Image.Image) -> Path:
    w, h = 1024, 500
    out = BRANDING / "play-store-feature-graphic-1024x500.png"
    canvas = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(canvas)
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(GRADIENT_TOP[0] + (GRADIENT_BOTTOM[0] - GRADIENT_TOP[0]) * t)
        g = int(GRADIENT_TOP[1] + (GRADIENT_BOTTOM[1] - GRADIENT_TOP[1]) * t)
        b = int(GRADIENT_TOP[2] + (GRADIENT_BOTTOM[2] - GRADIENT_TOP[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse((720, -80, 1120, 320), fill=(255, 255, 255, 28))
    od.ellipse((-120, 280, 280, 680), fill=(255, 255, 255, 18))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), overlay).convert("RGB")

    icon_side = 280
    icon = master.resize((icon_side, icon_side), Image.Resampling.LANCZOS)
    ix, iy = 80, (h - icon_side) // 2
    canvas.paste(icon, (ix, iy))

    draw = ImageDraw.Draw(canvas)
    title_font = load_korean_font(72, bold=True)
    sub_font = load_korean_font(32, bold=False)
    tag_font = load_korean_font(24, bold=False)

    tx = ix + icon_side + 52
    draw.text((tx, 148), "우열", fill=(255, 255, 255), font=title_font)
    draw.text((tx, 240), "AI 수학 튜터", fill=(255, 255, 255), font=sub_font)
    draw.text(
        (tx, 292),
        "풀이 사진 분석 · 유사 문제 · 학부모 코칭",
        fill=(230, 240, 255),
        font=tag_font,
    )

    save_rgb_png(canvas, out)
    return out


def write_android_icons(master: Image.Image) -> None:
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in ANDROID_SIZES.items():
        dest = res / folder / "ic_launcher.png"
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        save_rgb_png(resized, dest)
        print(f"android {dest.relative_to(ROOT)}")


def write_web_icons(master: Image.Image) -> None:
    web = ROOT / "web"
    for name, size in (
        ("icons/Icon-192.png", 192),
        ("icons/Icon-512.png", 512),
        ("icons/Icon-maskable-192.png", 192),
        ("icons/Icon-maskable-512.png", 512),
        ("favicon.png", 48),
    ):
        dest = web / name
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        save_rgb_png(resized, dest)
        print(f"web {name}")


def run_ios_icons() -> None:
    script = SCRIPT_DIR / "generate_ios_icons_from_master.py"
    subprocess.run([sys.executable, str(script), str(MASTER)], check=True)


def main() -> None:
    if not MASTER.is_file():
        print(f"Missing master: {MASTER}", file=sys.stderr)
        sys.exit(1)

    im = Image.open(MASTER).convert("RGBA")
    master = square_master(im)
    save_rgb_png(master, MASTER)

    icon_path = write_play_icon(master)
    feature_path = write_feature_graphic(master)
    write_android_icons(master)
    write_web_icons(master)
    run_ios_icons()

    print(f"\nPlay Store icon: {icon_path}")
    print(f"Feature graphic: {feature_path}")
    print("Done.")


if __name__ == "__main__":
    main()
