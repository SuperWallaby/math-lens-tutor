/**
 * Capture Flutter design-review screens via web-server + Playwright.
 *
 * Prerequisite: Flutter web-server on FLUTTER_WEB_URL (default http://127.0.0.1:8080)
 *
 *   npm run capture:design-review
 *   npm run capture:design-review -- --only student_progress
 */

import { writeFileSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const outRoot = join(root, "design-review", "captures");

const keys = [
  "student_hub__first_visit",
  "student_hub__returning",
  "upload__idle",
  "analysis__analyzing",
  "analysis__result_weak",
  "analysis__result_ok",
  "practice__question",
  "practice__feedback_correct",
  "practice__feedback_wrong",
  "student_progress__grade_e12",
  "student_progress__grade_m1",
  "student_progress__chain_warning",
];

const baseUrl = (process.env.FLUTTER_WEB_URL ?? "http://127.0.0.1:8080").replace(
  /\/$/,
  "",
);
const onlyFilter = (() => {
  const idx = process.argv.indexOf("--only");
  if (idx === -1 || !process.argv[idx + 1]) return null;
  return process.argv[idx + 1].trim();
})();

/** Keys that render one screen but save under another folder (see SCREEN_MATRIX.md). */
const outputPathOverrides = {
  "analysis__analyzing": join(outRoot, "upload", "analyzing.png"),
};

function outPath(key) {
  if (outputPathOverrides[key]) return outputPathOverrides[key];
  const sep = key.indexOf("__");
  const screen = sep > 0 ? key.slice(0, sep) : key;
  const state = sep > 0 ? key.slice(sep + 2) : "default";
  return join(outRoot, screen, `${state}.png`);
}

async function delay(ms) {
  await new Promise((r) => setTimeout(r, ms));
}

/** Flutter web paints to canvas — body.innerText is not reliable. */
async function waitForFlutterReady(page, { firstLoad = false } = {}) {
  await page.waitForSelector(
    "flutter-view, FLUTTER-VIEW, flt-glass-pane, FLT-GLASS-PANE",
    { state: "attached", timeout: 180_000 },
  );
  await delay(firstLoad ? 8_000 : 5_000);
}

async function main() {
  const targets = keys.filter((k) => {
    if (!onlyFilter) return true;
    return k.startsWith(`${onlyFilter}__`) || k.startsWith(onlyFilter);
  });

  if (targets.length === 0) {
    console.error("No capture keys matched --only", onlyFilter);
    process.exit(1);
  }

  await mkdir(outRoot, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();
  page.setDefaultTimeout(120_000);

  const manifest = [];

  for (let i = 0; i < targets.length; i++) {
    const key = targets[i];
    const url = `${baseUrl}/?design_review=${encodeURIComponent(key)}`;
    console.log("Capture", key, "→", url);
    await page.goto(url, { waitUntil: "load", timeout: 180_000 });
    await waitForFlutterReady(page, { firstLoad: i === 0 });
    const dest = outPath(key);
    await mkdir(dirname(dest), { recursive: true });
    await page.screenshot({ path: dest, type: "png", fullPage: true });
    manifest.push({ key, url, file: dest.replace(`${root}/`, "") });
    console.log("Wrote", dest);
  }

  writeFileSync(
    join(outRoot, "manifest.json"),
    JSON.stringify({ capturedAt: new Date().toISOString(), items: manifest }, null, 2),
  );

  await browser.close();
  console.log(`Done: ${targets.length} captures → ${outRoot}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
