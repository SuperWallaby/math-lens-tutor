/** Heuristic: empty Desmos bakes are mostly white/gray grid with very low blue curve signal. */
export async function pngLikelyEmptyGraph(png: Buffer): Promise<boolean> {
  const sharp = (await import("sharp")).default;
  const { data, info } = await sharp(png).raw().toBuffer({ resolveWithObject: true });

  let blueish = 0;
  let dark = 0;
  const pixels = info.width * info.height;
  for (let i = 0; i < data.length; i += info.channels) {
    const r = data[i]!;
    const g = data[i + 1]!;
    const b = data[i + 2]!;
    const lum = (r + g + b) / 3;
    if (lum < 120) dark += 1;
    if (b > r + 18 && b > g + 8 && lum < 200) blueish += 1;
  }

  const darkRatio = dark / pixels;
  const blueRatio = blueish / pixels;
  return darkRatio < 0.012 && blueRatio < 0.0008;
}
