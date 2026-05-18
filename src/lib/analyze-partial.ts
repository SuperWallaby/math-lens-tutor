import type { AnalyzeProgressStep } from "./analyze-steps";
import { analyzeProgressMessage } from "./analyze-steps";
import type {
  GeneratedProblemSet,
  SolutionAnalysis,
  VisionSolutionExtraction,
} from "./types";
import { normalizeVisionSolutionSteps } from "./types";

const IMAGE_QUALITY_WARNING_THRESHOLD = 0.5;

export function partialAnalysisFromVision(
  vision: VisionSolutionExtraction,
): SolutionAnalysis {
  const warn =
    vision.imageClarityScore < IMAGE_QUALITY_WARNING_THRESHOLD ||
    vision.extractionConfidence < IMAGE_QUALITY_WARNING_THRESHOLD;
  return {
    problemText: vision.problemText,
    extractedStudentAnswer: vision.extractedStudentAnswer,
    inferredCorrectAnswer: "",
    referenceSolutionSteps: [],
    solutionSteps: normalizeVisionSolutionSteps(vision.solutionSteps),
    confidence: 0,
    errorSummary: "",
    weakConcepts: [],
    recommendedFocus: [],
    imageQualityWarning: warn,
    visionImageClarityScore: vision.imageClarityScore,
    visionExtractionConfidence: vision.extractionConfidence,
  };
}

export type AnalyzePartialPayload =
  | {
      type: "meta";
      submissionId: string;
      problemSetId: string;
      imageName: string;
    }
  | {
      type: "partial";
      step: Extract<AnalyzeProgressStep, "upload">;
      imageUrl: string | null;
    }
  | {
      type: "partial";
      step: Extract<AnalyzeProgressStep, "vision" | "tutor">;
      analysis: SolutionAnalysis;
    }
  | {
      type: "partial";
      step: Extract<AnalyzeProgressStep, "similar">;
      problemSet: GeneratedProblemSet;
    };

export function encodeAnalyzePartialLine(payload: AnalyzePartialPayload): Uint8Array {
  const step = payload.type === "meta" ? "meta" : payload.step;
  const message =
    payload.type === "meta"
      ? "분석을 시작합니다…"
      : analyzeProgressMessage(payload.step as AnalyzeProgressStep);
  return new TextEncoder().encode(
    `${JSON.stringify({ ...payload, message })}\n`,
  );
}
