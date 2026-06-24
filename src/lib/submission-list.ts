import type { SolutionSubmission } from "./types";
import { formatListTitleWithMath } from "./truncate-math-safe";

/** Vision이 추출한 problemText 기반 목록 제목 (파일명·해설 대신 사용). */
export function formatSubmissionListTitle(
  problemText: string,
  imageName: string,
  weakConcepts?: string[],
): string {
  const fromProblem = problemText.trim();
  if (fromProblem) {
    const concept = weakConcepts?.find((c) => c.trim())?.trim();
    return formatListTitleWithMath(fromProblem, 96, concept);
  }

  const fromName = imageName.trim();
  if (fromName) {
    return fromName.replace(/\.(jpe?g|png|webp|heic)$/i, "");
  }

  return "풀이 분석";
}

export function toSubmissionListItem(submission: SolutionSubmission) {
  return {
    id: submission.id,
    imageUrl: submission.imageUrl,
    title: formatSubmissionListTitle(
      submission.analysis?.problemText ?? "",
      submission.imageName ?? "",
      submission.analysis?.weakConcepts,
    ),
    createdAt: submission.createdAt,
    weakConcepts: (submission.analysis?.weakConcepts ?? []).slice(0, 3),
  };
}
