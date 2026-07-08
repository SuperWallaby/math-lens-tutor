#!/usr/bin/env python3
"""Resize one PNG to App Store / Play target size (cover crop)."""

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
    p.add_argument("--w", type=int, required=True)
    p.add_argument("--h", type=int, required=True)
    args = p.parse_args()

    args.dst.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(args.src)
    out = to_rgb(resize_cover_center(im, args.w, args.h))
    out.save(args.dst, "PNG", optimize=True)
    print(f"{args.src.name} -> {args.dst} ({args.w}x{args.h})")


if __name__ == "__main__":
    main()
