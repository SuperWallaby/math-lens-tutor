#!/usr/bin/env python3
"""Square-crop master PNG to 1024, write AppIcon.appiconset + LaunchImage.imageset."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

# (filename, width_px, height_px)
APP_ICONS: list[tuple[str, int, int]] = [
    ("Icon-App-20x20@2x.png", 40, 40),
    ("Icon-App-20x20@3x.png", 60, 60),
    ("Icon-App-29x29@1x.png", 29, 29),
    ("Icon-App-29x29@2x.png", 58, 58),
    ("Icon-App-29x29@3x.png", 87, 87),
    ("Icon-App-40x40@2x.png", 80, 80),
    ("Icon-App-40x40@3x.png", 120, 120),
    ("Icon-App-60x60@2x.png", 120, 120),
    ("Icon-App-60x60@3x.png", 180, 180),
    ("Icon-App-20x20@1x.png", 20, 20),
    ("Icon-App-40x40@1x.png", 40, 40),
    ("Icon-App-76x76@1x.png", 76, 76),
    ("Icon-App-76x76@2x.png", 152, 152),
    ("Icon-App-83.5x83.5@2x.png", 167, 167),
    ("Icon-App-1024x1024@1x.png", 1024, 1024),
]


def square_master(im: Image.Image) -> Image.Image:
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    im = im.crop((left, top, left + side, top + side))
    return im.resize((1024, 1024), Image.Resampling.LANCZOS)


def make_launch_screen(master: Image.Image, w: int, h: int) -> Image.Image:
    """Indigo gradient + centered icon."""
    out = Image.new("RGB", (w, h), (30, 58, 138))
    draw = ImageDraw.Draw(out)
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(30 + (37 - 30) * t)
        g = int(58 + (99 - 58) * t)
        b = int(138 + (235 - 138) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    icon_side = int(min(w, h) * 0.42)
    icon = master.resize((icon_side, icon_side), Image.Resampling.LANCZOS)
    if icon.mode == "RGBA":
        bg = Image.new("RGB", icon.size, (255, 255, 255))
        bg.paste(icon, mask=icon.split()[3])
        icon = bg
    x = (w - icon_side) // 2
    y = (h - icon_side) // 2
    out.paste(icon, (x, y))
    return out


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: generate_ios_icons_from_master.py <master.png>", file=sys.stderr)
        sys.exit(1)
    master_path = Path(sys.argv[1]).resolve()
    ios = Path(__file__).resolve().parent.parent / "ios" / "Runner" / "Assets.xcassets"
    icon_dir = ios / "AppIcon.appiconset"
    launch_dir = ios / "LaunchImage.imageset"

    if not master_path.is_file():
        print(f"Missing: {master_path}", file=sys.stderr)
        sys.exit(1)

    im = Image.open(master_path).convert("RGBA")
    master_sq = square_master(im)

    for name, tw, th in APP_ICONS:
        resized = master_sq.resize((tw, th), Image.Resampling.LANCZOS)
        dest = icon_dir / name
        if resized.mode == "RGBA":
            rgb = Image.new("RGB", resized.size, (255, 255, 255))
            rgb.paste(resized, mask=resized.split()[3])
            resized = rgb
        resized.save(dest, "PNG", optimize=True)
        print(dest.name)

    # Launch (storyboard reference 168×185 @1x)
    for fname, w, h in (
        ("LaunchImage.png", 168, 185),
        ("LaunchImage@2x.png", 336, 370),
        ("LaunchImage@3x.png", 504, 555),
    ):
        splash = make_launch_screen(master_sq, w, h)
        splash.save(launch_dir / fname, "PNG", optimize=True)
        print(fname)

    print("Done.")


if __name__ == "__main__":
    main()
