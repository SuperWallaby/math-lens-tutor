import type { SolutionSubmission } from "./types";
import { deriveSubmissionListTitle, normalizeListTitle } from "./list-title";

export function formatSubmissionListTitle(
  submission: Pick<SolutionSubmission, "imageName"> & {
    analysis?: SolutionSubmission["analysis"];
  },
): string {
  return deriveSubmissionListTitle({
    listTitle: submission.analysis?.listTitle,
    weakConcepts: submission.analysis?.weakConcepts,
    recommendedFocus: submission.analysis?.recommendedFocus,
    errorSummary: submission.analysis?.errorSummary,
    problemText: submission.analysis?.problemText,
    imageName: submission.imageName,
  });
}

export function toSubmissionListItem(submission: SolutionSubmission) {
  const title = formatSubmissionListTitle(submission);
  const listTitle = normalizeListTitle(submission.analysis?.listTitle ?? "") || title;

  return {
    id: submission.id,
    imageUrl: submission.imageUrl,
    title,
    listTitle,
    createdAt: submission.createdAt,
    weakConcepts: (submission.analysis?.weakConcepts ?? []).slice(0, 3),
  };
}
