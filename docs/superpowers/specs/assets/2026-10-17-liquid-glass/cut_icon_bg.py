"""Make the white area outside the app icon's rounded plate transparent.

Flood-fills near-white pixels connected to the image border, then un-mixes
the anti-aliased edge band against white so the plate edge stays smooth.
"""
import sys

import numpy as np
from PIL import Image

src, out, preview = sys.argv[1:4]
rgb = np.asarray(Image.open(src).convert("RGB"), dtype=np.float32)
h, w, _ = rgb.shape
minc = rgb.min(axis=2)


def dilate(mask, steps=1):
    m = mask.copy()
    for _ in range(steps):
        g = m.copy()
        g[1:, :] |= m[:-1, :]
        g[:-1, :] |= m[1:, :]
        g[:, 1:] |= m[:, :-1]
        g[:, :-1] |= m[:, 1:]
        m = g
    return m


candidate = minc >= 238
bg = np.zeros_like(candidate)
bg[0, :], bg[-1, :], bg[:, 0], bg[:, -1] = candidate[0, :], candidate[-1, :], candidate[:, 0], candidate[:, -1]
while True:
    grown = dilate(bg) & candidate
    if (grown == bg).all():
        break
    bg = grown

band = dilate(bg, 4) & ~bg
interior = ~dilate(bg, 7)


def box(a, r):
    pad = np.pad(a, ((r + 1, r), (r + 1, r)), mode="edge")
    c = pad.cumsum(0).cumsum(1)
    return c[2 * r + 1:, 2 * r + 1:] - c[:-2 * r - 1, 2 * r + 1:] - c[2 * r + 1:, :-2 * r - 1] + c[:-2 * r - 1, :-2 * r - 1]


wsum = box(interior.astype(np.float32), 9)
fg = np.stack([box(rgb[..., k] * interior, 9) for k in range(3)], axis=2) / np.maximum(wsum, 1)[..., None]

d_px = 255.0 - rgb
d_fg = 255.0 - fg
alpha_band = np.clip((d_px * d_fg).sum(2) / np.maximum((d_fg * d_fg).sum(2), 1.0), 0.0, 1.0)

alpha = np.ones((h, w), dtype=np.float32)
alpha[bg] = 0.0
alpha[band] = alpha_band[band]

color = rgb.copy()
a3 = np.maximum(alpha, 1e-3)[..., None]
unmixed = np.clip((rgb - (1.0 - alpha[..., None]) * 255.0) / a3, 0, 255)
color[band] = np.where(alpha[band][..., None] > 0.15, unmixed[band], fg[band])

rgba = np.dstack([color, alpha * 255.0]).round().astype(np.uint8)
img = Image.fromarray(rgba, "RGBA")
img.save(out)

check = Image.new("RGBA", (w * 2, h), (0, 0, 0, 255))
check.paste(Image.new("RGBA", (w, h), (30, 70, 170, 255)), (w, 0))
check.alpha_composite(img, (0, 0))
check.alpha_composite(img, (w, 0))
check.convert("RGB").resize((w, h // 2)).save(preview)
print("transparent px:", int(bg.sum()), "edge px:", int(band.sum()))
