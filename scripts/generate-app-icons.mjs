#!/usr/bin/env node
/**
 * 우열 3D hero icon set — Azure OpenAI gpt-image-2
 *
 *   node --env-file=.env.local scripts/generate-app-icons.mjs
 *   node --env-file=.env.local scripts/generate-app-icons.mjs --priority 1
 *   node --env-file=.env.local scripts/generate-app-icons.mjs --id training_empty_new
 *   node --env-file=.env.local scripts/generate-app-icons.mjs --force
 */
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const manifestPath = join(root, "flutter_app/assets/icons/3d/manifest.json");
const outDir = join(root, "flutter_app/assets/icons/3d");

const args = process.argv.slice(2);
const force = args.includes("--force");
const priorityArg = args.find((a) => a.startsWith("--priority"));
const priorityFilter = priorityArg
  ? Number(priorityArg.split("=")[1] ?? args[args.indexOf("--priority") + 1])
  : null;
const idArg = args.find((a) => a.startsWith("--id"));
const idFilter = idArg
  ? idArg.includes("=")
    ? idArg.split("=")[1]
    : args[args.indexOf("--id") + 1]
  : null;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function stripIconBackground(outPath) {
  const script = join(root, "scripts/fix-icon-transparency.py");
  const result = spawnSync("python3", [script, outPath], {
    encoding: "utf8",
    cwd: root,
  });
  if (result.status !== 0) {
    const detail = (result.stderr || result.stdout || "").trim();
    throw new Error(`background strip failed: ${detail || "python3 error"}`);
  }
}

function needEnv() {
  const ep = process.env.AZURE_OPENAI_ENDPOINT?.replace(/\/$/, "");
  const key = process.env.AZURE_OPENAI_API_KEY;
  if (!ep || !key) {
    throw new Error("Missing AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_API_KEY in .env.local");
  }
  return { ep, key };
}

async function generateIcon(manifest, icon) {
  const { ep, key } = needEnv();
  const deployment =
    process.env.AZURE_OPENAI_IMAGE_DEPLOYMENT?.trim() || manifest.deployment;
  const apiVersion =
    process.env.AZURE_OPENAI_IMAGE_API_VERSION?.trim() || "2025-04-01-preview";
  const url = `${ep}/openai/deployments/${encodeURIComponent(deployment)}/images/generations?api-version=${encodeURIComponent(apiVersion)}`;

  const prompt = `${manifest.masterPrompt}\n\nSubject: ${icon.prompt}\nBrand accent color: ${icon.color}.`;

  const useTransparentApi =
    !deployment.includes("gpt-image-2") && !String(manifest.model).includes("gpt-image-2");

  const body = {
    prompt,
    model: manifest.model,
    size: manifest.size,
    n: 1,
    quality: manifest.quality,
    output_format: "png",
  };
  if (useTransparentApi) {
    body.background = "transparent";
  }

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": key,
    },
    body: JSON.stringify(body),
  });

  const text = await res.text();
  if (!res.ok) {
    throw new Error(`[${icon.id}] HTTP ${res.status}: ${text.slice(0, 400)}`);
  }

  const json = JSON.parse(text);
  const b64 = json.data?.[0]?.b64_json;
  if (!b64) {
    throw new Error(`[${icon.id}] No b64_json in response`);
  }

  const outPath = join(outDir, icon.file);
  await writeFile(outPath, Buffer.from(b64, "base64"));
  stripIconBackground(outPath);
  return outPath;
}

async function main() {
  const raw = await readFile(manifestPath, "utf8");
  const manifest = JSON.parse(raw);
  await mkdir(outDir, { recursive: true });

  let icons = manifest.icons;
  if (idFilter) {
    icons = icons.filter((i) => i.id === idFilter);
    if (icons.length === 0) {
      throw new Error(`Unknown icon id: ${idFilter}`);
    }
  } else if (priorityFilter != null && !Number.isNaN(priorityFilter)) {
    icons = icons.filter((i) => i.priority <= priorityFilter);
  }

  const log = {
    generatedAt: new Date().toISOString(),
    deployment:
      process.env.AZURE_OPENAI_IMAGE_DEPLOYMENT?.trim() || manifest.deployment,
    model: manifest.model,
    quality: manifest.quality,
    results: [],
  };

  console.log(`Generating ${icons.length} icon(s) → ${outDir}`);

  for (const icon of icons) {
    const outPath = join(outDir, icon.file);
    if (!force) {
      try {
        await readFile(outPath);
        console.log(`skip ${icon.id} (exists)`);
        log.results.push({ id: icon.id, file: icon.file, status: "skipped" });
        continue;
      } catch {
        // generate
      }
    }

    process.stdout.write(`generate ${icon.id}… `);
    try {
      await generateIcon(manifest, icon);
      console.log("ok");
      log.results.push({ id: icon.id, file: icon.file, status: "ok" });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.log("FAIL");
      console.error(message);
      log.results.push({ id: icon.id, file: icon.file, status: "error", error: message });
    }

    await sleep(1500);
  }

  await writeFile(
    join(outDir, "generation-log.json"),
    `${JSON.stringify(log, null, 2)}\n`,
  );

  const failed = log.results.filter((r) => r.status === "error").length;
  console.log(`Done. ok=${log.results.filter((r) => r.status === "ok").length} skipped=${log.results.filter((r) => r.status === "skipped").length} failed=${failed}`);
  if (failed > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
