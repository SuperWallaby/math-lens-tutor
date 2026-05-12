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

/** 모드는 배포(모델)만 바꾸고, temperature는 작업별로 고정합니다. */
const ANALYZE_TEMPERATURE = 0.22;
const GENERATE_TEMPERATURE = 0.45;

function parseJsonFromText(text: string) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const jsonText = fenced?.[1] ?? text;
  return JSON.parse(jsonText.trim());
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

/** Flutter 등에서 type 이 octet-stream 으로 오는 경우가 많아 Azure 비전 API가 거부함 */
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

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": env.azureOpenAiApiKey!,
    },
    body: JSON.stringify({
      messages: params.messages,
      temperature: params.temperature,
      max_tokens: params.maxTokens ?? 4096,
      response_format: { type: "json_object" },
    }),
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
Set isLikelyCorrect to true when the student's answer and reasoning are substantially aligned with inferredCorrectAnswer; set false when clearly wrong, incomplete, or contradictory.`;

  const text = await azureChatCompletionJson({
    deploymentName: options.deploymentName,
    temperature: ANALYZE_TEMPERATURE,
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

export async function generateSimilarProblems(
  analysis: SolutionAnalysis,
  submissionId: string,
  options: { deploymentName: string; mode: AnalyzeQualityMode },
): Promise<GeneratedProblemSet> {
  if (!hasAzureOpenAiConfig()) {
    return {
      ...sampleProblemSet,
      id: randomUUID(),
      submissionId,
    };
  }

  const setId = randomUUID();
  const prompt = `Create five similar Korean math practice problems based on this student's mistake analysis.

Analysis:
${JSON.stringify(analysis, null, 2)}

Return only JSON matching this exact shape:
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
      "chart": null
    }
  ]
}

Rules:
- Exactly 5 problems.
- Mix multiple_choice and free_response when useful.
- Multiple choice problems must have choices numbered 1 through 5.
- For multiple_choice, correctAnswer must be the **exact label text** of the correct option (same string as one choice's "label"), never only the choice id "1".."5".
- If a graph is needed, set chart to a Chart.js-compatible JSON object with type, data, and options.
- Use Korean text.
- Make the problems similar enough to train the missing concept, but not identical.`;

  const text = await azureChatCompletionJson({
    deploymentName: options.deploymentName,
    temperature: GENERATE_TEMPERATURE,
    messages: [{ role: "user", content: prompt }],
  });

  return generatedProblemSetSchema.parse(parseJsonFromText(text));
}

/**
 * 풀이 이미지만 보고 유사 문제 세트를 생성합니다.
 * `/api/analyze`에서 분석(텍스트 피드백) 호출과 병렬로 실행합니다.
 */
export async function generateSimilarProblemsFromImage(
  file: File,
  submissionId: string,
  problemSetId: string,
  options: { deploymentName: string; mode: AnalyzeQualityMode },
): Promise<GeneratedProblemSet> {
  if (!hasAzureOpenAiConfig()) {
    return {
      ...sampleProblemSet,
      id: problemSetId,
      submissionId,
    };
  }

  const buffer = Buffer.from(await file.arrayBuffer());
  const mime = normalizeImageMimeType(file);
  const dataUrl = `data:${mime};base64,${buffer.toString("base64")}`;

  const prompt = `You are an expert Korean math tutor. Read the student's handwritten math solution image with multimodal reasoning.

Infer likely mistakes and weak concepts from the image alone, then create five similar Korean math practice problems that help train those gaps.

Return only JSON matching this exact shape:
{
  "id": "${problemSetId}",
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
      "chart": null
    }
  ]
}

Rules:
- id must be exactly "${problemSetId}" and submissionId exactly "${submissionId}".
- Exactly 5 problems.
- Mix multiple_choice and free_response when useful.
- Multiple choice problems must have choices numbered 1 through 5.
- For multiple_choice, correctAnswer must be the **exact label text** of the correct option (same string as one choice's "label"), never only the choice id "1".."5".
- If a graph is needed, set chart to a Chart.js-compatible JSON object with type, data, and options.
- Use Korean text.
- Make problems similar enough to train inferred weak concepts, but not identical to the photo.`;

  const text = await azureChatCompletionJson({
    deploymentName: options.deploymentName,
    temperature: GENERATE_TEMPERATURE,
    maxTokens: 8192,
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

  const parsed = generatedProblemSetSchema.parse(parseJsonFromText(text));
  return {
    ...parsed,
    id: problemSetId,
    submissionId,
  };
}
