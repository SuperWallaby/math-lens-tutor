import Link from "next/link";
import { AppShell } from "@/components/AppShell";

export default function SignupPage() {
  return (
    <AppShell>
      <section className="mx-auto max-w-xl rounded-3xl border border-white/10 bg-white/5 p-8">
        <p className="text-sm font-medium text-blue-200">회원가입</p>
        <h1 className="mt-3 text-3xl font-black">앱에서 간편 가입해 주세요</h1>
        <p className="mt-4 leading-8 text-slate-300">
          Math Lens Tutor의 역할 기반 가입(학생·학부모·교사)과 학생 연동 기능은
          Flutter 앱을 중심으로 제공합니다. 카카오·Google·Apple로 1탭 가입 후
          바로 이용할 수 있습니다.
        </p>
        <div className="mt-8 flex flex-wrap gap-3">
          <Link
            href="/"
            className="rounded-2xl bg-blue-500 px-6 py-3 font-semibold text-white hover:bg-blue-400"
          >
            홈으로
          </Link>
          <Link
            href="/privacy"
            className="rounded-2xl border border-white/15 px-6 py-3 font-semibold text-slate-100 hover:bg-white/10"
          >
            개인정보 처리방침
          </Link>
        </div>
      </section>
    </AppShell>
  );
}
