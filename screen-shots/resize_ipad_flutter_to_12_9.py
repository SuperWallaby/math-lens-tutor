#!/usr/bin/env python3
"""Cover-crop Flutter iPad simulator PNGs to 2048×2732 for App Store 12.9\" slot."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


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
        bg = Image.new("RGB", im.size, (2, 6, 23))
        bg.paste(im, mask=im.split()[3])
        return bg
    return im.convert("RGB")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--src", type=Path, required=True)
    p.add_argument("--dst", type=Path, required=True)
    p.add_argument("--w", type=int, default=2048)
    p.add_argument("--h", type=int, default=2732)
    args = p.parse_args()

    args.dst.mkdir(parents=True, exist_ok=True)
    tw, th = args.w, args.h

    for path in sorted(args.src.glob("*.png")):
        if not path.is_file():
            continue
        im = Image.open(path)
        out_im = resize_cover_center(im, tw, th)
        out_im = to_rgb(out_im)
        dest = args.dst / path.name
        out_im.save(dest, "PNG", optimize=True)
        print(f"{path.name} -> {dest} ({tw}x{th})")


if __name__ == "__main__":
    main()
