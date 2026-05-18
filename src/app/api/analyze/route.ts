import { NextResponse } from "next/server";
import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import {
  hasAzureOpenAiConfig,
  resolveAzureDeploymentName,
  resolveVisionDeploymentName,
} from "@/lib/azure";
import {
  buildTextDeploymentCandidateList,
  buildVisionDeploymentCandidateList,
  pickAllowedDeployment,
} from "@/lib/model-deployment-options";
import { GENERIC_ANALYZE_ERROR, logApiError } from "@/lib/api-errors";
import { getRequestUserId } from "@/lib/request";
import { encodeAnalyzePartialLine } from "@/lib/analyze-partial";
import type { AnalyzePartialPayload } from "@/lib/analyze-partial";
import {
  encodeAnalyzeNdjsonLine,
  progressNdjsonLine,
  runAnalyzeJob,
} from "@/lib/run-analyze-job";
import { studyLog } from "@/lib/server-log";
import type { SolutionSubmission } from "@/lib/types";

export const runtime = "nodejs";
/** Pro/Enterprise: 최대 300s. Hobby는 플랫폼 상한(~10s)이 더 짧을 수 있음. */
export const maxDuration = 300;

function errText(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}

function normalizeForCompare(s: string) {
  return s.replace(/\s+/g, "").replace(/\u2212/g, "-").toLowerCase();
}

function logAnalysisResult(
  scope: string,
  analysis: SolutionSubmission["analysis"],
) {
  const student = analysis.extractedStudentAnswer.trim();
  const inferred = analysis.inferredCorrectAnswer.trim();
  const normMatch =
    student.length > 0 &&
    inferred.length > 0 &&
    normalizeForCompare(student) === normalizeForCompare(inferred);

  studyLog(scope, "analysis result", {
    extractedStudentAnswer: student.slice(0, 200),
    inferredCorrectAnswer: inferred.slice(0, 200),
    normalizedMatch: normMatch,
    confidence: analysis.confidence,
    imageQualityWarning: analysis.imageQualityWarning,
    visionExtractionConfidence: analysis.visionExtractionConfidence,
    solutionStepsCount: analysis.solutionSteps.length,
    referenceStepsCount: analysis.referenceSolutionSteps?.length ?? 0,
  });
}

function wantsProgressStream(formData: FormData): boolean {
  const v = formData.get("streamProgress");
  return v === "1" || v === "true";
}

export async function POST(request: Request) {
  const userId = getRequestUserId(request);
  const azureConfigured = hasAzureOpenAiConfig();

  studyLog("analyze", "POST start", {
    userId: userId.slice(0, 24),
    azureConfigured,
    nodeEnv: process.env.NODE_ENV,
    vercelEnv: process.env.VERCEL_ENV ?? null,
  });

  try {
    const formData = await request.formData();
    const file = formData.get("image");

    if (!(file instanceof File) || file.size === 0) {
      return NextResponse.json(
        { error: "풀이 사진 파일을 첨부해 주세요." },
        { status: 400 },
      );
    }

    const qualityMode = parseAnalyzeQualityMode(formData.get("qualityMode"));
    const streamProgress = wantsProgressStream(formData);
    const visionCandidates = buildVisionDeploymentCandidateList();
    const textCandidates = buildTextDeploymentCandidateList();
    const textFallback = resolveAzureDeploymentName(qualityMode);
    const visionFallback = resolveVisionDeploymentName();

    if (azureConfigured) {
      if (!textFallback) {
        return NextResponse.json(
          {
            error:
              "Azure OpenAI 배포 이름이 없습니다. AZURE_OPENAI_DEPLOYMENT 또는 모드별 AZURE_OPENAI_DEPLOYMENT_* 환경 변수를 설정해 주세요.",
          },
          { status: 500 },
        );
      }
      if (!visionFallback) {
        return NextResponse.json(
          {
            error:
              "비전용 배포가 없습니다. AZURE_OPENAI_DEPLOYMENT_BALANCED 등 비전을 지원하는 배포를 설정하거나 AZURE_OPENAI_DEPLOYMENT_VISION 을 지정해 주세요.",
          },
          { status: 500 },
        );
      }
    }

    const deploymentName =
      pickAllowedDeployment(
        formData.get("textDeployment"),
        textCandidates,
        textFallback,
      ) ?? "unused";
    const visionDeploymentName =
      pickAllowedDeployment(
        formData.get("visionDeployment"),
        visionCandidates,
        visionFallback,
      ) ?? deploymentName;

    studyLog("analyze", "deployments resolved", {
      qualityMode,
      streamProgress,
      visionDeploymentName,
      textDeploymentName: deploymentName,
    });

    const jobParams = {
      file,
      userId,
      qualityMode,
      visionDeploymentName,
      textDeploymentName: deploymentName,
    };

    if (streamProgress) {
      const stream = new ReadableStream({
        async start(controller) {
          try {
            const result = await runAnalyzeJob({
              ...jobParams,
              stream: {
                onProgress: (step) => {
                  controller.enqueue(progressNdjsonLine(step));
                },
                onPartial: (payload: AnalyzePartialPayload) => {
                  controller.enqueue(encodeAnalyzePartialLine(payload));
                },
              },
            });
            logAnalysisResult("analyze", result.submission.analysis);
            studyLog("analyze", "saved (stream)", {
              submissionId: result.submissionId,
              problemSetId: result.problemSetId,
            });
            controller.enqueue(
              encodeAnalyzeNdjsonLine({ type: "result", ...result }),
            );
            controller.close();
          } catch (error) {
            studyLog("analyze", "POST failed (stream)", {
              error: errText(error),
            });
            const errorId = await logApiError({
              request,
              route: "/api/analyze",
              userId,
              error,
            });
            controller.enqueue(
              encodeAnalyzeNdjsonLine({
                type: "error",
                error: GENERIC_ANALYZE_ERROR,
                errorId,
              }),
            );
            controller.close();
          }
        },
      });

      return new Response(stream, {
        headers: {
          "Content-Type": "application/x-ndjson; charset=utf-8",
          "Cache-Control": "no-cache, no-transform",
          Connection: "keep-alive",
        },
      });
    }

    const result = await runAnalyzeJob({ ...jobParams });
    logAnalysisResult("analyze", result.submission.analysis);
    studyLog("analyze", "saved", {
      submissionId: result.submissionId,
      problemSetId: result.problemSetId,
    });

    return NextResponse.json({
      submissionId: result.submissionId,
      problemSetId: result.problemSetId,
      qualityMode: result.qualityMode,
      submission: result.submission,
      problemSet: result.problemSet,
    });
  } catch (error) {
    studyLog("analyze", "POST failed", { error: errText(error) });
    const errorId = await logApiError({
      request,
      route: "/api/analyze",
      userId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_ANALYZE_ERROR, errorId },
      { status: 500 },
    );
  }
}
