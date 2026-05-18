import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import {
  analyzeSolutionImage,
  generateSimilarProblems,
  hasAzureOpenAiConfig,
  refineSolutionAnalysisForAccurateMode,
  resolveAzureDeploymentName,
  resolveVisionDeploymentName,
} from "@/lib/azure";
import {
  buildTextDeploymentCandidateList,
  buildVisionDeploymentCandidateList,
  pickAllowedDeployment,
} from "@/lib/model-deployment-options";
import { GENERIC_ANALYZE_ERROR, logApiError } from "@/lib/api-errors";
import { isDevEnvironment } from "@/lib/is-dev";
import { getRequestUserId } from "@/lib/request";
import {
  saveProblemSet,
  saveSubmission,
  uploadSolutionImage,
} from "@/lib/store";
import { sampleAnalysis, sampleProblemSet } from "@/lib/sample";
import type { GeneratedProblemSet, SolutionSubmission } from "@/lib/types";

export const runtime = "nodejs";

// #region agent log
function agentLog(
  location: string,
  message: string,
  data: Record<string, unknown>,
  hypothesisId: string,
) {
  fetch("http://127.0.0.1:7389/ingest/73396ec2-fca1-4017-a12e-5c91c133bd12", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Debug-Session-Id": "786fd5",
    },
    body: JSON.stringify({
      sessionId: "786fd5",
      location,
      message,
      data,
      timestamp: Date.now(),
      hypothesisId,
    }),
  }).catch(() => {});
}

function errText(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}
// #endregion

export async function POST(request: Request) {
  const userId = getRequestUserId(request);

  try {
    const formData = (await request.formData()) as unknown as {
      get(name: string): FormDataEntryValue | null;
    };
    const file = formData.get("image");

    if (!(file instanceof File) || file.size === 0) {
      return NextResponse.json(
        { error: "풀이 사진 파일을 첨부해 주세요." },
        { status: 400 },
      );
    }

    const qualityMode = parseAnalyzeQualityMode(formData.get("qualityMode"));

    const visionCandidates = buildVisionDeploymentCandidateList();
    const textCandidates = buildTextDeploymentCandidateList();
    const textFallback = resolveAzureDeploymentName(qualityMode);
    const visionFallback = resolveVisionDeploymentName();

    if (hasAzureOpenAiConfig()) {
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

    // #region agent log
    agentLog(
      "analyze/route.ts:deployments",
      "resolved deployments",
      {
        qualityMode,
        visionDeploymentName,
        textDeploymentName: deploymentName,
        visionCandidatesLen: visionCandidates.length,
        textCandidatesLen: textCandidates.length,
      },
      "H1",
    );
    // #endregion

    const submissionId = randomUUID();
    const problemSetId = randomUUID();

    /** 각 분기에서 File.arrayBuffer()를 소비하므로 동일 바이트를 복제해 전달 */
    const raw = await file.arrayBuffer();
    const duplicateInputFile = () =>
      new File([raw.slice(0)], file.name, {
        type: file.type || "application/octet-stream",
      });

    let imageUrl: string | null;
    let analysis: SolutionSubmission["analysis"];
    let problemSet: GeneratedProblemSet;

    if (hasAzureOpenAiConfig()) {
      const settled = await Promise.allSettled([
        uploadSolutionImage(duplicateInputFile(), userId),
        analyzeSolutionImage(duplicateInputFile(), {
          deploymentName: visionDeploymentName,
          textDeploymentName: deploymentName,
          mode: qualityMode,
        }),
      ]);

      // #region agent log
      if (settled[0].status === "rejected") {
        agentLog(
          "analyze/route.ts:upload",
          "uploadSolutionImage rejected",
          { error: errText(settled[0].reason) },
          "H4",
        );
      } else {
        agentLog(
          "analyze/route.ts:upload",
          "uploadSolutionImage fulfilled",
          { hasUrl: Boolean(settled[0].value) },
          "H4",
        );
      }
      if (settled[1].status === "rejected") {
        agentLog(
          "analyze/route.ts:analyze",
          "analyzeSolutionImage rejected",
          { error: errText(settled[1].reason) },
          "H1",
        );
      } else {
        agentLog(
          "analyze/route.ts:analyze",
          "analyzeSolutionImage fulfilled",
          {
            hasProblemText: Boolean(
              settled[1].value && settled[1].value.problemText,
            ),
          },
          "H1",
        );
      }
      // #endregion

      if (settled[0].status === "rejected") throw settled[0].reason;
      if (settled[1].status === "rejected") throw settled[1].reason;
      imageUrl = settled[0].value;
      analysis = settled[1].value;

      if (qualityMode === "accurate") {
        try {
          analysis = await refineSolutionAnalysisForAccurateMode(analysis, {
            deploymentName,
            mode: qualityMode,
          });
          // #region agent log
          agentLog(
            "analyze/route.ts:refine",
            "refineSolutionAnalysisForAccurateMode ok",
            {},
            "H2",
          );
          // #endregion
        } catch (refineErr) {
          // #region agent log
          agentLog(
            "analyze/route.ts:refine",
            "refineSolutionAnalysisForAccurateMode rejected",
            { error: errText(refineErr) },
            "H2",
          );
          // #endregion
          throw refineErr;
        }
      }

      try {
        problemSet = await generateSimilarProblems(
          analysis,
          submissionId,
          {
            deploymentName,
            mode: qualityMode,
            problemSetId,
          },
        );
        // #region agent log
        agentLog(
          "analyze/route.ts:similar",
          "generateSimilarProblems ok",
          { problemCount: problemSet.problems?.length ?? 0 },
          "H3",
        );
        // #endregion
      } catch (similarErr) {
        // #region agent log
        agentLog(
          "analyze/route.ts:similar",
          "generateSimilarProblems rejected",
          { error: errText(similarErr) },
          "H3",
        );
        // #endregion
        throw similarErr;
      }
    } else {
      imageUrl = await uploadSolutionImage(duplicateInputFile(), userId);
      analysis = sampleAnalysis;
      problemSet = {
        ...sampleProblemSet,
        id: problemSetId,
        submissionId,
      };
    }

    const usedSample = !hasAzureOpenAiConfig();
    const submission: SolutionSubmission = {
      id: submissionId,
      userId,
      imageUrl,
      imageName: file.name,
      createdAt: new Date().toISOString(),
      analysis,
      ...(isDevEnvironment()
        ? {
            devMeta: {
              visionModel: usedSample ? "(샘플)" : visionDeploymentName,
              textModel: usedSample ? "(샘플)" : deploymentName,
              qualityMode,
              isSample: usedSample,
            },
          }
        : {}),
    };

    try {
      await saveSubmission(submission);
      await saveProblemSet(problemSet);
      // #region agent log
      agentLog(
        "analyze/route.ts:persist",
        "saveSubmission+saveProblemSet ok",
        { submissionId: submission.id },
        "H5",
      );
      // #endregion
    } catch (persistErr) {
      // #region agent log
      agentLog(
        "analyze/route.ts:persist",
        "save rejected",
        { error: errText(persistErr) },
        "H5",
      );
      // #endregion
      throw persistErr;
    }

    return NextResponse.json({
      submissionId: submission.id,
      problemSetId: problemSet.id,
      qualityMode,
      submission,
      problemSet,
    });
  } catch (error) {
    // #region agent log
    agentLog(
      "analyze/route.ts:catch",
      "POST failed",
      { error: errText(error) },
      "H1",
    );
    // #endregion
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
