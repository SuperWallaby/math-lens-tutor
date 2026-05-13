/**
 * App Store Connect — iPad 12.9" / 13" screenshot size (portrait 2048×2732).
 * Uses Playwright: npm run capture:ipad-screens
 *
 * Env:
 *   BASE_URL — default https://study-alpha-rosy.vercel.app
 *   IMAGE_PATH — default repo root /문제풀이.png
 */

import { mkdir, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "..");

async function delay(ms) {
  await new Promise((r) => setTimeout(r, ms));
}

const BASE_URL = (process.env.BASE_URL ?? "https://study-alpha-rosy.vercel.app").replace(
  /\/$/,
  "",
);
const IMAGE_PATH = path.resolve(
  process.env.IMAGE_PATH ?? path.join(REPO_ROOT, "문제풀이.png"),
);

const VIEWPORT = { width: 2048, height: 2732, deviceScaleFactor: 1 };
const OUT_DIR = path.join(
  REPO_ROOT,
  "screen-shots",
  "ios-ipad-12.9-2048x2732",
);

async function shot(page, name) {
  const dest = path.join(OUT_DIR, name);
  await page.screenshot({
    path: dest,
    type: "png",
    clip: { x: 0, y: 0, width: VIEWPORT.width, height: VIEWPORT.height },
  });
  console.log("Wrote", dest);
}

async function main() {
  await stat(IMAGE_PATH).catch(() => {
    throw new Error(`Image not found: ${IMAGE_PATH}`);
  });
  await mkdir(OUT_DIR, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: 1,
    userAgent:
      "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
  });
  const page = await context.newPage();
  page.setDefaultTimeout(300_000);

  console.log("BASE_URL", BASE_URL);
  console.log("IMAGE_PATH", IMAGE_PATH);

  await page.goto(BASE_URL, { waitUntil: "networkidle", timeout: 120_000 });
  await delay(2500);
  await shot(page, "01-home.png");

  await page.goto(`${BASE_URL}/upload`, { waitUntil: "networkidle", timeout: 120_000 });
  await delay(2000);
  await shot(page, "02-upload.png");

  const fileInput = page.locator('input[type="file"]');
  await fileInput.setInputFiles(IMAGE_PATH);
  await delay(2000);

  const submit = page.getByRole("button", { name: /분석하고 유사 문제 생성/ });
  await submit.click();

  await page.waitForURL(/\/submissions\/[^/]+/, { timeout: 300_000 });
  await page.getByRole("heading", { name: "AI 풀이 분석" }).waitFor({
    state: "visible",
    timeout: 120_000,
  });
  await delay(3000);
  await shot(page, "03-analysis.png");

  await page.goto(`${BASE_URL}/practice/demo-set`, {
    waitUntil: "networkidle",
    timeout: 120_000,
  });
  await delay(2500);
  await shot(page, "04-practice-demo.png");

  await page.goto(`${BASE_URL}/dashboard`, {
    waitUntil: "networkidle",
    timeout: 120_000,
  });
  await delay(2500);
  await shot(page, "05-dashboard.png");

  await browser.close();
  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
