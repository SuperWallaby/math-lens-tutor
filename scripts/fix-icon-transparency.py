#!/usr/bin/env python3
"""Remove near-white studio backgrounds from 3D hero icons (RGBA PNG)."""

from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow required: pip install pillow", file=sys.stderr)
    raise SystemExit(1)

DEFAULT_DIR = Path(__file__).resolve().parents[1] / "flutter_app/assets/icons/3d"


def make_transparent(path: Path, tolerance: int = 24) -> float:
    im = Image.open(path).convert("RGBA")
    width, height = im.size
    pixels = im.load()
    visited = bytearray(width * height)

    def index(x: int, y: int) -> int:
        return y * width + x

    def close_to_bg(rgb: tuple[int, int, int], bg: tuple[int, int, int]) -> bool:
        return all(abs(rgb[i] - bg[i]) <= tolerance for i in range(3))

    seeds = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]

    for sx, sy in seeds:
        bg = pixels[sx, sy][:3]
        queue: deque[tuple[int, int]] = deque([(sx, sy)])
        while queue:
            x, y = queue.popleft()
            i = index(x, y)
            if x < 0 or y < 0 or x >= width or y >= height or visited[i]:
                continue
            rgb = pixels[x, y][:3]
            if not close_to_bg(rgb, bg):
                continue
            visited[i] = 1
            r, g, b, _ = pixels[x, y]
            pixels[x, y] = (r, g, b, 0)
            queue.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    im.save(path, "PNG")
    alpha = im.getchannel("A")
    transparent = sum(1 for value in alpha.get_flattened_data() if value < 10)
    return transparent / (width * height)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="PNG files (default: all icons in assets/icons/3d)",
    )
    parser.add_argument(
        "--dir",
        type=Path,
        default=DEFAULT_DIR,
        help=f"Directory of PNG icons (default: {DEFAULT_DIR})",
    )
    parser.add_argument(
        "--tolerance",
        type=int,
        default=24,
        help="Background color match tolerance (default: 24)",
    )
    args = parser.parse_args()

    files = args.paths or sorted(args.dir.glob("*.png"))
    if not files:
        print("No PNG files found.", file=sys.stderr)
        raise SystemExit(1)

    for path in files:
        if not path.is_file():
            print(f"skip {path} (missing)")
            continue
        ratio = make_transparent(path, tolerance=args.tolerance)
        print(f"ok {path.name} ({ratio:.0%} transparent)")


if __name__ == "__main__":
    main()
