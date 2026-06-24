/**
 * App Store / Play Store screenshots via Flutter Web + Playwright.
 *
 *   npm run screenshots:appstore -- --only student
 *
 * Screens: demo data via ?store_screenshot=hub-returning (no API login).
 */

import { writeFileSync } from "node:fs";
import { mkdir, unlink } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import sharp from "sharp";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const outRoot = join(root, "artifacts", "store-screenshots");

const PAD_BG = { r: 245, g: 245, b: 245 };

/** Student store lineup — bottom nav + situation-specific full screens. */
const SCREENS = [
  { file: "01-hub-first.png", mode: "hub-first", readyMs: 10_000 },
  { file: "02-hub-returning.png", mode: "hub-returning", readyMs: 9_000 },
  { file: "03-tab-upload.png", mode: "tab-upload", readyMs: 7_000 },
  { file: "04-analysis-analyzing.png", mode: "analysis-analyzing", readyMs: 6_000 },
  { file: "05-analysis-weak.png", mode: "analysis-weak", readyMs: 8_000 },
  { file: "06-practice-question.png", mode: "practice-question", readyMs: 8_000 },
  { file: "07-practice-correct.png", mode: "practice-correct", readyMs: 7_000 },
  { file: "08-practice-wrong.png", mode: "practice-wrong", readyMs: 7_000 },
  { file: "09-tab-training.png", mode: "tab-training", readyMs: 9_000 },
  { file: "10-tab-progress.png", mode: "tab-progress", readyMs: 9_000 },
  { file: "11-tab-progress-warning.png", mode: "tab-progress-warning", readyMs: 9_000 },
  { file: "05-parent-home.png", mode: "parent-home", readyMs: 8_000 },
  { file: "06-parent-explain.png", mode: "parent-explain", readyMs: 8_000 },
];

const DEVICES = [
  {
    id: "iphone-6.5",
    viewport: { width: 414, height: 896 },
    deviceScaleFactor: 3,
    pad: null,
  },
  {
    id: "iphone-6.7",
    viewport: { width: 428, height: 926 },
    deviceScaleFactor: 3,
    pad: null,
  },
  {
    id: "ipad-12.9",
    viewport: { width: 414, height: 896 },
    deviceScaleFactor: 3,
    pad: { width: 2048, height: 2732 },
  },
  {
    id: "ipad-13",
    viewport: { width: 414, height: 896 },
    deviceScaleFactor: 3,
    pad: { width: 2064, height: 2752 },
  },
  {
    id: "android-phone",
    viewport: { width: 360, height: 640 },
    deviceScaleFactor: 3,
    pad: null,
  },
  {
    id: "android-phone-hd",
    viewport: { width: 360, height: 640 },
    deviceScaleFactor: 4,
    pad: null,
  },
];

const baseUrl = (process.env.FLUTTER_APP_URL ?? "http://127.0.0.1:5050").replace(
  /\/$/,
  "",
);
const defaultSettleMs = Number(process.env.SETTLE_MS ?? "6000");
const onlyFilter = (() => {
  const idx = process.argv.indexOf("--only");
  if (idx === -1 || !process.argv[idx + 1]) return null;
  return process.argv[idx + 1].trim().toLowerCase();
})();
const deviceFilter = (() => {
  const idx = process.argv.indexOf("--device");
  if (idx === -1 || !process.argv[idx + 1]) return null;
  return process.argv[idx + 1].trim().toLowerCase();
})();

async function delay(ms) {
  await new Promise((r) => setTimeout(r, ms));
}

async function waitForFlutterAttached(page) {
  await page.waitForSelector(
    "flutter-view, FLUTTER-VIEW, flt-glass-pane, FLT-GLASS-PANE",
    { state: "attached", timeout: 180_000 },
  );
}

/** Wait until network settles, then extra time for CanvasKit + 3D assets. */
async function waitForScreenReady(page, screen, { firstLoad = false } = {}) {
  await waitForFlutterAttached(page);
  await page.waitForLoadState("networkidle", { timeout: 90_000 }).catch(() => {});
  const base = screen.readyMs ?? defaultSettleMs;
  const ms = firstLoad ? base + 4_000 : base;
  await delay(ms);
  // Second networkidle pass — catches late asset fetches (icons, fonts).
  await page.waitForLoadState("networkidle", { timeout: 45_000 }).catch(() => {});
  await delay(1_500);
}

async function padScreenshot(srcPath, destPath, targetW, targetH) {
  const meta = await sharp(srcPath).metadata();
  const w = meta.width ?? targetW;
  const h = meta.height ?? targetH;
  const left = Math.max(0, Math.floor((targetW - w) / 2));
  const top = Math.max(0, Math.floor((targetH - h) / 2));
  await sharp({
    create: {
      width: targetW,
      height: targetH,
      channels: 3,
      background: PAD_BG,
    },
  })
    .composite([{ input: srcPath, left, top }])
    .png()
    .toFile(destPath);
}

async function captureDevice(browser, device, screens) {
  const deviceDir = join(outRoot, device.id);
  await mkdir(deviceDir, { recursive: true });

  const context = await browser.newContext({
    viewport: device.viewport,
    deviceScaleFactor: device.deviceScaleFactor,
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();
  page.setDefaultTimeout(180_000);

  const captured = [];

  for (let i = 0; i < screens.length; i++) {
    const screen = screens[i];
    const url = `${baseUrl}/?store_screenshot=${encodeURIComponent(screen.mode)}`;
    console.log(`[${device.id}] ${screen.file} ← ${url}`);
    await page.goto(url, { waitUntil: "load", timeout: 180_000 });
    await waitForScreenReady(page, screen, { firstLoad: i === 0 });

    const rawPath = join(deviceDir, `.raw-${screen.file}`);
    const destPath = join(deviceDir, screen.file);
    await page.screenshot({ path: rawPath, type: "png", fullPage: false });

    if (device.pad) {
      await padScreenshot(rawPath, destPath, device.pad.width, device.pad.height);
    } else {
      await sharp(rawPath).png().toFile(destPath);
    }
    await unlink(rawPath).catch(() => {});

    captured.push({
      file: screen.file,
      mode: screen.mode,
      url,
      path: destPath.replace(`${root}/`, ""),
    });
    console.log(`  → ${destPath}`);
  }

  await context.close();
  return captured;
}

function filterScreens() {
  return SCREENS.filter(({ file, mode }) => {
    if (!onlyFilter) return true;
    if (onlyFilter === "student") {
      return !mode.startsWith("parent");
    }
    const knownModes = new Set(SCREENS.map((s) => s.mode));
    if (knownModes.has(onlyFilter)) {
      return mode === onlyFilter;
    }
    const f = onlyFilter.toLowerCase();
    return file.toLowerCase().includes(f) || mode.toLowerCase().includes(f);
  });
}

async function main() {
  const screens = filterScreens();
  if (screens.length === 0) {
    console.error("No screens matched --only", onlyFilter);
    process.exit(1);
  }

  const devices = deviceFilter
    ? DEVICES.filter((d) => d.id.includes(deviceFilter))
    : DEVICES;
  if (devices.length === 0) {
    console.error("No devices matched --device", deviceFilter);
    process.exit(1);
  }

  await mkdir(outRoot, { recursive: true });

  const browser = await chromium.launch({
    headless: true,
    args: ["--enable-webgl", "--use-gl=swiftshader"],
  });

  const manifest = {
    capturedAt: new Date().toISOString(),
    flutterAppUrl: baseUrl,
    devices: {},
  };

  for (const device of devices) {
    console.log(`\n=== ${device.id} (${screens.length} screens) ===`);
    manifest.devices[device.id] = await captureDevice(browser, device, screens);
  }

  await browser.close();

  writeFileSync(
    join(outRoot, "manifest.json"),
    JSON.stringify(manifest, null, 2),
  );

  console.log(`\nDone → ${outRoot}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
