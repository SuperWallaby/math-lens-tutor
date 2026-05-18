import type { AnalyzePartialPayload } from "./analyze-partial";
import {
  analyzeProgressMessage,
  type AnalyzeProgressStep,
  shouldAdvanceProgressStep,
} from "./analyze-steps";
import type { SolutionAnalysis } from "./types";
import type { GeneratedProblemSet } from "./types";

export type AnalyzeStreamResult = {
  submissionId: string;
  problemSetId?: string;
  submission?: unknown;
  problemSet?: unknown;
};

export type AnalyzeStreamCallbacks = {
  onProgress?: (message: string) => void;
  onPartial?: (payload: AnalyzePartialPayload & { message?: string }) => void;
};

export type StreamingAnalyzeState = {
  submissionId: string | null;
  problemSetId: string | null;
  imageName: string;
  imageUrl: string | null;
  progressMessage: string;
  progressStep: AnalyzeProgressStep | null;
  analysis: SolutionAnalysis | null;
  problemSet: GeneratedProblemSet | null;
};

export function createEmptyStreamingState(imageName = ""): StreamingAnalyzeState {
  return {
    submissionId: null,
    problemSetId: null,
    imageName,
    imageUrl: null,
    progressMessage: "분석을 시작합니다…",
    progressStep: null,
    analysis: null,
    problemSet: null,
  };
}

function hasTutorData(analysis: SolutionAnalysis | null): boolean {
  if (!analysis) return false;
  return (
    analysis.inferredCorrectAnswer.trim().length > 0 &&
    analysis.errorSummary.trim().length > 0
  );
}

function similarStillPending(state: StreamingAnalyzeState): boolean {
  return !state.problemSet || state.problemSet.problems.length === 0;
}

function withProgress(
  state: StreamingAnalyzeState,
  step: AnalyzeProgressStep,
  message: string,
  options?: { tutorComplete?: boolean },
): StreamingAnalyzeState {
  const tutorComplete = options?.tutorComplete ?? hasTutorData(state.analysis);
  if (!shouldAdvanceProgressStep(state.progressStep, step, { tutorComplete })) {
    return state;
  }
  return { ...state, progressStep: step, progressMessage: message };
}

/** 풀이 완료 직후 유사문제가 아직이면 진행 문구를 유사문제 단계로 전환 */
function afterTutorMaybeShowSimilar(
  state: StreamingAnalyzeState,
): StreamingAnalyzeState {
  if (!hasTutorData(state.analysis) || !similarStillPending(state)) {
    return state;
  }
  return withProgress(
    state,
    "similar",
    analyzeProgressMessage("similar"),
    { tutorComplete: true },
  );
}

export function applyAnalyzeStreamEvent(
  state: StreamingAnalyzeState,
  event: Record<string, unknown>,
): StreamingAnalyzeState {
  const type = event.type as string | undefined;
  const message =
    typeof event.message === "string" ? event.message : state.progressMessage;
  const step = event.step as AnalyzeProgressStep | undefined;

  if (type === "progress" && step) {
    return withProgress(state, step, message);
  }

  if (type === "meta") {
    return {
      ...state,
      submissionId: event.submissionId as string,
      problemSetId: event.problemSetId as string,
      imageName: (event.imageName as string) || state.imageName,
    };
  }

  if (type === "partial" && step) {
    if (step === "upload") {
      return {
        ...withProgress(state, step, message),
        imageUrl: (event.imageUrl as string | null) ?? null,
      };
    }
    if (step === "vision") {
      return {
        ...withProgress(state, step, message),
        analysis: event.analysis as SolutionAnalysis,
      };
    }
    if (step === "tutor") {
      const withAnalysis = {
        ...withProgress(state, step, message),
        analysis: event.analysis as SolutionAnalysis,
      };
      return afterTutorMaybeShowSimilar(withAnalysis);
    }
    if (step === "similar") {
      const tutorComplete = hasTutorData(state.analysis);
      const next = {
        ...state,
        problemSet: event.problemSet as GeneratedProblemSet,
      };
      return shouldAdvanceProgressStep(state.progressStep, step, {
        tutorComplete,
      })
        ? { ...next, progressStep: step, progressMessage: message }
        : next;
    }
  }

  return state;
}

export async function postAnalyzeWithProgress(
  formData: FormData,
  callbacks: AnalyzeStreamCallbacks & { url?: string } = {},
): Promise<AnalyzeStreamResult> {
  const url = callbacks.url ?? "/api/analyze";
  formData.set("streamProgress", "1");

  const response = await fetch(url, {
    method: "POST",
    body: formData,
  });

  const contentType = response.headers.get("content-type") ?? "";
  if (!contentType.includes("ndjson")) {
    const payload = (await response.json()) as {
      submissionId?: string;
      error?: string;
    };
    if (!response.ok || !payload.submissionId) {
      throw new Error(payload.error ?? "분석 요청에 실패했습니다.");
    }
    return { submissionId: payload.submissionId };
  }

  const reader = response.body?.getReader();
  if (!reader) {
    throw new Error("분석 응답 스트림을 열 수 없습니다.");
  }

  const decoder = new TextDecoder();
  let buffer = "";
  let result: AnalyzeStreamResult | undefined;
  let streamError: string | undefined;

  const handleLine = (line: string) => {
    if (!line) return;
    const obj = JSON.parse(line) as Record<string, unknown>;
    const type = obj.type as string | undefined;

    if (type === "progress" || type === "meta" || type === "partial") {
      callbacks.onPartial?.(obj as AnalyzePartialPayload & { message?: string });
      if (typeof obj.message === "string") {
        callbacks.onProgress?.(obj.message);
      }
    }
    if (type === "error") {
      streamError =
        (obj.error as string | undefined) ?? "분석 요청에 실패했습니다.";
      return;
    }
    if (type === "result" && obj.submissionId) {
      result = { submissionId: obj.submissionId as string };
    }
  };

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    let newline = buffer.indexOf("\n");
    while (newline >= 0) {
      const line = buffer.slice(0, newline).trim();
      buffer = buffer.slice(newline + 1);
      handleLine(line);
      newline = buffer.indexOf("\n");
    }
  }

  const tail = buffer.trim();
  if (tail) handleLine(tail);

  if (streamError) throw new Error(streamError);
  if (!result?.submissionId) {
    throw new Error("분석 요청에 실패했습니다.");
  }

  return result;
}
