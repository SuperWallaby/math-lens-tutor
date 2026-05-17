import { env } from "./env";

function parseCommaDeployments(raw: string | undefined): string[] {
  if (!raw?.trim()) return [];
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function dedupeOrdered(names: (string | undefined)[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const n of names) {
    const t = n?.trim();
    if (t && !seen.has(t)) {
      seen.add(t);
      out.push(t);
    }
  }
  return out;
}

/** 서버 env 기준 후보. 미설정 시 현재 단일 배포 키들에서 자동 구성 */
export function buildVisionDeploymentCandidateList(): string[] {
  const explicit = parseCommaDeployments(env.azureOpenAiVisionDeploymentOptions);
  if (explicit.length > 0) return explicit;
  return dedupeOrdered([
    env.azureOpenAiDeploymentVision,
    env.azureOpenAiDeploymentBalanced,
    env.azureOpenAiDeploymentFast,
    env.azureOpenAiDeployment,
  ]);
}

export function buildTextDeploymentCandidateList(): string[] {
  const explicit = parseCommaDeployments(env.azureOpenAiTextDeploymentOptions);
  if (explicit.length > 0) return explicit;
  return dedupeOrdered([
    env.azureOpenAiDeploymentAccurate,
    env.azureOpenAiDeploymentBalanced,
    env.azureOpenAiDeploymentFast,
    env.azureOpenAiDeployment,
  ]);
}

/**
 * 클라이언트가 고른 배포 이름이 서버 허용 목록에 있을 때만 사용.
 * 아니면 fallback (모드별 기본 배포 등).
 */
export function pickAllowedDeployment(
  requested: unknown,
  candidates: string[],
  fallback: string | null,
): string | null {
  const r = typeof requested === "string" ? requested.trim() : "";
  if (r && candidates.includes(r)) {
    return r;
  }
  return fallback;
}
