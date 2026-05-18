import { NextResponse } from "next/server";
import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import {
  hasAzureOpenAiConfig,
  refineSolutionAnalysisForAccurateMode,
  solveAndExpandFromVision,
} from "@/lib/azure";
import { getRequestUserId } from "@/lib/request";
import { sampleAnalysis } from "@/lib/sample";
import { studyLog } from "@/lib/server-log";
import {
  solutionAnalysisSchema,
  visionSolutionExtractionSchema,
} from "@/lib/types";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(request: Request) {
  getRequestUserId(request);

  try {
    const body = (await request.json()) as Record<string, unknown>;
    const vision = visionSolutionExtractionSchema.parse(body.vision);
    const qualityMode = parseAnalyzeQualityMode(
      body.qualityMode as string | null,
    );
    const textDeploymentName = String(body.textDeploymentName ?? "").trim();
    if (!textDeploymentName) {
      return NextResponse.json(
        { error: "textDeploymentName이 필요합니다." },
        { status: 400 },
      );
    }

    studyLog("analyze:tutor", "POST start", {
      qualityMode,
      textDeploymentName,
    });

    let analysis = hasAzureOpenAiConfig()
      ? await solveAndExpandFromVision(vision, {
          deploymentName: textDeploymentName,
          mode: qualityMode,
        })
      : sampleAnalysis;

    if (qualityMode === "accurate" && hasAzureOpenAiConfig()) {
      analysis = await refineSolutionAnalysisForAccurateMode(analysis, {
        deploymentName: textDeploymentName,
        mode: qualityMode,
      });
    }

    return NextResponse.json({
      analysis: solutionAnalysisSchema.parse(analysis),
    });
  } catch (error) {
    studyLog("analyze:tutor", "failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      { error: "정답·오답 진단 중 오류가 발생했습니다." },
      { status: 500 },
    );
  }
}
