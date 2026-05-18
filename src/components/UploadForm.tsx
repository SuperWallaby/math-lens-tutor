"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { setPendingAnalyzeFile } from "@/lib/pending-analyze";

export function UploadForm() {
  const router = useRouter();
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const previewUrlRef = useRef<string | null>(null);

  useEffect(() => {
    return () => {
      if (previewUrlRef.current) {
        URL.revokeObjectURL(previewUrlRef.current);
      }
    };
  }, []);

  function handleFileChange(nextFile: File | null) {
    if (previewUrlRef.current) {
      URL.revokeObjectURL(previewUrlRef.current);
      previewUrlRef.current = null;
    }

    if (!nextFile) {
      setPreviewUrl(null);
      return;
    }

    const objectUrl = URL.createObjectURL(nextFile);
    previewUrlRef.current = objectUrl;
    setPreviewUrl(objectUrl);

    setPendingAnalyzeFile(nextFile);
    router.push("/analyze/result");
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
        파일을 선택하면 결과 화면으로 이동하며 분석이 진행됩니다.
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
    </div>
  );
}
