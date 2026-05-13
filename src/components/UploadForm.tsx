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
  const qualityModeRef = useRef(qualityMode);
  /** 새 선택·언마운트 시 증가 → 진행 중 요청 결과 무시 */
  const analyzeSeqRef = useRef(0);

  useEffect(() => {
    qualityModeRef.current = qualityMode;
  }, [qualityMode]);

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
    formData.append("qualityMode", qualityModeRef.current);

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
        파일을 선택하면 바로 분석이 시작됩니다. 응답 모드는 이미지 선택 전에 고르세요.
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
      <fieldset className="mt-5" disabled={isLoading}>
        <legend className="text-sm font-medium text-slate-200">
          응답 모드
        </legend>
        <p className="mt-1 text-xs text-slate-400">
          분석 피드백과 유사 문제 세트는 서버에서 서로 병렬로 생성합니다. 모드는 사용하는
          Azure 배포(모델)만 바꿉니다.
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
        type="button"
        disabled={!file || isLoading}
        onClick={() => file && runAnalyze(file)}
        className="mt-6 w-full rounded-2xl bg-blue-500 px-5 py-3 font-semibold text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {isLoading ? "Azure AI가 풀이를 분석 중..." : "다시 분석"}
      </button>
      <p className="mt-4 text-xs leading-6 text-slate-400">
        Azure OpenAI 환경 변수가 없으면 샘플 분석으로, MongoDB가 없으면 메모리 저장소로 데모 흐름이 실행됩니다.
      </p>
    </div>
  );
}
