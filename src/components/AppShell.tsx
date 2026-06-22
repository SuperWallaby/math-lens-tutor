import Link from "next/link";
import type { ReactNode } from "react";
import { isDevEnvironment } from "@/lib/is-dev";
import { APP_NAME } from "@/lib/account-deletion-content";

export function AppShell({ children }: { children: ReactNode }) {
  const showDevNav = isDevEnvironment();
  return (
    <div className="min-h-screen bg-wy-bg text-foreground">
      <header className="print:hidden border-b border-wy-border bg-wy-surface">
        <nav className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <Link href="/" className="text-lg font-bold tracking-tight">
            {APP_NAME}
          </Link>
          <div className="flex items-center gap-4 text-sm text-wy-text-sub">
            <Link href="/upload" className="hover:text-wy-primary">
              사진 분석
            </Link>
            <Link href="/practice/demo-set" className="hover:text-wy-primary">
              샘플 문제
            </Link>
            <Link href="/dashboard" className="hover:text-wy-primary">
              대시보드
            </Link>
            {showDevNav ? (
              <Link href="/settings" className="hover:text-wy-primary">
                설정
              </Link>
            ) : null}
            <Link href="/signup" className="hover:text-wy-primary">
              가입
            </Link>
            <Link href="/account-deletion" className="hover:text-wy-primary">
              계정 삭제
            </Link>
            <Link href="/privacy" className="hover:text-wy-primary">
              개인정보
            </Link>
          </div>
        </nav>
      </header>
      <main className="mx-auto w-full max-w-6xl px-6 py-10">{children}</main>
    </div>
  );
}
