import { stripMathForListPreview } from "./truncate-math-safe";

const MAX_LIST_TITLE = 48;

function isGoodListTitleCandidate(text: string): boolean {
  if (text.length < 4 || text.length > MAX_LIST_TITLE) return false;
  if (/^사진/.test(text)) return false;
  if (/[.!?…]/.test(text) && text.length > 20) return false;
  if (text.includes("알 수 없") || text.includes("때문에")) return false;
  return true;
}

function isUselessImageName(name: string): boolean {
  const base = name.replace(/\.(jpe?g|png|webp|heic|gif)$/i, "").trim();
  if (!base) return true;
  if (/^(IMG_|DSC_|KakaoTalk_|photo_|image_picker_|scaled_)/i.test(base)) return true;
  if (/^[0-9A-F-]{20,}$/i.test(base)) return true;
  return base.includes("_") && !base.includes(" ") && base.length >= 24;
}

/** 목록용 짧은 제목 — 수식·LaTeX 없이 한글만 */
export function normalizeListTitle(raw: string): string {
  const plain = stripMathForListPreview(raw)
    .replace(/[「」『』"“”]/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (!plain) return "";
  if (plain.length <= MAX_LIST_TITLE) return plain;
  return `${plain.slice(0, MAX_LIST_TITLE - 1).trimEnd()}…`;
}

export function deriveSubmissionListTitle(params: {
  listTitle?: string | null;
  weakConcepts?: string[];
  recommendedFocus?: string[];
  errorSummary?: string | null;
  problemText?: string | null;
  imageName?: string;
}): string {
  const fromField = normalizeListTitle(params.listTitle ?? "");
  if (fromField && isGoodListTitleCandidate(fromField)) return fromField;

  for (const concept of params.weakConcepts ?? []) {
    const title = normalizeListTitle(concept);
    if (title && isGoodListTitleCandidate(title)) return title;
  }

  for (const focus of params.recommendedFocus ?? []) {
    const title = normalizeListTitle(focus);
    if (isGoodListTitleCandidate(title)) return title;
  }

  const fromError = normalizeListTitle(params.errorSummary ?? "");
  if (isGoodListTitleCandidate(fromError)) return fromError;

  const fromProblem = normalizeListTitle(params.problemText ?? "");
  if (isGoodListTitleCandidate(fromProblem)) return fromProblem;

  const fromName = params.imageName?.trim();
  if (fromName && !isUselessImageName(fromName)) {
    const title = fromName.replace(/\.(jpe?g|png|webp|heic|gif)$/i, "");
    if (isGoodListTitleCandidate(title)) return title;
  }

  return "풀이 분석";
}
