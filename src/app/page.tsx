import Link from "next/link";
import { AppShell } from "@/components/AppShell";
import { HomeReturnRedirect } from "@/components/HomeReturnRedirect";

export default function Home() {
  return (
    <AppShell>
      <HomeReturnRedirect />
      <section className="grid gap-10 lg:grid-cols-[1.2fr_0.8fr] lg:items-center">
        <div>
          <p className="mb-4 inline-flex rounded-full bg-[var(--wy-primary-tint)] px-4 py-2 text-sm text-wy-primary">
            사진 기반 수학 오답 코치
          </p>
          <h1 className="text-5xl font-black leading-tight tracking-tight">
            풀이 사진을 읽고, 약점을 잡고, 비슷한 문제 5개로 다시 훈련합니다.
          </h1>
          <p className="mt-6 max-w-2xl text-lg leading-8 text-wy-text-sub">
            풀이 과정과 선택 답안을 분석하고, 부족한 개념을 짚어 유사 문제로
            다시 훈련할 수 있습니다.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              href="/upload"
              className="rounded-wy-md bg-wy-primary px-6 py-3 font-semibold text-white hover:bg-wy-primary-dark"
            >
              풀이 사진 분석하기
            </Link>
            <Link
              href="/dashboard"
              className="rounded-wy-md border border-wy-border-strong px-6 py-3 font-semibold text-foreground hover:bg-wy-surface-muted"
            >
              학습 대시보드 보기
            </Link>
          </div>
        </div>
        <div className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
          <h2 className="text-xl font-bold">MVP 기능</h2>
          <div className="mt-5 space-y-4 text-sm leading-6 text-wy-text-sub">
            <p>1. 풀이 사진 업로드 및 AI 분석</p>
            <p>2. 오답 원인과 부족 개념 진단</p>
            <p>3. 유사 문제 5개 자동 생성</p>
            <p>4. 객관식/주관식 답안 제출 및 채점</p>
            <p>5. 누적 데이터 기반 수준 피드백</p>
          </div>
        </div>
      </section>
    </AppShell>
  );
}
