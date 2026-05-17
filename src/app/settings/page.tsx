"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { AppShell } from "@/components/AppShell";

const STORAGE_VISION = "study_vision_deployment";
const STORAGE_TEXT = "study_text_deployment";

const DEPLOYMENT_HINTS: Record<string, string> = {
  "gpt-5.4": "GPT-5.4 — 비전·텍스트 (권장)",
  "gpt-4o": "GPT-4o — 비전(OCR)",
  "trx-gpt-4-1-vision": "GPT-4.1 비전",
  "o4-mini": "o4-mini — 추론·텍스트 (GPT-5 계열 전)",
  "gpt-5.4-pro": "GPT-5.4 Pro (텍스트)",
  "gpt-5.4-pro-2": "GPT-5.4 Pro 복제 배포",
  "trx-gpt-4-1-mini": "GPT-4.1 mini",
};

function labelFor(name: string) {
  return DEPLOYMENT_HINTS[name] ?? name;
}

export default function SettingsPage() {
  const [visionOptions, setVisionOptions] = useState<string[]>([]);
  const [textOptions, setTextOptions] = useState<string[]>([]);
  const [configured, setConfigured] = useState(false);
  const [vision, setVision] = useState("");
  const [text, setText] = useState("");
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch("/api/settings/model-options");
        const data = (await res.json()) as {
          vision?: string[];
          text?: string[];
          configured?: boolean;
        };
        if (cancelled) return;
        setVisionOptions(data.vision ?? []);
        setTextOptions(data.text ?? []);
        setConfigured(Boolean(data.configured));
      } catch {
        if (!cancelled) {
          setVisionOptions([]);
          setTextOptions([]);
          setConfigured(false);
        }
      }
      try {
        setVision(
          typeof window !== "undefined"
            ? (localStorage.getItem(STORAGE_VISION) ?? "")
            : "",
        );
        setText(
          typeof window !== "undefined"
            ? (localStorage.getItem(STORAGE_TEXT) ?? "")
            : "",
        );
      } finally {
        if (!cancelled) setLoaded(true);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  function persistVision(next: string) {
    setVision(next);
    if (typeof window === "undefined") return;
    if (!next) localStorage.removeItem(STORAGE_VISION);
    else localStorage.setItem(STORAGE_VISION, next);
  }

  function persistText(next: string) {
    setText(next);
    if (typeof window === "undefined") return;
    if (!next) localStorage.removeItem(STORAGE_TEXT);
    else localStorage.setItem(STORAGE_TEXT, next);
  }

  return (
    <AppShell>
      <div className="mx-auto max-w-xl space-y-8">
        <div>
          <p className="text-sm text-slate-400">분석에 쓸 Azure 배포 후보</p>
          <h1 className="mt-2 text-3xl font-black">설정</h1>
          <p className="mt-3 text-sm leading-relaxed text-slate-300">
            사진 분석 요청 시 이 브라우저에만 저장됩니다. 선택한 이름은 서버
            허용 목록(
            <code className="rounded bg-slate-800 px-1 text-xs">
              AZURE_OPENAI_*_DEPLOYMENT_OPTIONS
            </code>
            )에 있을 때만 적용됩니다.
          </p>
        </div>

        <div className="rounded-2xl border border-amber-500/25 bg-amber-500/10 p-4 text-sm leading-relaxed text-amber-100">
          <strong className="font-semibold">o1 / o3-mini:</strong> Azure는 해당
          버전을 Deprecating 처리해 <strong>신규 배포가 거절</strong>되는 경우가
          많습니다. 같은 리소스에는 <strong>o4-mini</strong>(텍스트·추론 후보)를
          배포해 두었습니다. 카탈로그에 <code className="text-xs">o3</code>{" "}
          풀모델은 없고 <code className="text-xs">o3-mini</code>만 있습니다.
        </div>

        {!configured && loaded ? (
          <p className="text-sm text-slate-400">
            Azure 환경 변수가 없어 후보 목록을 불러오지 못했습니다. 로컬 데모만
            쓰는 경우 이 페이지는 비워 둘 수 있습니다.
          </p>
        ) : null}

        <div className="space-y-6 rounded-3xl border border-white/10 bg-white/10 p-6">
          <div>
            <label className="block text-sm font-medium text-slate-200">
              비전 배포 (풀이 사진 OCR)
            </label>
            <p className="mt-1 text-xs text-slate-400">
              미선택 시 서버 기본(
              <code className="rounded bg-slate-900 px-1">
                AZURE_OPENAI_DEPLOYMENT_VISION
              </code>{" "}
              등)을 씁니다.
            </p>
            <select
              value={vision}
              onChange={(e) => persistVision(e.target.value)}
              disabled={!loaded}
              className="mt-3 w-full rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm text-slate-100"
            >
              <option value="">기본 (서버)</option>
              {visionOptions.map((name) => (
                <option key={name} value={name}>
                  {labelFor(name)}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-200">
              텍스트 배포 (튜터·유사 문제 등)
            </label>
            <p className="mt-1 text-xs text-slate-400">
              선택 시 응답 모드와 관계없이 해당 배포로 텍스트 단계를 보냅니다.
              정확 모드의 2차 검토도 같은 이름을 사용합니다.
            </p>
            <select
              value={text}
              onChange={(e) => persistText(e.target.value)}
              disabled={!loaded}
              className="mt-3 w-full rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm text-slate-100"
            >
              <option value="">기본 (모드별 서버 배포)</option>
              {textOptions.map((name) => (
                <option key={name} value={name}>
                  {labelFor(name)}
                </option>
              ))}
            </select>
          </div>
        </div>

        <p className="text-center text-sm">
          <Link href="/upload" className="text-blue-300 hover:text-blue-200">
            ← 사진 분석으로
          </Link>
        </p>
      </div>
    </AppShell>
  );
}
