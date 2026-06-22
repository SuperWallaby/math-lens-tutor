import type { SolutionSubmission } from "./types";

function truncateForListTitle(text: string, maxLen = 72): string {
  let normalized = text
    .replace(/^\s*\d+[\.)]\s*/, "")
    .replace(/\$([^$]+)\$/g, "$1")
    .replace(/\s+/g, " ")
    .trim();

  if (normalized.length <= maxLen) {
    return normalized;
  }

  return `${normalized.slice(0, maxLen - 1)}…`;
}

/** Vision이 추출한 problemText 기반 목록 제목 (파일명·해설 대신 사용). */
export function formatSubmissionListTitle(
  problemText: string,
  imageName: string,
): string {
  const fromProblem = problemText.trim();
  if (fromProblem) {
    return truncateForListTitle(fromProblem);
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
      submission.analysis.problemText,
      submission.imageName,
    ),
    createdAt: submission.createdAt,
    weakConcepts: submission.analysis.weakConcepts.slice(0, 3),
  };
}
