#!/usr/bin/env node
/**
 * 현재 `.env.local` 기준 Azure·파이프라인 스모크.
 *
 *   yarn smoke:env
 *   # 또는
 *   node --env-file=.env.local scripts/smoke-env.mjs
 *
 * 검증: (1) smoke-accurate-pipeline (2) 비전 배포 텍스트 JSON (3) 동일 배포 멀티모달(재시도)
 * /api/analyze 는 비전 단계에서 Azure 429 가 나올 수 있어 이 스크립트엔 포함하지 않습니다.
 */
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function needEnv() {
  const ep = process.env.AZURE_OPENAI_ENDPOINT?.replace(/\/$/, "");
  const key = process.env.AZURE_OPENAI_API_KEY;
  if (!ep || !key) {
    console.error("Missing AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_API_KEY");
    process.exit(1);
  }
  return { ep, key };
}

async function chatTextJson() {
  const { ep, key } = needEnv();
  const dep = (process.env.AZURE_OPENAI_DEPLOYMENT_VISION || "gpt-5.4").trim();
  const ver = process.env.AZURE_OPENAI_API_VERSION || "2024-08-01-preview";
  const url = `${ep}/openai/deployments/${encodeURIComponent(dep)}/chat/completions?api-version=${encodeURIComponent(ver)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": key,
    },
    body: JSON.stringify({
      messages: [
        { role: "user", content: 'Reply JSON only: {"vision_dep_text":true}' },
      ],
      response_format: { type: "json_object" },
      max_completion_tokens: 80,
    }),
  });
  const t = await res.text();
  if (!res.ok) {
    console.error(`[${dep} text]`, res.status, t.slice(0, 400));
    return false;
  }
  console.log(`[${dep} text] OK`, t.slice(0, 120).replace(/\s+/g, " "));
  return true;
}

async function chatVisionOnce() {
  const { ep, key } = needEnv();
  const dep = (process.env.AZURE_OPENAI_DEPLOYMENT_VISION || "gpt-5.4").trim();
  const ver = process.env.AZURE_OPENAI_API_VERSION || "2024-08-01-preview";
  const png =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
  const dataUrl = `data:image/png;base64,${png}`;
  const url = `${ep}/openai/deployments/${encodeURIComponent(dep)}/chat/completions?api-version=${encodeURIComponent(ver)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": key,
    },
    body: JSON.stringify({
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: 'Return JSON only: {"vision_smoke": true}',
            },
            { type: "image_url", image_url: { url: dataUrl } },
          ],
        },
      ],
      max_completion_tokens: 120,
    }),
  });
  const t = await res.text();
  return { ok: res.ok, status: res.status, body: t };
}

async function chatVisionWithRetries() {
  const max = 4;
  for (let i = 0; i < max; i++) {
    const r = await chatVisionOnce();
    if (r.ok) {
      console.log(
        "[vision multimodal]",
        "OK",
        r.body.slice(0, 100).replace(/\s+/g, " "),
      );
      return true;
    }
    console.warn(
      `[vision multimodal] attempt ${i + 1}/${max}`,
      r.status,
      r.body.slice(0, 200),
    );
    await new Promise((r) => setTimeout(r, 2500 * (i + 1)));
  }
  console.error("[vision multimodal] FAIL after retries (often Azure 429 / quota)");
  return false;
}

console.log("=== 1) smoke-accurate-pipeline (Responses + refine-shaped JSON) ===");
const acc = spawnSync(
  process.execPath,
  ["--env-file=.env.local", join(root, "scripts/smoke-accurate-pipeline.mjs")],
  {
    cwd: root,
    stdio: "inherit",
    env: process.env,
  },
);
if (acc.status !== 0) process.exit(acc.status ?? 1);

console.log("\n=== 2) Vision deployment — Chat Completions + JSON (text only) ===");
if (!(await chatTextJson())) process.exit(1);

console.log("\n=== 3) Vision deployment — Chat Completions + image_url ===");
const visionOk = await chatVisionWithRetries();
if (!visionOk) {
  console.warn(
    "\n(Warning) Vision path flaky — /api/analyze may return 500 when Azure returns 429 here.",
  );
  process.exit(2);
}

console.log("\nAll smoke-env checks passed.");
process.exit(0);
