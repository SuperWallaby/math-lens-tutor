/** List thumbnails (48–56pt @ ~2.5x density). */
export const SOLUTION_IMAGE_THUMB_PX = 128;

/** Optimized display copy — vision still uses the original upload buffer. */
export const SOLUTION_IMAGE_MAX_EDGE_PX = 2048;

export function solutionImageThumbR2KeyFromR2Key(r2Key: string): string | null {
  const key = r2Key?.trim();
  if (!key) return null;
  if (/-thumb\.webp$/i.test(key)) return key;
  if (/\.webp$/i.test(key)) {
    return key.replace(/\.webp$/i, "-thumb.webp");
  }
  return key.replace(/\.(jpe?g|png|gif|heic|heif)$/i, "-thumb.webp");
}

export function resolveSolutionImageThumbUrl(
  imageUrl: string | null | undefined,
): string | null {
  const url = imageUrl?.trim();
  if (!url) return null;

  if (url.startsWith("/api/images/")) {
    const [path, query] = url.split("?");
    if (query?.includes("variant=thumb")) return url;
    return `${path}?variant=thumb`;
  }

  const base = url.split("?")[0] ?? url;
  if (/\.webp$/i.test(base)) {
    return base.replace(/\.webp$/i, "-thumb.webp");
  }
  if (/\.(jpe?g|png|gif|heic|heif)$/i.test(base)) {
    return base.replace(/\.(jpe?g|png|gif|heic|heif)$/i, "-thumb.webp");
  }

  return `${base}?variant=thumb`;
}

export async function optimizeSolutionImageVariants(
  source: Buffer,
): Promise<{ display: Buffer; thumb: Buffer }> {
  const sharp = (await import("sharp")).default;
  const rotated = sharp(source).rotate();

  const display = await rotated
    .clone()
    .resize(SOLUTION_IMAGE_MAX_EDGE_PX, SOLUTION_IMAGE_MAX_EDGE_PX, {
      fit: "inside",
      withoutEnlargement: true,
    })
    .webp({ quality: 82, effort: 4 })
    .toBuffer();

  const thumb = await sharp(source)
    .rotate()
    .resize(SOLUTION_IMAGE_THUMB_PX, SOLUTION_IMAGE_THUMB_PX, {
      fit: "cover",
      position: "centre",
    })
    .webp({ quality: 78, effort: 4 })
    .toBuffer();

  return { display, thumb };
}
