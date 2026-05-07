"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";

export function UploadForm() {
  const router = useRouter();
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [qualityMode, setQualityMode] = useState<
    "fast" | "balanced" | "accurate"
  >("balanced");
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
    formData.append("qualityMode", qualityMode);

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
      <fieldset className="mt-5">
        <legend className="text-sm font-medium text-slate-200">
          응답 모드
        </legend>
        <p className="mt-1 text-xs text-slate-400">
          빠른 응답은 이미지 한 번으로 분석과 유사 문제를 함께 생성합니다. 정확 모드는
          분석 후 문제 생성까지 두 단계로 나눕니다.
        </p>
        <div className="mt-3 flex flex-col gap-2 sm:flex-row sm:flex-wrap">
          {(
            [
              { value: "fast" as const, label: "빠른 응답" },
              { value: "balanced" as const, label: "밸런스" },
              { value: "accurate" as const, label: "정확한 응답" },
            ] as const
          ).map((opt) => (
            <label
              key={opt.value}
              className={`flex cursor-pointer items-center gap-2 rounded-2xl border px-4 py-2.5 text-sm transition ${
                qualityMode === opt.value
                  ? "border-blue-400 bg-blue-500/20 text-white"
                  : "border-white/10 bg-slate-900/60 text-slate-300 hover:border-white/20"
              }`}
            >
              <input
                type="radio"
                name="qualityModeUi"
                checked={qualityMode === opt.value}
                onChange={() => setQualityMode(opt.value)}
                className="h-4 w-4 accent-blue-500"
              />
              {opt.label}
            </label>
          ))}
        </div>
      </fieldset>
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
