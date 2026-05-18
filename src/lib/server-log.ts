/** Vercel/로컬 서버 로그 — 프로덕션 디버깅용 */
export function studyLog(
  scope: string,
  message: string,
  data?: Record<string, unknown>,
) {
  const payload = data ? { ...data } : {};
  if (Object.keys(payload).length > 0) {
    console.log(`[study:${scope}] ${message}`, payload);
  } else {
    console.log(`[study:${scope}] ${message}`);
  }
}
