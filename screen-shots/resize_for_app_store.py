#!/usr/bin/env python3
"""Resize portrait screenshots to iPhone App Store Connect sizes.

Apple lists (among others): 1242×2688, 1284×2778, 1290×2796 (portrait)
and landscape swaps — see Connect upload UI for the active slot.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

# (width, height, folder suffix) — portrait
TARGETS: tuple[tuple[int, int, str], ...] = (
    (1290, 2796, "ios-app-store-6.7in-1290x2796"),
    (1284, 2778, "ios-app-store-6.5in-1284x2778"),
    (1242, 2688, "ios-app-store-1242x2688"),  # 6.5" alternate (Connect lists this)
)


def resize_cover_center(im: Image.Image, tw: int, th: int) -> Image.Image:
    w, h = im.size
    scale = max(tw / w, th / h)
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return im.crop((left, top, left + tw, top + th))


def to_rgb(im: Image.Image) -> Image.Image:
    if im.mode == "RGBA":
        bg = Image.new("RGB", im.size, (255, 255, 255))
        bg.paste(im, mask=im.split()[3])
        return bg
    return im.convert("RGB")


def main() -> None:
    root = Path(__file__).resolve().parent

    for tw, th, folder in TARGETS:
        out = root / folder
        out.mkdir(exist_ok=True)

        for path in sorted(root.glob("study-app-*.png")):
            if not path.is_file():
                continue
            im = Image.open(path)
            out_im = resize_cover_center(im, tw, th)
            out_im = to_rgb(out_im)
            dest = out / path.name
            out_im.save(dest, "PNG", optimize=True)
            print(f"{path.name} -> {folder}/ ({tw}x{th})")


if __name__ == "__main__":
    main()
