#!/usr/bin/env node
/**
 * 온보딩 시작 슬라이드(01–04.png) 최적화 후 역할별 폴더에 배포
 *
 *   node scripts/optimize-onboarding-images.mjs
 */
import { mkdir, stat, unlink } from "node:fs/promises";
import { join } from "node:path";
import sharp from "sharp";

const ROOT = join(import.meta.dirname, "..", "flutter_app", "assets", "onboarding");
const SOURCE_DIR = join(ROOT, "student");
const ROLES = ["student", "parent", "teacher"];
const FILES = ["01.png", "02.png", "03.png", "04.png"];
const LEGACY = [
  "01_wrong_analysis.png",
  "02_photo_upload.png",
  "03_unit_progress.png",
  "04_analysis_report.png",
];
const TARGET_W = 1024;
const TARGET_H = 1536;
const FLATTEN_BG = "#FAFAFA";

async function optimizeOne(srcPath, destPath) {
  const before = (await stat(srcPath)).size;
  await sharp(srcPath)
    .rotate()
    .resize(TARGET_W, TARGET_H, {
      fit: "inside",
      withoutEnlargement: true,
    })
    .flatten({ background: FLATTEN_BG })
    .png({ compressionLevel: 9, effort: 10 })
    .toFile(destPath);
  const after = (await stat(destPath)).size;
  return { before, after };
}

async function main() {
  const tmpDir = join(ROOT, ".optimized");
  await mkdir(tmpDir, { recursive: true });

  const stats = [];
  for (const file of FILES) {
    const src = join(SOURCE_DIR, file);
    const tmp = join(tmpDir, file);
    const result = await optimizeOne(src, tmp);
    stats.push({ file, ...result });
    console.log(
      `${file}: ${(result.before / 1024).toFixed(0)}KB → ${(result.after / 1024).toFixed(0)}KB`,
    );
  }

  for (const role of ROLES) {
    const dir = join(ROOT, role);
    await mkdir(dir, { recursive: true });
    for (const file of FILES) {
      await sharp(join(tmpDir, file)).toFile(join(dir, file));
    }
    for (const legacy of LEGACY) {
      try {
        await unlink(join(dir, legacy));
        console.log(`removed ${role}/${legacy}`);
      } catch {
        /* already gone */
      }
    }
  }

  for (const file of FILES) {
    try {
      await unlink(join(tmpDir, file));
    } catch {
      /* */
    }
  }

  const totalBefore = stats.reduce((s, x) => s + x.before, 0);
  const totalAfter = stats.reduce((s, x) => s + x.after, 0);
  console.log(
    `\nTotal: ${(totalBefore / 1024 / 1024).toFixed(2)}MB → ${(totalAfter / 1024 / 1024).toFixed(2)}MB per role`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
