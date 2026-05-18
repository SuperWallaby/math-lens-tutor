"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { STUDY_RETURN_USER_KEY } from "@/components/HomeReturnRedirect";

/** `src/app/settings/page.tsx` 와 동일 키 */
const STORAGE_VISION = "study_vision_deployment";
const STORAGE_TEXT = "study_text_deployment";

export function UploadForm() {
  const router = useRouter();
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const previewUrlRef = useRef<string | null>(null);
  /** 새 선택·언마운트 시 증가 → 진행 중 요청 결과 무시 */
  const analyzeSeqRef = useRef(0);

  useEffect(() => {
    return () => {
      analyzeSeqRef.current++;
      if (previewUrlRef.current) {
        URL.revokeObjectURL(previewUrlRef.current);
      }
    };
  }, []);

  async function runAnalyze(uploadFile: File) {
    const seq = ++analyzeSeqRef.current;
    setIsLoading(true);
    setError(null);

    const formData = new FormData();
    formData.append("image", uploadFile);
    formData.append("qualityMode", "balanced");
    try {
      const v = localStorage.getItem(STORAGE_VISION)?.trim();
      if (v) formData.append("visionDeployment", v);
      const t = localStorage.getItem(STORAGE_TEXT)?.trim();
      if (t) formData.append("textDeployment", t);
    } catch {
      /* ignore */
    }

    try {
      const response = await fetch("/api/analyze", {
        method: "POST",
        body: formData,
      });
      const payload = (await response.json()) as {
        submissionId?: string;
        error?: string;
      };

      if (seq !== analyzeSeqRef.current) return;

      setIsLoading(false);

      if (!response.ok || !payload.submissionId) {
        setError(payload.error ?? "분석 요청에 실패했습니다.");
        return;
      }

      try {
        localStorage.setItem(STUDY_RETURN_USER_KEY, "1");
      } catch {
        /* ignore */
      }
      router.push(`/submissions/${payload.submissionId}`);
    } catch {
      if (seq !== analyzeSeqRef.current) return;
      setIsLoading(false);
      setError("분석 요청에 실패했습니다.");
    }
  }

  function handleFileChange(nextFile: File | null) {
    if (previewUrlRef.current) {
      URL.revokeObjectURL(previewUrlRef.current);
      previewUrlRef.current = null;
    }

    if (!nextFile) {
      analyzeSeqRef.current++;
      setFile(null);
      setPreviewUrl(null);
      setError(null);
      setIsLoading(false);
      return;
    }

    setFile(nextFile);
    setError(null);

    const objectUrl = URL.createObjectURL(nextFile);
    previewUrlRef.current = objectUrl;
    setPreviewUrl(objectUrl);

    queueMicrotask(() => {
      runAnalyze(nextFile);
    });
  }

  return (
    <div className="rounded-3xl border border-white/10 bg-white/10 p-6 shadow-2xl">
      <label className="block">
        <span className="text-sm font-medium text-slate-200">
          풀이 사진 업로드
        </span>
        <input
          type="file"
          accept="image/*"
          onChange={(event) =>
            handleFileChange(event.target.files?.[0] ?? null)
          }
          className="mt-3 block w-full rounded-2xl border border-white/10 bg-slate-900 p-4 text-sm text-slate-200 file:mr-4 file:rounded-full file:border-0 file:bg-blue-500 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-white"
        />
      </label>
      <p className="mt-2 text-xs text-slate-400">
        파일을 선택하면 바로 분석이 시작됩니다.
      </p>
      {previewUrl ? (
        <div className="mt-5 overflow-hidden rounded-2xl border border-white/10 bg-slate-900">
          <div className="border-b border-white/10 px-4 py-3 text-sm text-slate-300">
            선택한 이미지 미리보기
          </div>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={previewUrl}
            alt="선택한 풀이 사진 미리보기"
            className="max-h-[520px] w-full object-contain"
          />
        </div>
      ) : null}
      {error ? <p className="mt-4 text-sm text-red-300">{error}</p> : null}
      <button
        type="button"
        disabled={!file || isLoading}
        onClick={() => file && runAnalyze(file)}
        className="mt-6 w-full rounded-2xl bg-blue-500 px-5 py-3 font-semibold text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {isLoading ? "풀이를 분석 중..." : "다시 분석"}
      </button>
    </div>
  );
}
