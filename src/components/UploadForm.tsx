"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";

export function UploadForm() {
  const router = useRouter();
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
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

    setFile(nextFile);
    setError(null);

    if (!nextFile) {
      setPreviewUrl(null);
      return;
    }

    const objectUrl = URL.createObjectURL(nextFile);
    previewUrlRef.current = objectUrl;
    setPreviewUrl(objectUrl);
  }

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!file) {
      setError("풀이 사진을 먼저 선택해 주세요.");
      return;
    }

    setIsLoading(true);
    setError(null);

    const formData = new FormData();
    formData.append("image", file);

    const response = await fetch("/api/analyze", {
      method: "POST",
      body: formData,
    });
    const payload = (await response.json()) as {
      submissionId?: string;
      error?: string;
    };

    setIsLoading(false);

    if (!response.ok || !payload.submissionId) {
      setError(payload.error ?? "분석 요청에 실패했습니다.");
      return;
    }

    router.push(`/submissions/${payload.submissionId}`);
  }

  return (
    <form
      onSubmit={onSubmit}
      className="rounded-3xl border border-white/10 bg-white/10 p-6 shadow-2xl"
    >
      <label className="block">
        <span className="text-sm font-medium text-slate-200">
          풀이 사진 업로드
        </span>
        <input
          type="file"
          accept="image/*"
          onChange={(event) => handleFileChange(event.target.files?.[0] ?? null)}
          className="mt-3 block w-full rounded-2xl border border-white/10 bg-slate-900 p-4 text-sm text-slate-200 file:mr-4 file:rounded-full file:border-0 file:bg-blue-500 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-white"
        />
      </label>
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
        type="submit"
        disabled={isLoading}
        className="mt-6 w-full rounded-2xl bg-blue-500 px-5 py-3 font-semibold text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {isLoading ? "Azure AI가 풀이를 분석 중..." : "분석하고 유사 문제 생성"}
      </button>
      <p className="mt-4 text-xs leading-6 text-slate-400">
        Azure OpenAI 환경 변수가 없으면 샘플 분석으로, MongoDB가 없으면 메모리 저장소로 데모 흐름이 실행됩니다.
      </p>
    </form>
  );
}
