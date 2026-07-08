import { createHash } from "crypto";
import { createServer } from "http";
import { mkdir, readFile, writeFile } from "fs/promises";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

import type { Browser, Page } from "playwright";
import { chromium } from "playwright";

import {
  isR2Configured,
  publicUrlForR2Key,
  uploadToR2,
  buildVizR2Key,
} from "./object-storage";
import type { VisualizationData } from "./visualization-schema";
import {
  chartVisualizationDataSchema,
  functionGraphDataSchema,
  visualizationDataToChartConfig,
  visualizationDataToJsxDiagram,
} from "./visualization-schema";
import { sanitizeFunctionGraphData } from "./desmos-latex";

const rootDir = join(dirname(fileURLToPath(import.meta.url)), "../..");
const publicDir = join(rootDir, "public");
const flutterWebVizDir = join(rootDir, "flutter_app/web/viz");

const DESMOS_API_KEY =
  process.env.DESMOS_API_KEY?.trim() ||
  process.env.NEXT_PUBLIC_DESMOS_API_KEY?.trim() ||
  "dcb31709b452b1cf9dc26972add0fda6";

const CAPTURE_SPECS = {
  function_graph: { page: "desmos.html", width: 800, height: 400 },
  geometry: { page: "jsxgraph.html", width: 800, height: 392 },
  coordinate: { page: "jsxgraph.html", width: 800, height: 392 },
  chart: { page: "chart.html", width: 800, height: 264 },
} as const;

let httpServer: ReturnType<typeof createServer> | null = null;
let serverPort = 0;
let browser: Browser | null = null;

function encodePayload(payload: unknown): string {
  return encodeURIComponent(
    Buffer.from(JSON.stringify(payload), "utf8").toString("base64"),
  );
}

function stripAssetFields(data: Record<string, unknown>): Record<string, unknown> {
  const copy = { ...data };
  delete copy.imageUrl;
  delete copy.width;
  delete copy.height;
  delete copy.contentHash;
  return copy;
}

export function visualizationContentHash(viz: Exclude<VisualizationData, null>): string {
  const canonical = {
    type: viz.type,
    engine: viz.engine,
    data: stripAssetFields(viz.data ?? {}),
  };
  return createHash("sha256").update(JSON.stringify(canonical)).digest("hex").slice(0, 16);
}

async function ensureStaticServer(): Promise<number> {
  if (httpServer && serverPort > 0) return serverPort;

  httpServer = createServer(async (req, res) => {
    try {
      const url = new URL(req.url ?? "/", `http://127.0.0.1`);
      const rel = decodeURIComponent(url.pathname).replace(/^\/+/, "");
      const safe = rel.split("?")[0];
      const filePath = join(publicDir, safe);
      if (!filePath.startsWith(publicDir)) {
        res.writeHead(403).end();
        return;
      }
      const body = await readFile(filePath);
      const ext = safe.split(".").pop()?.toLowerCase();
      const type =
        ext === "html"
          ? "text/html; charset=utf-8"
          : ext === "js"
            ? "text/javascript; charset=utf-8"
            : ext === "css"
              ? "text/css; charset=utf-8"
              : "application/octet-stream";
      res.writeHead(200, { "Content-Type": type }).end(body);
    } catch {
      res.writeHead(404).end();
    }
  });

  await new Promise<void>((resolve) => {
    httpServer!.listen(0, "127.0.0.1", () => resolve());
  });

  const address = httpServer.address();
  if (!address || typeof address === "string") {
    throw new Error("static server failed to bind");
  }
  serverPort = address.port;
  return serverPort;
}

async function ensureBrowser(): Promise<Browser> {
  if (browser) return browser;
  browser = await chromium.launch({ headless: true });
  return browser;
}

export async function initVisualizationBaker(): Promise<void> {
  await ensureStaticServer();
  await ensureBrowser();
}

export async function shutdownVisualizationBaker(): Promise<void> {
  if (browser) {
    await browser.close();
    browser = null;
  }
  if (httpServer) {
    await new Promise<void>((resolve, reject) => {
      httpServer!.close((error) => (error ? reject(error) : resolve()));
    });
    httpServer = null;
    serverPort = 0;
  }
}

export async function withVisualizationBaker<T>(fn: () => Promise<T>): Promise<T> {
  await initVisualizationBaker();
  try {
    return await fn();
  } finally {
    await shutdownVisualizationBaker();
  }
}

async function waitForReady(page: Page) {
  await page.waitForFunction(
    () => (window as unknown as { __STUDY_VIZ_READY?: boolean }).__STUDY_VIZ_READY === true,
    undefined,
    { timeout: 90_000 },
  );
  await page.waitForTimeout(300);
}

export async function pngLooksEmpty(png: Buffer): Promise<boolean> {
  const sharp = (await import("sharp")).default;
  const { data, info } = await sharp(png).raw().toBuffer({ resolveWithObject: true });
  let ink = 0;
  const pixels = info.width * info.height;
  for (let i = 0; i < data.length; i += info.channels) {
    const r = data[i]!;
    const g = data[i + 1]!;
    const b = data[i + 2]!;
    const lum = (r + g + b) / 3;
    const sat = Math.max(r, g, b) - Math.min(r, g, b);
    if (lum > 215) continue;
    if (lum > 175 && sat < 14) continue;
    ink += 1;
  }
  return ink / pixels < 0.0015;
}

function capturePayloadForVisualization(
  viz: Exclude<VisualizationData, null>,
): { page: string; payload: unknown; width: number; height: number } | null {
  const spec = CAPTURE_SPECS[viz.type as keyof typeof CAPTURE_SPECS];
  if (!spec) return null;

  if (viz.type === "function_graph") {
    const data = sanitizeFunctionGraphData(functionGraphDataSchema.parse(viz.data));
    return {
      page: spec.page,
      width: spec.width,
      height: spec.height,
      payload: { ...data, apiKey: DESMOS_API_KEY },
    };
  }

  if (viz.type === "geometry" || viz.type === "coordinate") {
    const diagram = visualizationDataToJsxDiagram(viz);
    if (!diagram?.diagramNeeded) return null;
    return { page: spec.page, width: spec.width, height: spec.height, payload: diagram };
  }

  if (viz.type === "chart") {
    const chart = visualizationDataToChartConfig(viz);
    if (!chart) return null;
    return { page: spec.page, width: spec.width, height: spec.height, payload: chart };
  }

  return null;
}

async function capturePng(params: {
  page: string;
  payload: unknown;
  width: number;
  height: number;
}): Promise<Buffer> {
  const port = await ensureStaticServer();
  const b = await ensureBrowser();
  const page = await b.newPage({ viewport: { width: params.width, height: params.height } });
  try {
    const hash = encodePayload(params.payload);
    const apiQuery =
      params.page === "desmos.html"
        ? `?apiKey=${encodeURIComponent(DESMOS_API_KEY)}`
        : "";
    const url = `http://127.0.0.1:${port}/viz-capture/${params.page}${apiQuery}#${hash}`;
    await page.goto(url, { waitUntil: "load", timeout: 120_000 });
    await waitForReady(page);
    const root = page.locator("#viz-root");
    await root.waitFor({ state: "visible", timeout: 10_000 });
    let png = await root.screenshot({ type: "png" });
    if (params.page === "desmos.html" && (await pngLooksEmpty(png))) {
      await page.waitForTimeout(2000);
      png = await root.screenshot({ type: "png" });
      if (await pngLooksEmpty(png)) {
        throw new Error("desmos capture produced an empty graph");
      }
    }
    return png;
  } finally {
    await page.close();
  }
}

async function persistPng(contentHash: string, png: Buffer): Promise<string> {
  const localPaths = [
    join(publicDir, "viz", `${contentHash}.png`),
    join(flutterWebVizDir, `${contentHash}.png`),
  ];

  for (const filePath of localPaths) {
    await mkdir(dirname(filePath), { recursive: true });
    await writeFile(filePath, png);
  }

  if (isR2Configured()) {
    const key = buildVizR2Key(contentHash);
    await uploadToR2({
      key,
      body: png,
      contentType: "image/png",
      cacheControl: "public, max-age=31536000, immutable",
    });
    return publicUrlForR2Key(key) ?? `/viz/${contentHash}.png`;
  }

  return `/viz/${contentHash}.png`;
}

export async function localVizPngExists(contentHash: string): Promise<boolean> {
  try {
    await readFile(join(publicDir, "viz", `${contentHash}.png`));
    return true;
  } catch {
    return false;
  }
}

export async function bakeVisualizationPng(
  viz: Exclude<VisualizationData, null>,
): Promise<Buffer> {
  const capture = capturePayloadForVisualization(viz);
  if (!capture) {
    throw new Error(`unsupported visualization type: ${viz.type}`);
  }
  return capturePng(capture);
}

export async function storeVisualizationPng(
  contentHash: string,
  png: Buffer,
): Promise<string> {
  return persistPng(contentHash, png);
}

/** validate 후 viz 타입별 diagram/chart payload 검증용 */
export function assertBakeableVisualization(viz: Exclude<VisualizationData, null>): void {
  if (viz.type === "function_graph") {
    functionGraphDataSchema.parse(viz.data);
    return;
  }
  if (viz.type === "geometry" || viz.type === "coordinate") {
    const diagram = visualizationDataToJsxDiagram(viz);
    if (!diagram?.diagramNeeded) {
      throw new Error(`jsx diagram missing for ${viz.type}`);
    }
    return;
  }
  if (viz.type === "chart") {
    chartVisualizationDataSchema.parse(viz.data);
    return;
  }
  throw new Error(`unsupported visualization type: ${viz.type}`);
}
