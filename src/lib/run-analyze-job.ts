import { randomUUID } from "crypto";
import type { AnalyzeQualityMode } from "./analyze-mode";
import {
  encodeAnalyzePartialLine,
  partialAnalysisFromVision,
  type AnalyzePartialPayload,
} from "./analyze-partial";
import {
  makeAnalyzeProgressEvent,
  type AnalyzeProgressStep,
} from "./analyze-steps";
import {
  extractSolutionImageVision,
  generateSimilarProblems,
  hasAzureOpenAiConfig,
  refineSolutionAnalysisForAccurateMode,
  solveAndExpandFromVision,
} from "./azure";
import { sampleAnalysis, sampleProblemSet } from "./sample";
import { uploadSolutionImage, saveProblemSet, saveSubmission } from "./store";
import type { GeneratedProblemSet, SolutionSubmission } from "./types";

export type AnalyzeJobResult = {
  submissionId: string;
  problemSetId: string;
  qualityMode: AnalyzeQualityMode;
  submission: SolutionSubmission;
  problemSet: GeneratedProblemSet;
};

export type AnalyzeStreamSink = {
  onProgress?: (step: AnalyzeProgressStep) => void;
  onPartial?: (payload: AnalyzePartialPayload) => void;
};

function duplicateInputFile(raw: ArrayBuffer, name: string, type: string) {
  return new File([raw.slice(0)], name, {
    type: type || "application/octet-stream",
  });
}

export async function runAnalyzeJob(params: {
  file: File;
  userId: string;
  qualityMode: AnalyzeQualityMode;
  visionDeploymentName: string;
  textDeploymentName: string;
  stream?: AnalyzeStreamSink;
}): Promise<AnalyzeJobResult> {
  const { file, userId, qualityMode, visionDeploymentName, textDeploymentName } =
    params;
  const emitProgress = (step: AnalyzeProgressStep) => {
    params.stream?.onProgress?.(step);
  };
  const emitPartial = (payload: AnalyzePartialPayload) => {
    params.stream?.onPartial?.(payload);
  };

  const submissionId = randomUUID();
  const problemSetId = randomUUID();
  const azureConfigured = hasAzureOpenAiConfig();

  emitPartial({
    type: "meta",
    submissionId,
    problemSetId,
    imageName: file.name,
  });

  const raw = await file.arrayBuffer();
  const mkFile = () => duplicateInputFile(raw, file.name, file.type);

  let imageUrl: string | null;
  let analysis: SolutionSubmission["analysis"];
  let problemSet: GeneratedProblemSet;

  if (azureConfigured) {
    emitProgress("upload");
    emitProgress("vision");

    const uploadPromise = uploadSolutionImage(mkFile(), userId).then((url) => {
      imageUrl = url;
      emitPartial({ type: "partial", step: "upload", imageUrl: url });
      return url;
    });

    const analyzeBundlePromise = (async () => {
      const vision = await extractSolutionImageVision(mkFile(), {
        deploymentName: visionDeploymentName,
      });
      emitPartial({
        type: "partial",
        step: "vision",
        analysis: partialAnalysisFromVision(vision),
      });

      const visionDraft = partialAnalysisFromVision(vision);
      emitProgress("tutor");

      let similarFinished = false;
      const similarPromise = generateSimilarProblems(
        visionDraft,
        submissionId,
        {
          deploymentName: textDeploymentName,
          mode: qualityMode,
          problemSetId,
          fromVisionOcrOnly: true,
        },
      ).then((ps) => {
        similarFinished = true;
        emitPartial({ type: "partial", step: "similar", problemSet: ps });
        return ps;
      });

      let tutorAnalysis = await solveAndExpandFromVision(vision, {
        deploymentName: textDeploymentName,
        mode: qualityMode,
      });
      emitPartial({
        type: "partial",
        step: "tutor",
        analysis: tutorAnalysis,
      });

      if (qualityMode === "accurate") {
        tutorAnalysis = await refineSolutionAnalysisForAccurateMode(
          tutorAnalysis,
          {
            deploymentName: textDeploymentName,
            mode: qualityMode,
          },
        );
        emitPartial({
          type: "partial",
          step: "tutor",
          analysis: tutorAnalysis,
        });
      }

      if (!similarFinished) {
        emitProgress("similar");
      }
      const generatedSet = await similarPromise;
      return { analysis: tutorAnalysis, problemSet: generatedSet };
    })();

    const settled = await Promise.allSettled([
      uploadPromise,
      analyzeBundlePromise,
    ]);

    if (settled[0].status === "rejected") throw settled[0].reason;
    if (settled[1].status === "rejected") throw settled[1].reason;

    imageUrl = settled[0].value;
    analysis = settled[1].value.analysis;
    problemSet = settled[1].value.problemSet;
  } else {
    emitProgress("upload");
    imageUrl = await uploadSolutionImage(mkFile(), userId);
    emitPartial({ type: "partial", step: "upload", imageUrl });
    emitProgress("vision");
    analysis = partialAnalysisFromVision({
      problemText: sampleAnalysis.problemText,
      extractedStudentAnswer: sampleAnalysis.extractedStudentAnswer,
      solutionSteps: sampleAnalysis.solutionSteps,
      imageClarityScore: 1,
      extractionConfidence: 1,
    });
    emitPartial({ type: "partial", step: "vision", analysis });
    emitProgress("tutor");
    analysis = sampleAnalysis;
    emitPartial({ type: "partial", step: "tutor", analysis });
    emitProgress("similar");
    problemSet = {
      ...sampleProblemSet,
      id: problemSetId,
      submissionId,
    };
    emitPartial({ type: "partial", step: "similar", problemSet });
  }

  const usedSample = !azureConfigured;
  const modelMeta = {
    visionModel: usedSample ? "(샘플)" : visionDeploymentName,
    textModel: usedSample ? "(샘플)" : textDeploymentName,
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

  emitProgress("save");
  await saveSubmission(submission);
  await saveProblemSet(problemSet);

  return {
    submissionId: submission.id,
    problemSetId: problemSet.id,
    qualityMode,
    submission,
    problemSet,
  };
}

export function encodeAnalyzeNdjsonLine(payload: unknown): Uint8Array {
  return new TextEncoder().encode(`${JSON.stringify(payload)}\n`);
}

export function progressNdjsonLine(step: AnalyzeProgressStep): Uint8Array {
  return encodeAnalyzeNdjsonLine(makeAnalyzeProgressEvent(step));
}

export { encodeAnalyzePartialLine };
