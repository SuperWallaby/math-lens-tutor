import { randomUUID } from "crypto";
import type { AnalyzeQualityMode } from "./analyze-mode";
import { env } from "./env";
import { sampleAnalysis, sampleProblemSet } from "./sample";
import type { AnalyzeProgressStep } from "./analyze-steps";
import { partialAnalysisFromVision } from "./analyze-partial";
import {
  generatedProblemSetSchema,
  normalizeVisionSolutionSteps,
  problemSolveResultSchema,
  solutionAnalysisSchema,
  tutorExpansionFromVisionSchema,
  tutorSolveAndExpandFromVisionSchema,
  visionSolutionExtractionSchema,
  type GeneratedProblemSet,
  type ProblemSolveResult,
  type SolutionAnalysis,
  type TutorExpansionFromVision,
  type TutorSolveAndExpandFromVision,
  type VisionSolutionExtraction,
} from "./types";

/** 흐림·저자신감 배지: 이 값 미만이면 imageQualityWarning */
const IMAGE_QUALITY_WARNING_THRESHOLD = 0.5;

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

/** 밸런스 모드 유사 문제 생성 등 별도 리전 Chat/Responses 호출 시 */
export type AzureCredentialOverride = {
  endpoint: string;
  apiKey: string;
};

function resolveBalancedTextRegionalCredentials(): AzureCredentialOverride | null {
  const rawEp = env.azureOpenAiBalancedRegionalEndpoint?.trim();
  const rawKey = env.azureOpenAiBalancedRegionalApiKey?.trim();
  if (!rawEp || !rawKey) return null;
  return { endpoint: rawEp.replace(/\/$/, ""), apiKey: rawKey };
}

function reasoningEffortForResponses(): "low" | "medium" | "high" {
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
  credentialOverride?: AzureCredentialOverride;
}): Promise<string> {
  const base = (
    params.credentialOverride?.endpoint ?? env.azureOpenAiEndpoint!
  ).replace(/\/$/, "");
  const apiKey =
    params.credentialOverride?.apiKey ?? env.azureOpenAiApiKey!;
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
      "api-key": apiKey,
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
  credentialOverride?: AzureCredentialOverride;
}): Promise<string> {
  const base = (
    params.credentialOverride?.endpoint ?? env.azureOpenAiEndpoint!
  ).replace(/\/$/, "");
  const apiKey =
    params.credentialOverride?.apiKey ?? env.azureOpenAiApiKey!;
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

  /** 멀티모달이 할당량·스로틀(429)에 자주 걸려 비전일 때만 재시도 */
  const maxAttempts = usesVision ? 5 : 1;
  let lastStatus = 0;
  let lastErrBody = "";

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "api-key": apiKey,
      },
      body: JSON.stringify(payload),
    });

    if (res.ok) {
      const data = (await res.json()) as {
        choices?: Array<{ message?: { content?: string | null } }>;
      };
      const text = data.choices?.[0]?.message?.content;
      if (typeof text !== "string" || !text.trim()) {
        throw new Error("Azure OpenAI 응답에 본문이 없습니다.");
      }
      return text;
    }

    lastStatus = res.status;
    lastErrBody = await res.text();
    const retryable =
      (lastStatus === 429 || lastStatus === 503) && attempt < maxAttempts - 1;
    if (!retryable) {
      break;
    }
    const ra = res.headers.get("retry-after");
    const fromHeader = ra ? parseInt(ra, 10) * 1000 : NaN;
    const backoff = Number.isFinite(fromHeader)
      ? Math.min(20_000, fromHeader)
      : Math.min(12_000, 400 * 2 ** attempt);
    await new Promise((r) => setTimeout(r, backoff));
  }

  throw new Error(
    `Azure OpenAI 오류 (${lastStatus}): ${lastErrBody.slice(0, 500)}`,
  );
}

/**
 * 텍스트 전용 JSON 완료.
 *
 * - **Chat Completions** (대부분 배포): `response_format: { type: "json_object" }` 로 응답을 JSON으로 제한
 *   (단, 메시지에 `image_url` 이 있으면 비전 호환 이슈로 `json_object` 를 붙이지 않음 → `azureChatCompletionJson`)
 * - **GPT-5 계열 Responses API**: `text.format.type: "json_object"` (`azureResponsesCompletionJson`)
 *
 * 따라서 `expandAnalysisFromVisionDraft` · `refineSolutionAnalysisForAccurateMode` 같은 **순수 텍스트** 호출은
 * 이미 API 레벨에서 JSON만 나오도록 연결되어 있다.
 */
async function completeTextOnlyJsonPrompt(params: {
  deploymentName: string;
  userPrompt: string;
  temperatureForChat: number;
  maxTokens: number;
  credentialOverride?: AzureCredentialOverride;
}): Promise<string> {
  if (deploymentUsesResponsesApi(params.deploymentName)) {
    return azureResponsesCompletionJson({
      deploymentName: params.deploymentName,
      prompt: params.userPrompt,
      credentialOverride: params.credentialOverride,
    });
  }
  return azureChatCompletionJson({
    deploymentName: params.deploymentName,
    temperature: params.temperatureForChat,
    maxTokens: params.maxTokens,
    messages: [{ role: "user", content: params.userPrompt }],
    credentialOverride: params.credentialOverride,
  });
}

function mergeVisionMetricsIntoAnalysis(
  expansion: TutorExpansionFromVision,
  vision: VisionSolutionExtraction,
  solved: ProblemSolveResult,
): SolutionAnalysis {
  const warn =
    vision.imageClarityScore < IMAGE_QUALITY_WARNING_THRESHOLD ||
    vision.extractionConfidence < IMAGE_QUALITY_WARNING_THRESHOLD;
  return {
    ...expansion,
    problemText: vision.problemText,
    extractedStudentAnswer: vision.extractedStudentAnswer,
    inferredCorrectAnswer: solved.inferredCorrectAnswer,
    referenceSolutionSteps: solved.referenceSolutionSteps,
    solutionSteps: normalizeVisionSolutionSteps(vision.solutionSteps),
    imageQualityWarning: warn,
    visionImageClarityScore: vision.imageClarityScore,
    visionExtractionConfidence: vision.extractionConfidence,
  };
}

/**
 * 2단계-A: 인쇄된 문제 지문만으로 정답·모범 풀이 (학생 손글씨 OCR 은 보지 않음).
 * 추정 정답은 이 결과를 우선한다.
 */
export async function solveProblemFromVisionText(
  problemText: string,
  options: { deploymentName: string },
): Promise<ProblemSolveResult> {
  if (!hasAzureOpenAiConfig()) {
    return {
      inferredCorrectAnswer: sampleAnalysis.inferredCorrectAnswer,
      referenceSolutionSteps: [...sampleAnalysis.solutionSteps],
    };
  }

  const prompt = `You are an expert Korean middle/high school mathematics solver.

Solve ONLY from the printed problem below. You do NOT see any student handwriting.

Problem (from OCR of the worksheet):
${problemText}

Tasks:
1) Solve completely with rigorous case analysis. For "가능한 a의 개수", "몇 개", "총 몇" questions, the final answer must be ONE non-negative integer (or simplified fraction if the problem asks for a fraction).
2) List referenceSolutionSteps: 4–12 short steps in Korean showing YOUR correct reasoning (KaTeX $...$ for math). These are the model answer steps, not student work.
3) Set inferredCorrectAnswer to the final answer only (compact; KaTeX allowed). For counting problems use digits like "17" not prose.

Rules:
- Do not copy numbers from any student notes (you were not given any).
- Check absolute value inequalities carefully (e.g. $|a| \\le a$ forces $a \\ge 0$).
- Divisor-count conditions: enumerate all cases, then count distinct valid values.
- Double-check the final count before responding.

Return JSON only:
{
  "inferredCorrectAnswer": "string",
  "referenceSolutionSteps": ["string", "..."]
}`;

  const raw = await completeTextOnlyJsonPrompt({
    deploymentName: options.deploymentName,
    userPrompt: prompt,
    temperatureForChat: ANALYZE_TEMPERATURE,
    maxTokens: 8192,
  });

  return problemSolveResultSchema.parse(parseJsonFromText(raw));
}

/** 1단계: 이미지에서 문제·손글씀 풀이 단계·답 + 이미지 품질만 */
export async function extractSolutionImageVision(
  file: File,
  options: { deploymentName: string },
): Promise<VisionSolutionExtraction> {
  if (!hasAzureOpenAiConfig()) {
    return {
      problemText: sampleAnalysis.problemText,
      extractedStudentAnswer: sampleAnalysis.extractedStudentAnswer,
      solutionSteps: [...sampleAnalysis.solutionSteps],
      imageClarityScore: 1,
      extractionConfidence: 1,
    };
  }

  const buffer = Buffer.from(await file.arrayBuffer());
  const mime = normalizeImageMimeType(file);
  const dataUrl = `data:${mime};base64,${buffer.toString("base64")}`;

  const prompt = `You are a strict transcription model for Korean math worksheets. Look at ONE student solution photo.

Extract only what is visibly written or strongly implied by the student's handwriting. You are not a math solver: do not tutor, infer the textbook answer, judge right/wrong, repair algebra, complete missing lines, normalize the student's math, or convert wrong work into a correct solution.

Uncertainty policy:
- For **problemText**, be conservative. If an important condition, number, symbol, or word is unclear, write [unclear] rather than guessing.
- For the student's **extractedStudentAnswer** and **solutionSteps**, if the surrounding handwriting/math strongly suggests one reading, write your best guess followed by (?) — for example $x = 2(?)$ or $-\frac{1}{2}(?)$.
- Use [unclear] only when there is no reasonable guess.
- Lower extractionConfidence for every guessed symbol, guessed answer, or partially visible line.

1) **problemText**: Full problem statement/instructions visible on the sheet (Korean; KaTeX $...$ for math where written). Preserve visible numbering and conditions.

2) **extractedStudentAnswer**: Use the student's final/boxed/circled answer when marked. If the mark is unclear but a final answer is strongly suggested, include the best guess with (?). If no final answer is reasonably identifiable, return an empty string "". Do not infer the correct textbook answer.

3) **solutionSteps**: Each visible line or logical step of the student's **handwritten work**, in reading order (top-to-bottom, left-to-right). One array element per step/line. Transcribe faithfully; use KaTeX $...$ for formulas as they appear. If only scratch with no clear order, keep the best visible reading order. Do not add teaching commentary.

4) **imageClarityScore** (0.0–1.0):
- 0.90–1.00: all text and symbols comfortably readable
- 0.70–0.89: mostly readable, minor ambiguity
- 0.50–0.69: some important symbols/lines ambiguous
- below 0.50: blurry, low-resolution, dark, glare, or not comfortably readable

5) **extractionConfidence** (0.0–1.0): Confidence that the strings above match what is on the paper. Lower this if any formula, sign, exponent, denominator, or final answer is uncertain.

Return only JSON matching this exact shape:
{
  "problemText": "string",
  "extractedStudentAnswer": "string",
  "solutionSteps": ["string", "..."],
  "imageClarityScore": 0.0,
  "extractionConfidence": 0.0
}`;

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

  return visionSolutionExtractionSchema.parse(parseJsonFromText(text));
}

/** 2단계: 텍스트 전용 튜터 모델 — 나머지 분석 채우기 */
export async function expandAnalysisFromVisionDraft(
  vision: VisionSolutionExtraction,
  options: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
    solved: ProblemSolveResult;
  },
): Promise<SolutionAnalysis> {
  if (!hasAzureOpenAiConfig()) {
    const expansion: TutorExpansionFromVision = {
      problemText: sampleAnalysis.problemText,
      extractedStudentAnswer: sampleAnalysis.extractedStudentAnswer,
      inferredCorrectAnswer: options.solved.inferredCorrectAnswer,
      confidence: sampleAnalysis.confidence,
      errorSummary: sampleAnalysis.errorSummary,
      weakConcepts: sampleAnalysis.weakConcepts,
      recommendedFocus: sampleAnalysis.recommendedFocus,
    };
    return mergeVisionMetricsIntoAnalysis(expansion, vision, options.solved);
  }

  const prompt = `You are an expert Korean mathematics tutor — **text-only**. You do not see the photo.

A separate solver already computed the **authoritative correct answer** from the printed problem only:
- inferredCorrectAnswer (authoritative): ${JSON.stringify(options.solved.inferredCorrectAnswer)}
- referenceSolutionSteps (model solution): ${JSON.stringify(options.solved.referenceSolutionSteps, null, 2)}

Vision OCR JSON (student photo — may include scratch notes, prime lists, etc.):
${JSON.stringify(vision, null, 2)}

IMPORTANT:
- vision.solutionSteps are **student handwriting / scratch notes**, NOT the model solution. Numbers in solutionSteps (e.g. lists of primes) are NOT automatically the student's final answer.
- The student's final answer is **only** vision.extractedStudentAnswer.
- Compare the student to the authoritative answer and referenceSolutionSteps above.

Your tasks:
1) Copy inferredCorrectAnswer **exactly** as given above (same string).
2) Write errorSummary (short, Korean): is the student correct? What went wrong?
3) List weakConcepts and recommendedFocus (Korean); empty arrays if unknown.
4) Set confidence ∈ [0,1] for your diagnosis quality.

RULES:
- Repeat problemText and extractedStudentAnswer **verbatim** from the vision JSON.
- Do NOT output solutionSteps or referenceSolutionSteps (server attaches them).

Return JSON with exactly these keys:
problemText, extractedStudentAnswer, inferredCorrectAnswer, confidence, errorSummary, weakConcepts, recommendedFocus

Use Korean for prose. KaTeX $...$ for math in errorSummary.`;

  // 위 프롬프트와 별개로, 출력 형식은 completeTextOnlyJsonPrompt 안에서
  // Chat: response_format=json_object / Responses: text.format=json_object 로 이미 강제됨.
  const raw = await completeTextOnlyJsonPrompt({
    deploymentName: options.deploymentName,
    userPrompt: prompt,
    temperatureForChat: ANALYZE_TEMPERATURE,
    maxTokens: 8192,
  });

  const expansion = tutorExpansionFromVisionSchema.parse(parseJsonFromText(raw));
  return mergeVisionMetricsIntoAnalysis(expansion, vision, options.solved);
}

/**
 * 정답 풀이 + 진단을 한 번의 텍스트 호출로 처리 (정확도 유지, 왕복 1회 절감).
 */
export async function solveAndExpandFromVision(
  vision: VisionSolutionExtraction,
  options: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
  },
): Promise<SolutionAnalysis> {
  if (!hasAzureOpenAiConfig()) {
    const solved: ProblemSolveResult = {
      inferredCorrectAnswer: sampleAnalysis.inferredCorrectAnswer,
      referenceSolutionSteps: sampleAnalysis.referenceSolutionSteps ?? [
        ...sampleAnalysis.solutionSteps,
      ],
    };
    return expandAnalysisFromVisionDraft(vision, {
      deploymentName: options.deploymentName,
      mode: options.mode,
      solved,
    });
  }

  const prompt = `You are an expert Korean middle/high school mathematics tutor — **text-only**. You do not see the photo.

Vision OCR JSON (student photo — may include scratch notes):
${JSON.stringify(vision, null, 2)}

Work in two strict phases in one response:

**Phase A — Solve (printed problem only)**
- Use ONLY vision.problemText. Ignore vision.solutionSteps and any student scratch lists (e.g. prime lists) for solving.
- Solve completely with rigorous case analysis. For counting questions ("가능한 a의 개수", "몇 개"), inferredCorrectAnswer must be ONE non-negative integer (or simplified fraction if asked).
- referenceSolutionSteps: 4–12 short Korean steps with KaTeX $...$ for YOUR model solution (not student handwriting).
- Check absolute value inequalities (e.g. $|a| \\le a$ forces $a \\ge 0$) and divisor-count cases.

**Phase B — Diagnose (student vs your answer)**
- vision.solutionSteps are **student handwriting / scratch**, NOT your solution.
- The student's final answer is **only** vision.extractedStudentAnswer.
- Compare the student to your Phase A answer.
- problemText and extractedStudentAnswer: copy **verbatim** from the vision JSON.
- errorSummary (Korean): correct or what went wrong. weakConcepts, recommendedFocus (Korean arrays; empty if none).
- confidence ∈ [0,1] for diagnosis quality.

Return JSON only with exactly these keys:
problemText, extractedStudentAnswer, inferredCorrectAnswer, referenceSolutionSteps, confidence, errorSummary, weakConcepts, recommendedFocus

Use Korean for prose. KaTeX $...$ in errorSummary and steps.`;

  const raw = await completeTextOnlyJsonPrompt({
    deploymentName: options.deploymentName,
    userPrompt: prompt,
    temperatureForChat: ANALYZE_TEMPERATURE,
    maxTokens: 8192,
  });

  const combined: TutorSolveAndExpandFromVision =
    tutorSolveAndExpandFromVisionSchema.parse(parseJsonFromText(raw));
  const solved: ProblemSolveResult = {
    inferredCorrectAnswer: combined.inferredCorrectAnswer,
    referenceSolutionSteps: combined.referenceSolutionSteps,
  };
  const expansion: TutorExpansionFromVision = {
    problemText: combined.problemText,
    extractedStudentAnswer: combined.extractedStudentAnswer,
    inferredCorrectAnswer: combined.inferredCorrectAnswer,
    confidence: combined.confidence,
    errorSummary: combined.errorSummary,
    weakConcepts: combined.weakConcepts,
    recommendedFocus: combined.recommendedFocus,
  };
  return mergeVisionMetricsIntoAnalysis(expansion, vision, solved);
}

export async function analyzeSolutionImage(
  file: File,
  options: {
    deploymentName: string;
    textDeploymentName: string;
    mode: AnalyzeQualityMode;
    onProgress?: (step: Extract<AnalyzeProgressStep, "vision" | "tutor">) => void;
    onPartial?: (payload: {
      step: "vision" | "tutor";
      analysis: SolutionAnalysis;
    }) => void;
  },
): Promise<SolutionAnalysis> {
  options.onProgress?.("vision");
  const vision = await extractSolutionImageVision(file, {
    deploymentName: options.deploymentName,
  });
  options.onPartial?.({
    step: "vision",
    analysis: partialAnalysisFromVision(vision),
  });
  options.onProgress?.("tutor");
  const analysis = await solveAndExpandFromVision(vision, {
    deploymentName: options.textDeploymentName,
    mode: options.mode,
  });
  options.onPartial?.({ step: "tutor", analysis });
  if (typeof console !== "undefined") {
    console.log("[study:azure:vision]", {
      deployment: options.deploymentName,
      extractedStudentAnswer: vision.extractedStudentAnswer.slice(0, 120),
      solutionStepsCount: vision.solutionSteps.length,
      imageClarityScore: vision.imageClarityScore,
      extractionConfidence: vision.extractionConfidence,
    });
    console.log("[study:azure:tutor]", {
      deployment: options.textDeploymentName,
      mode: options.mode,
      inferredCorrectAnswer: analysis.inferredCorrectAnswer.slice(0, 120),
      referenceStepsCount: analysis.referenceSolutionSteps?.length ?? 0,
      confidence: analysis.confidence,
    });
  }
  return analysis;
}

/**
 * 정확 모드 전용: 텍스트 모델이 채운 분석을 추론 모델로 재검증·교정합니다.
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

The JSON below blends (A) **vision-only OCR** (problem, handwriting solution steps, final answer) plus image-quality scores, and (B) a **subsequent text-only** tutor pass. Treat the OCR fields as photo evidence, not as text you can freely rewrite. **풀이 단계(solutionSteps)는 비전 전용**이라 이 단계에서는 바꾸지 않는다(서버가 유지).

Your tasks:
1) Keep problemText and extractedStudentAnswer verbatim unless the draft contains obvious formatting/JSON corruption. Do not correct OCR based on mathematical expectation alone.
2) Improve correctness of inferredCorrectAnswer and tie errorSummary / weakConcepts / recommendedFocus to the student's work shown in the draft's solutionSteps (read-only context).
3) Adjust confidence ∈ [0,1] appropriately.
4) Keep factual alignment with what was transcribed from the photo.

Draft JSON to refine:
${JSON.stringify(draft, null, 2)}

Return a single JSON object with these keys: problemText, extractedStudentAnswer, inferredCorrectAnswer, confidence, errorSummary, weakConcepts, recommendedFocus.
(Omit solutionSteps from your reply—it will be taken from the draft server-side.)
Copy problemText and extractedStudentAnswer exactly from the draft unless the exception in task (1) applies.
Keep readable LaTeX: inline formulas in $ ... $ and display formulas in $$ ... $$ wherever math appears. Preserve JSON escaping rules for backslashes.`;
  const raw = await completeTextOnlyJsonPrompt({
    deploymentName: options.deploymentName,
    userPrompt: prompt,
    temperatureForChat: ANALYZE_TEMPERATURE,
    maxTokens: 8192,
  });

  const parsedJson = parseJsonFromText(raw);
  if (
    typeof parsedJson !== "object" ||
    parsedJson === null ||
    Array.isArray(parsedJson)
  ) {
    throw new Error("정확 모드 재검토 응답이 JSON 객체가 아닙니다.");
  }
  const refined = solutionAnalysisSchema.parse({
    ...(parsedJson as Record<string, unknown>),
    solutionSteps: draft.solutionSteps,
    referenceSolutionSteps: draft.referenceSolutionSteps ?? [],
    imageQualityWarning: draft.imageQualityWarning,
    visionImageClarityScore: draft.visionImageClarityScore,
    visionExtractionConfidence: draft.visionExtractionConfidence,
  });
  return refined;
}

export async function generateSimilarProblems(
  analysis: SolutionAnalysis,
  submissionId: string,
  options: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
    problemSetId?: string;
    /** 비전 OCR 직후(튜터 병렬) — problemText·학생 풀이만으로 유사 유형 생성 */
    fromVisionOcrOnly?: boolean;
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
  const visionOnly = options.fromVisionOcrOnly === true;
  const promptIntro = visionOnly
    ? `Create five similar Korean math practice problems from this worksheet photo OCR (tutor diagnosis may still be running in parallel).

OCR snapshot:
${JSON.stringify(analysis, null, 2)}

Use problemText, extractedStudentAnswer, and solutionSteps (student handwriting). inferredCorrectAnswer or errorSummary may be empty — infer the likely weak concept from the problem type and visible student work. Do not wait for a full diagnosis.
Ignore imageQualityWarning, visionImageClarityScore, and visionExtractionConfidence except to avoid over-trusting ambiguous OCR.`
    : `Create five similar Korean math practice problems based on this student's mistake analysis.

Analysis:
${JSON.stringify(analysis, null, 2)}

Use only the learning-relevant fields: problemText, inferredCorrectAnswer, errorSummary, weakConcepts, recommendedFocus, and the student's transcribed solutionSteps. Ignore imageQualityWarning, visionImageClarityScore, and visionExtractionConfidence except to avoid over-trusting ambiguous OCR.`;

  const prompt = `${promptIntro}

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

  const balancedRegionalCredential =
    options.mode === "balanced"
      ? resolveBalancedTextRegionalCredentials()
      : null;

  const text = await completeTextOnlyJsonPrompt({
    deploymentName: options.deploymentName,
    userPrompt: prompt,
    temperatureForChat: GENERATE_TEMPERATURE,
    maxTokens: 8192,
    ...(balancedRegionalCredential
      ? { credentialOverride: balancedRegionalCredential }
      : {}),
  });

  const parsed = generatedProblemSetSchema.parse(parseJsonFromText(text));
  return {
    ...parsed,
    id: setId,
    submissionId,
  };
}
