"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { AppShell } from "@/components/AppShell";
import { ProgressiveSubmissionView } from "@/components/ProgressiveSubmissionView";
import { STUDY_RETURN_USER_KEY } from "@/components/HomeReturnRedirect";
import {
  applyAnalyzeStreamEvent,
  createEmptyStreamingState,
  postAnalyzeWithProgress,
  type StreamingAnalyzeState,
} from "@/lib/analyze-stream-client";
import { takePendingAnalyzeFile } from "@/lib/pending-analyze";

const STORAGE_VISION = "study_vision_deployment";
const STORAGE_TEXT = "study_text_deployment";

export default function AnalyzeResultPage() {
  const router = useRouter();
  const [state, setState] = useState<StreamingAnalyzeState | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const startedRef = useRef(false);

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;

    const file = takePendingAnalyzeFile();
    if (!file) {
      router.replace("/upload");
      return;
    }

    const objectUrl = URL.createObjectURL(file);
    setPreviewUrl(objectUrl);
    setState(createEmptyStreamingState(file.name));

    const formData = new FormData();
    formData.append("image", file);
    formData.append("qualityMode", "balanced");
    try {
      const v = localStorage.getItem(STORAGE_VISION)?.trim();
      if (v) formData.append("visionDeployment", v);
      const t = localStorage.getItem(STORAGE_TEXT)?.trim();
      if (t) formData.append("textDeployment", t);
    } catch {
      /* ignore */
    }

    void (async () => {
      try {
        const result = await postAnalyzeWithProgress(formData, {
          onPartial: (payload) => {
            setState((prev) =>
              prev
                ? applyAnalyzeStreamEvent(
                    prev,
                    payload as unknown as Record<string, unknown>,
                  )
                : prev,
            );
          },
        });

        try {
          localStorage.setItem(STUDY_RETURN_USER_KEY, "1");
        } catch {
          /* ignore */
        }

        router.replace(`/submissions/${result.submissionId}`);
      } catch (err) {
        setError(
          err instanceof Error ? err.message : "분석 요청에 실패했습니다.",
        );
      }
    })();

    return () => {
      URL.revokeObjectURL(objectUrl);
    };
  }, [router]);

  return (
    <AppShell>
      {error ? (
        <p className="rounded-2xl bg-red-500/15 p-4 text-red-100">{error}</p>
      ) : null}
      {state ? (
        <ProgressiveSubmissionView state={state} localPreviewUrl={previewUrl} />
      ) : (
        <p className="text-slate-300">분석을 준비하는 중…</p>
      )}
    </AppShell>
  );
}
