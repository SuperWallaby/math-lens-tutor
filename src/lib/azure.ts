import { randomUUID } from "crypto";
import type { AnalyzeQualityMode } from "./analyze-mode";
import { env } from "./env";
import { sampleAnalysis, sampleProblemSet } from "./sample";
import {
  generatedProblemSetSchema,
  solutionAnalysisSchema,
  type GeneratedProblemSet,
  type SolutionAnalysis,
} from "./types";

/** 비전 채팅 완료(멀티모달) — gpt-4.1 등 */
const ANALYZE_TEMPERATURE = 0.22;
/** 레거시 텍스트 채팅 완료 (gpt-5 제외 배포) */
const GENERATE_TEMPERATURE = 0.45;

/**
 * GPT-5 계열 Chat Completions 는 Azure 가 `temperature` 사용자 지정을 거부하고
 * `max_tokens` 대신 `max_completion_tokens` 를 요구함(비전 경로 포함).
 */
function chatUsesGpt5StyleParameters(deploymentName: string): boolean {
  return /\bgpt-5\b/i.test(deploymentName);
}

function parseJsonFromText(text: string) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const jsonText = fenced?.[1] ?? text;
  return JSON.parse(jsonText.trim());
}

function parseResponsesDeploymentRules(
  raw: string | undefined,
): string[] {
  if (!raw?.trim()) return [];
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

/** 모듈 로드 시 한 번만 파싱 */
const responsesDeploymentRules = parseResponsesDeploymentRules(
  env.azureOpenAiResponsesDeployments,
);

/**
 * 텍스트 전용 JSON 호출에 Responses API 를 쓸지 여부.
 * AZURE_OPENAI_RESPONSES_DEPLOYMENTS 가 있으면 그 규칙만 따르고,
 * 비어 있으면 배포 이름에 `gpt-5` 포함 시 예전과 동일하게 자동.
 */
export function deploymentUsesResponsesApi(deploymentName: string): boolean {
  if (responsesDeploymentRules.length > 0) {
    return responsesDeploymentRules.some((rule) =>
      matchesResponsesDeploymentRule(deploymentName, rule),
    );
  }
  return /\bgpt-5\b/i.test(deploymentName);
}

/** 정확 일치 또는 `규칙*` 접두사 일치 */
function matchesResponsesDeploymentRule(
  deploymentName: string,
  rule: string,
): boolean {
  if (rule.endsWith("*")) {
    const prefix = rule.slice(0, -1);
    return prefix.length > 0 && deploymentName.startsWith(prefix);
  }
  return deploymentName === rule;
}

function reasoningEffortForResponses():
  | "low"
  | "medium"
  | "high" {
  const r = env.azureOpenAiReasoningEffort.trim().toLowerCase();
  if (r === "low" || r === "medium" || r === "high") return r;
  return "medium";
}

/** Responses API 의 json_object 는 프롬프트에 json 언급이 필요함 */
function ensureJsonMention(prompt: string): string {
  if (/json/i.test(prompt)) return prompt;
  return `${prompt}\n\nReturn valid JSON only.`;
}

export function hasAzureOpenAiConfig() {
  return Boolean(
    env.azureOpenAiEndpoint &&
      env.azureOpenAiApiKey &&
      (env.azureOpenAiDeployment ||
        env.azureOpenAiDeploymentFast ||
        env.azureOpenAiDeploymentBalanced ||
        env.azureOpenAiDeploymentAccurate),
  );
}

export function resolveAzureDeploymentName(
  mode: AnalyzeQualityMode,
): string | null {
  const base = env.azureOpenAiDeployment?.trim();
  switch (mode) {
    case "fast":
      return (
        env.azureOpenAiDeploymentFast?.trim() ||
        base ||
        null
      );
    case "balanced":
      return (
        env.azureOpenAiDeploymentBalanced?.trim() ||
        base ||
        null
      );
    case "accurate":
      return (
        env.azureOpenAiDeploymentAccurate?.trim() ||
        base ||
        null
      );
    default:
      return base || null;
  }
}

/**
 * Chat Completions 로 풀이 이미지를 넣는 호출에 쓰는 배포.
 */
export function resolveVisionDeploymentName(): string | null {
  return (
    env.azureOpenAiDeploymentVision?.trim() ||
    resolveAzureDeploymentName("balanced") ||
    resolveAzureDeploymentName("fast") ||
    env.azureOpenAiDeployment?.trim() ||
    null
  );
}

function normalizeImageMimeType(file: File): string {
  const raw = (file.type ?? "").trim().toLowerCase();
  const vague =
    !raw ||
    raw === "application/octet-stream" ||
    raw === "binary/octet-stream" ||
    raw === "image/octet-stream";

  if (!vague && raw.startsWith("image/")) {
    return raw;
  }

  const name = file.name?.toLowerCase() ?? "";
  const dot = name.lastIndexOf(".");
  const ext = dot >= 0 ? name.slice(dot) : "";
  const byExt: Record<string, string> = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
    ".heic": "image/heic",
    ".heif": "image/heif",
  };
  if (ext && byExt[ext]) {
    return byExt[ext];
  }
  return "image/jpeg";
}

function messagesIncludeVision(
  messages: Array<{
    role: "system" | "user" | "assistant";
    content:
      | string
      | Array<
          | { type: "text"; text: string }
          | {
              type: "image_url";
              image_url: { url: string };
            }
        >;
  }>,
): boolean {
  for (const m of messages) {
    if (!Array.isArray(m.content)) continue;
    for (const part of m.content) {
      if (part.type === "image_url") return true;
    }
  }
  return false;
}

function extractResponsesApiAssistantText(data: Record<string, unknown>): string {
  if (data.error && typeof data.error === "object") {
    const err = data.error as { message?: string };
    throw new Error(
      err.message ?? JSON.stringify(data.error).slice(0, 500),
    );
  }
  const output = data.output;
  if (!Array.isArray(output)) {
    throw new Error("Responses API 응답에 output 배열이 없습니다.");
  }
  const parts: string[] = [];
  for (const item of output) {
    if (
      typeof item === "object" &&
      item !== null &&
      (item as { type?: string }).type === "message"
    ) {
      const content = (item as { content?: unknown }).content;
      if (!Array.isArray(content)) continue;
      for (const c of content) {
        if (
          typeof c === "object" &&
          c !== null &&
          (c as { type?: string }).type === "output_text" &&
          typeof (c as { text?: string }).text === "string"
        ) {
          parts.push((c as { text: string }).text);
        }
      }
    }
  }
  const text = parts.join("\n").trim();
  if (!text) throw new Error("Responses API 에서 본문 텍스트가 비었습니다.");
  return text;
}

/** GPT-5 등: Responses API 로 텍스트+JSON 결과 */
async function azureResponsesCompletionJson(params: {
  deploymentName: string;
  prompt: string;
}): Promise<string> {
  const base = env.azureOpenAiEndpoint!.replace(/\/$/, "");
  const apiVersion = encodeURIComponent(env.azureOpenAiResponsesApiVersion);
  const url = `${base}/openai/v1/responses?api-version=${apiVersion}`;

  const input = ensureJsonMention(params.prompt);
  const body: Record<string, unknown> = {
    model: params.deploymentName,
    input,
    reasoning: { effort: reasoningEffortForResponses() },
    text: {
      format: {
        type: "json_object",
      },
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": env.azureOpenAiApiKey!,
    },
    body: JSON.stringify(body),
  });

  const rawJson = (await res.json()) as Record<string, unknown>;
  if (!res.ok) {
    const msg =
      typeof rawJson.error === "object" &&
      rawJson.error !== null &&
      "message" in rawJson.error
        ? String((rawJson.error as { message?: string }).message)
        : JSON.stringify(rawJson).slice(0, 600);
    throw new Error(`Azure Responses API (${res.status}): ${msg}`);
  }

  return extractResponsesApiAssistantText(rawJson);
}

/** Chat Completions — 비전 포함 또는 레거시 텍스트 전용 배포용 */
async function azureChatCompletionJson(params: {
  deploymentName: string;
  messages: Array<{
    role: "system" | "user" | "assistant";
    content:
      | string
      | Array<
          | { type: "text"; text: string }
          | {
              type: "image_url";
              image_url: { url: string };
            }
        >;
  }>;
  temperature: number;
  maxTokens?: number;
}): Promise<string> {
  const base = env.azureOpenAiEndpoint!.replace(/\/$/, "");
  const deployment = encodeURIComponent(params.deploymentName);
  const apiVersion = encodeURIComponent(env.azureOpenAiApiVersion);
  const url = `${base}/openai/deployments/${deployment}/chat/completions?api-version=${apiVersion}`;

  const usesVision = messagesIncludeVision(params.messages);
  const legacyChat = !chatUsesGpt5StyleParameters(params.deploymentName);
  const payload: Record<string, unknown> = {
    messages: params.messages,
  };
  if (legacyChat) {
    payload.temperature = params.temperature;
    payload.max_tokens = params.maxTokens ?? 4096;
  } else {
    payload.max_completion_tokens = params.maxTokens ?? 4096;
  }
  if (!usesVision) {
    payload.response_format = { type: "json_object" };
  }

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": env.azureOpenAiApiKey!,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errBody = await res.text();
    throw new Error(
      `Azure OpenAI 오류 (${res.status}): ${errBody.slice(0, 500)}`,
    );
  }

  const data = (await res.json()) as {
    choices?: Array<{ message?: { content?: string | null } }>;
  };
  const text = data.choices?.[0]?.message?.content;
  if (typeof text !== "string" || !text.trim()) {
    throw new Error("Azure OpenAI 응답에 본문이 없습니다.");
  }
  return text;
}

/**
 * 텍스트 전용 JSON 완료. gpt-5 배포명이면 Responses API, 아니면 Chat Completions.
 */
async function completeTextOnlyJsonPrompt(params: {
  deploymentName: string;
  userPrompt: string;
  temperatureForChat: number;
  maxTokens: number;
}): Promise<string> {
  if (deploymentUsesResponsesApi(params.deploymentName)) {
    return azureResponsesCompletionJson({
      deploymentName: params.deploymentName,
      prompt: params.userPrompt,
    });
  }
  return azureChatCompletionJson({
    deploymentName: params.deploymentName,
    temperature: params.temperatureForChat,
    maxTokens: params.maxTokens,
    messages: [{ role: "user", content: params.userPrompt }],
  });
}

export async function analyzeSolutionImage(
  file: File,
  options: { deploymentName: string; mode: AnalyzeQualityMode },
): Promise<SolutionAnalysis> {
  if (!hasAzureOpenAiConfig()) {
    return sampleAnalysis;
  }

  const buffer = Buffer.from(await file.arrayBuffer());
  const mime = normalizeImageMimeType(file);
  const dataUrl = `data:${mime};base64,${buffer.toString("base64")}`;

  const prompt = `You are an expert Korean math tutor. Read the student's handwritten math solution image with multimodal reasoning, not OCR-only extraction.

Return only JSON matching this shape:
{
  "problemText": "string",
  "extractedStudentAnswer": "string",
  "inferredCorrectAnswer": "string",
  "isLikelyCorrect": false,
  "confidence": 0.0,
  "solutionSteps": ["string"],
  "errorSummary": "string",
  "weakConcepts": ["string"],
  "recommendedFocus": ["string"]
}

Use Korean for all explanations. If the image is ambiguous, make the best careful inference and lower confidence.
Set isLikelyCorrect to true when the student's answer and reasoning are substantially aligned with inferredCorrectAnswer; set false when clearly wrong, incomplete, or contradictory.

Math typography (required): Wrap every mathematical expression in KaTeX-compatible LaTeX. Inline: $expression$ . Display/multi-line when helpful: $$ expression $$ . Prefer \\frac{a}{b}, ^, _. In JSON strings, escape backslashes per JSON rules (typically double \\\\ ). Do NOT use stray single $ for Korean won amounts—write amounts without wrapping in dollar fences.
Every solutionSteps[i] item must ALSO wrap every LaTeX command cluster (examples: \\frac{}{}, \\sqrt{}, \\sin, \\cos, \\theta, \\angle, \\Rightarrow, \\times) in inline $…$ ; never emit raw backslash-LaTeX next to Korean without delimiters.`;

  const text = await azureChatCompletionJson({
    deploymentName: options.deploymentName,
    temperature: ANALYZE_TEMPERATURE,
    maxTokens: 4096,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: prompt },
          { type: "image_url", image_url: { url: dataUrl } },
        ],
      },
    ],
  });

  return solutionAnalysisSchema.parse(parseJsonFromText(text));
}

/**
 * 정확 모드 전용: 비전 모델 초안 분석을 추론 모델로 재검증·교정합니다.
 */
export async function refineSolutionAnalysisForAccurateMode(
  draft: SolutionAnalysis,
  options: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
  },
): Promise<SolutionAnalysis> {
  if (options.mode !== "accurate") {
    return draft;
  }
  if (!hasAzureOpenAiConfig()) {
    return draft;
  }

  const prompt = `You are an expert Korean mathematics tutor conducting a careful second-pass review.

The JSON below was extracted from a student's handwritten solution photo using a vision model. Your tasks:
1) Sanity-check OCR-like errors (digits, minus signs, fractions) and reasoning gaps.
2) Improve correctness of inferredCorrectAnswer and justification in solutionSteps (step-by-step, in Korean).
3) Sharpen errorSummary, weakConcepts, and recommendedFocus for learning impact.
4) Adjust confidence ∈ [0,1] appropriately.
5) Keep factual alignment with what the draft plausibly saw in the photo; prefer fixing internal inconsistencies.

Draft JSON to refine:
${JSON.stringify(draft, null, 2)}

Return a single JSON object with exactly these keys: problemText, extractedStudentAnswer, inferredCorrectAnswer, isLikelyCorrect, confidence, solutionSteps, errorSummary, weakConcepts, recommendedFocus.
Keep readable LaTeX: inline formulas in $ ... $ and display formulas in $$ ... $$ wherever math appears. Preserve JSON escaping rules for backslashes. Each solutionSteps line must wrap every cluster of LaTeX commands (e.g. \\frac{}{}, \\sqrt{}, \\cos, \\theta, \\angle)—never attach raw command text to Korean without $ delimiters.`;
  const raw = await completeTextOnlyJsonPrompt({
    deploymentName: options.deploymentName,
    userPrompt: prompt,
    temperatureForChat: ANALYZE_TEMPERATURE,
    maxTokens: 8192,
  });

  return solutionAnalysisSchema.parse(parseJsonFromText(raw));
}

export async function generateSimilarProblems(
  analysis: SolutionAnalysis,
  submissionId: string,
  options: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
    problemSetId?: string;
  },
): Promise<GeneratedProblemSet> {
  if (!hasAzureOpenAiConfig()) {
    const id = options.problemSetId ?? randomUUID();
    return {
      ...sampleProblemSet,
      id,
      submissionId,
    };
  }

  const setId = options.problemSetId ?? randomUUID();
  const prompt = `Create five similar Korean math practice problems based on this student's mistake analysis.

Analysis:
${JSON.stringify(analysis, null, 2)}

Return JSON only matching this exact shape:
{
  "id": "${setId}",
  "submissionId": "${submissionId}",
  "title": "string",
  "learningGoal": "string",
  "problems": [
    {
      "id": "string",
      "type": "multiple_choice",
      "title": "string",
      "prompt": "string",
      "choices": [{"id":"1","label":"string"},{"id":"2","label":"string"},{"id":"3","label":"string"},{"id":"4","label":"string"},{"id":"5","label":"string"}],
      "correctAnswer": "string",
      "explanation": "string",
      "difficulty": "easy",
      "conceptTags": ["string"],
      "chart": null,
      "jsxGraph": null
    }
  ]
}

Rules:
- id must be exactly "${setId}" and submissionId exactly "${submissionId}".
- Exactly 5 problems.
- Mix multiple_choice and free_response when useful.
- Multiple choice problems must have choices numbered 1 through 5.
- For multiple_choice, correctAnswer must be the **exact label text** of the correct option (same string as one choice's "label"), never only the choice id "1".."5".
- chart: 필요할 때만. 통계형 **막대/선**(Chart.js, type/data/options). 과제 내 데이터 시각화.
- jsxGraph: **좌표평면 기하 도형**이 필요할 때만. 없어도 풀 수 있으면 **전부 jsxGraph:null**.

jsxGraph 규격 (미사용 문제는 "jsxGraph": null):
{"diagramNeeded":true,"captionKo":"설명 한 줄","rationaleKo":"필요 이유","board":{"boundingbox":[-2,12,14,-4],"axis":true},"elements":[{"elType":"point","id":"P","coord":[1,3],"attrs":{"name":"P","fixed":true}},{"elType":"segment","parents":["P",[6,8]]}]}

허용 elType: point, segment, line, polygon, circle, arc, angle, sector, text, midpoint, perpendicular, perpendicularsegment, bisector, glider 등 (문자열 eval·functiongraph 제외).
point 는 coord 또는 parents 로 좌표 전달 가능. 다른 요소 parents 에는 참조 문자열(id) 또는 [x,y] 좌표.
각 문제 객체에 반드시 키 jsxGraph 포함(chart 와 같은 레벨).
- 문제·선지·설명은 한국어. 개념 훈련에 충실하되 과제 원문과 동일하게 복사하지 마세요.
- 모든 수학 식은 LaTeX와 동일 규격: 인라인 $ ... $ , 블록 $$ ... $$. JSON 문자열에서 역슬래시(\\) 규칙을 지킨다. 원화 기호 때문에 단일 $만 쓰지 말 것(숫자만으로 표현).

Make the problems similar enough to train the missing concept, but not identical.`;

  const text = await completeTextOnlyJsonPrompt({
    deploymentName: options.deploymentName,
    userPrompt: prompt,
    temperatureForChat: GENERATE_TEMPERATURE,
    maxTokens: 8192,
  });

  const parsed = generatedProblemSetSchema.parse(parseJsonFromText(text));
  return {
    ...parsed,
    id: setId,
    submissionId,
  };
}
