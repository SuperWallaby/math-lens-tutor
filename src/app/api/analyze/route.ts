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
import { getRequestUserId } from "@/lib/request";
import { studyLog } from "@/lib/server-log";
import {
  saveProblemSet,
  saveSubmission,
  uploadSolutionImage,
} from "@/lib/store";
import { sampleAnalysis, sampleProblemSet } from "@/lib/sample";
import type { GeneratedProblemSet, SolutionSubmission } from "@/lib/types";

export const runtime = "nodejs";

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
  });
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
      visionDeploymentName,
      textDeploymentName: deploymentName,
      textDeploymentFromForm: String(formData.get("textDeployment") ?? ""),
      visionDeploymentFromForm: String(formData.get("visionDeployment") ?? ""),
      visionCandidatesLen: visionCandidates.length,
      textCandidatesLen: textCandidates.length,
    });

    const submissionId = randomUUID();
    const problemSetId = randomUUID();

    const raw = await file.arrayBuffer();
    const duplicateInputFile = () =>
      new File([raw.slice(0)], file.name, {
        type: file.type || "application/octet-stream",
      });

    let imageUrl: string | null;
    let analysis: SolutionSubmission["analysis"];
    let problemSet: GeneratedProblemSet;

    if (azureConfigured) {
      const settled = await Promise.allSettled([
        uploadSolutionImage(duplicateInputFile(), userId),
        analyzeSolutionImage(duplicateInputFile(), {
          deploymentName: visionDeploymentName,
          textDeploymentName: deploymentName,
          mode: qualityMode,
        }),
      ]);

      if (settled[0].status === "rejected") {
        studyLog("analyze", "uploadSolutionImage failed", {
          error: errText(settled[0].reason),
        });
        throw settled[0].reason;
      }
      if (settled[1].status === "rejected") {
        studyLog("analyze", "analyzeSolutionImage failed", {
          error: errText(settled[1].reason),
        });
        throw settled[1].reason;
      }

      imageUrl = settled[0].value;
      analysis = settled[1].value;
      logAnalysisResult("analyze", analysis);

      if (qualityMode === "accurate") {
        analysis = await refineSolutionAnalysisForAccurateMode(analysis, {
          deploymentName,
          mode: qualityMode,
        });
        studyLog("analyze", "accurate refine done", {});
        logAnalysisResult("analyze:refined", analysis);
      }

      problemSet = await generateSimilarProblems(analysis, submissionId, {
        deploymentName,
        mode: qualityMode,
        problemSetId,
      });
      studyLog("analyze", "similar problems generated", {
        problemCount: problemSet.problems.length,
        firstCorrectAnswers: problemSet.problems.map((p) => ({
          id: p.id,
          correctAnswer: p.correctAnswer.slice(0, 80),
          type: p.type,
        })),
      });
    } else {
      studyLog("analyze", "using sample analysis (no Azure config)", {});
      imageUrl = await uploadSolutionImage(duplicateInputFile(), userId);
      analysis = sampleAnalysis;
      problemSet = {
        ...sampleProblemSet,
        id: problemSetId,
        submissionId,
      };
      logAnalysisResult("analyze:sample", analysis);
    }

    const usedSample = !azureConfigured;
    const modelMeta = {
      visionModel: usedSample ? "(샘플)" : visionDeploymentName,
      textModel: usedSample ? "(샘플)" : deploymentName,
      qualityMode,
      isSample: usedSample,
    };

    const submission: SolutionSubmission = {
      id: submissionId,
      userId,
      imageUrl,
      imageName: file.name,
      createdAt: new Date().toISOString(),
      analysis,
      modelMeta,
    };

    await saveSubmission(submission);
    await saveProblemSet(problemSet);

    studyLog("analyze", "saved", {
      submissionId: submission.id,
      problemSetId: problemSet.id,
      modelMeta,
    });

    return NextResponse.json({
      submissionId: submission.id,
      problemSetId: problemSet.id,
      qualityMode,
      submission,
      problemSet,
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
