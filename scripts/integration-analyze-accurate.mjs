/**
 * 로컬에서 /api/analyze 정확 모드 전체 파이프라인 검증.
 *
 * 사용: Next 가 떠 있는 상태에서
 *   INTEGRATION_BASE_URL=http://127.0.0.1:3000 node --env-file=.env.local scripts/integration-analyze-accurate.mjs
 *
 * 또는 package.json 의 integration:accurate (서버를 붙여서 실행)
 */
import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const imgCandidates = [
  join(root, "문제풀이.png"),
  join(root, "flutter_app/web/favicon.png"),
];
const imgPath = imgCandidates.find((p) => existsSync(p));
if (!imgPath) {
  console.error("No test image found (문제풀이.png or flutter_app/web/favicon.png)");
  process.exit(1);
}

const base = (
  process.env.INTEGRATION_BASE_URL || "http://127.0.0.1:3000"
).replace(/\/$/, "");
const buf = readFileSync(imgPath);
const ext = imgPath.toLowerCase().endsWith(".jpg") || imgPath.toLowerCase().endsWith(".jpeg")
  ? "jpeg"
  : "png";
const mime = ext === "jpeg" ? "image/jpeg" : "image/png";

const form = new FormData();
form.append("qualityMode", "accurate");
form.append("image", new Blob([buf], { type: mime }), `integration-test.${ext}`);

const t0 = Date.now();
const res = await fetch(`${base}/api/analyze`, {
  method: "POST",
  body: form,
  signal: AbortSignal.timeout(600_000),
});
const ms = Date.now() - t0;
const text = await res.text();

if (!res.ok) {
  console.error("HTTP", res.status, text.slice(0, 800));
  process.exit(1);
}

let j;
try {
  j = JSON.parse(text);
} catch {
  console.error("Not JSON", text.slice(0, 400));
  process.exit(1);
}

if (j.qualityMode !== "accurate") {
  console.error("qualityMode mismatch", j.qualityMode);
  process.exit(1);
}
if (!j.submission?.analysis?.problemText) {
  console.error("missing submission.analysis");
  process.exit(1);
}
if (!Array.isArray(j.problemSet?.problems) || j.problemSet.problems.length !== 5) {
  console.error("problemSet.problems expected length 5, got", j.problemSet?.problems?.length);
  process.exit(1);
}

console.log(
  "OK accurate full pipeline",
  `${ms}ms`,
  "submissionId=",
  j.submissionId,
  "problemSetId=",
  j.problemSetId,
);
