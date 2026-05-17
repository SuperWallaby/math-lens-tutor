import Link from "next/link";
import type { ReactNode } from "react";

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <header className="print:hidden border-b border-white/10 bg-slate-950/80 backdrop-blur">
        <nav className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <Link href="/" className="text-lg font-bold tracking-tight">
            Math Lens Tutor
          </Link>
          <div className="flex items-center gap-4 text-sm text-slate-300">
            <Link href="/upload" className="hover:text-white">
              사진 분석
            </Link>
            <Link href="/practice/demo-set" className="hover:text-white">
              데모 문제
            </Link>
            <Link href="/dashboard" className="hover:text-white">
              대시보드
            </Link>
            <Link href="/settings" className="hover:text-white">
              설정
            </Link>
            <Link href="/privacy" className="hover:text-white">
              개인정보
            </Link>
          </div>
        </nav>
      </header>
      <main className="mx-auto w-full max-w-6xl px-6 py-10">{children}</main>
    </div>
  );
}
