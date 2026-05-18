/** 로컬 `next dev` 등 — 프로덕션 빌드에서는 false */
export function isDevEnvironment() {
  return process.env.NODE_ENV === "development";
}
