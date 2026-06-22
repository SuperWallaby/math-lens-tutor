import { env } from "./env";
import type { TrainingFeedItem } from "./types";

type FeedReasonEnhancement = {
  feedItemId: string;
  reason: string;
};

function gpuLlmConfigured(): boolean {
  return Boolean(env.gpuLlmBaseUrl?.trim());
}

function difficultyLabel(difficulty: string): string {
  if (difficulty === "easy") return "쉬움";
  if (difficulty === "hard") return "어려움";
  return "보통";
}

export async function enhanceFeedReasonsWithGpu(params: {
  userId: string;
  items: TrainingFeedItem[];
  focusConcepts: string[];
}): Promise<TrainingFeedItem[]> {
  if (!gpuLlmConfigured() || params.items.length === 0) {
    return params.items;
  }

  const baseUrl = env.gpuLlmBaseUrl!.replace(/\/$/, "");
  const model = env.gpuLlmModel ?? "qwen2.5:7b";

  const payload = {
    model,
    stream: false,
    format: "json",
    messages: [
      {
        role: "system",
        content:
          "You write short Korean feed card subtitles for a math tutoring app. Return JSON only.",
      },
      {
        role: "user",
        content: JSON.stringify({
          focusConcepts: params.focusConcepts,
          items: params.items.map((item) => ({
            feedItemId: item.id,
            concept: item.concept,
            difficulty: difficultyLabel(item.difficulty),
            title: item.title,
            currentReason: item.reason,
          })),
          instruction:
            "For each item, write a friendlier reason under 40 Korean characters. Keep concept and difficulty hint.",
        }),
      },
    ],
  };

  try {
    const response = await fetch(`${baseUrl}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(env.gpuLlmTimeoutMs),
    });

    if (!response.ok) {
      return params.items;
    }

    const body = (await response.json()) as {
      message?: { content?: string };
    };
    const raw = body.message?.content?.trim();
    if (!raw) return params.items;

    const parsed = JSON.parse(raw) as {
      items?: FeedReasonEnhancement[];
    };
    if (!Array.isArray(parsed.items)) return params.items;

    const reasonById = new Map(
      parsed.items.map((row) => [row.feedItemId, row.reason.trim()]),
    );

    return params.items.map((item) => {
      const reason = reasonById.get(item.id);
      return reason ? { ...item, reason } : item;
    });
  } catch {
    return params.items;
  }
}

export async function classifyMistakeWithGpu(params: {
  concept: string;
  prompt: string;
  submittedAnswer: string;
  expectedAnswer: string;
  feedback: string;
}): Promise<string | null> {
  if (!gpuLlmConfigured()) return null;

  const baseUrl = env.gpuLlmBaseUrl!.replace(/\/$/, "");
  const model = env.gpuLlmModel ?? "qwen2.5:7b";

  try {
    const response = await fetch(`${baseUrl}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model,
        stream: false,
        format: "json",
        messages: [
          {
            role: "system",
            content:
              'Classify the student mistake. Return JSON: {"errorType":"calculation|concept|condition|other","label":"short Korean"}',
          },
          {
            role: "user",
            content: JSON.stringify(params),
          },
        ],
      }),
      signal: AbortSignal.timeout(env.gpuLlmTimeoutMs),
    });

    if (!response.ok) return null;
    const body = (await response.json()) as { message?: { content?: string } };
    const raw = body.message?.content?.trim();
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { label?: string };
    return parsed.label?.trim() || null;
  } catch {
    return null;
  }
}
