#!/usr/bin/env node
/**
 * 로컬: node --env-file=.env.local scripts/smoke-accurate-pipeline.mjs
 *
 * 검증 순서:
 * 1) gpt-5 배포 Responses API 간단 JSON
 * 2) refineSolutionAnalysis 와 같은 프롬프트 축약 버전 스키마 (SolutionAnalysis 필드 존재)
 */
const base = process.env.AZURE_OPENAI_ENDPOINT?.replace(/\/$/, "");
const key = process.env.AZURE_OPENAI_API_KEY;
const model = process.env.AZURE_OPENAI_DEPLOYMENT_ACCURATE || "gpt-5.4-pro";
const preview = process.env.AZURE_OPENAI_RESPONSES_API_VERSION || "preview";
const effort = process.env.AZURE_OPENAI_REASONING_EFFORT || "medium";

if (!base || !key) {
  console.error("Missing AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_API_KEY");
  process.exit(1);
}

const url = `${base}/openai/v1/responses?api-version=${encodeURIComponent(preview)}`;

async function post(body) {
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": key,
    },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  if (!res.ok) {
    console.error("HTTP", res.status, JSON.stringify(json).slice(0, 500));
    process.exit(1);
  }
  return json;
}

function extractMessageText(data) {
  const parts = [];
  for (const item of data.output || []) {
    if (item.type !== "message" || !Array.isArray(item.content)) continue;
    for (const c of item.content) {
      if (c.type === "output_text" && c.text) parts.push(c.text);
    }
  }
  return parts.join("\n").trim();
}

console.log("1) Responses ping (json_object)...");

const j1 = await post({
  model,
  input: 'Return json only {"smoke":true,"model":"' + model + '"}',
  reasoning: { effort },
  text: { format: { type: "json_object" } },
});
const t1 = extractMessageText(j1);
JSON.parse(t1);
console.log("   OK", t1.slice(0, 80));

console.log("2) Mini refine-shaped JSON (full keys)...");

const draft = {
  problemText: "1+1=?",
  extractedStudentAnswer: "3",
  inferredCorrectAnswer: "2",
  isLikelyCorrect: false,
  confidence: 0.4,
  solutionSteps: ["잘못 더함"],
  errorSummary: "산술 오류",
  weakConcepts: ["덧셈"],
  recommendedFocus: ["기본 연산"],
};

const j2 = await post({
  model,
  input: `Refine this student solution analysis JSON. Return a single json object with keys: problemText, extractedStudentAnswer, inferredCorrectAnswer, isLikelyCorrect, confidence, solutionSteps, errorSummary, weakConcepts, recommendedFocus.
Draft: ${JSON.stringify(draft)}`,
  reasoning: { effort },
  text: { format: { type: "json_object" } },
});

const t2 = extractMessageText(j2);
const refined = JSON.parse(t2);
const keys = [
  "problemText",
  "extractedStudentAnswer",
  "inferredCorrectAnswer",
  "isLikelyCorrect",
  "confidence",
  "solutionSteps",
  "errorSummary",
  "weakConcepts",
  "recommendedFocus",
];

for (const k of keys) {
  if (!(k in refined)) {
    console.error("Missing key", k);
    process.exit(1);
  }
}
console.log("   OK inferredCorrectAnswer=", refined.inferredCorrectAnswer);

console.log("All smoke checks passed.");
