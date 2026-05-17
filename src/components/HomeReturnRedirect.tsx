"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/** `UploadForm` 성공 시 설정 — 재방문 시 홈 대신 업로드로 이동 */
export const STUDY_RETURN_USER_KEY = "study_return_user";

export function HomeReturnRedirect() {
  const router = useRouter();

  useEffect(() => {
    try {
      if (localStorage.getItem(STUDY_RETURN_USER_KEY) === "1") {
        router.replace("/upload");
      }
    } catch {
      /* ignore */
    }
  }, [router]);

  return null;
}
