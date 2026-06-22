import Link from "next/link";
import { AppShell } from "@/components/AppShell";

type LinkPageProps = {
  searchParams: Promise<{ code?: string }>;
};

function normalizeCode(raw?: string) {
  const value = raw?.trim().toUpperCase() ?? "";
  if (!/^WY-[A-HJ-NP-Z2-9]{6}$/.test(value)) {
    return null;
  }
  return value;
}

export default async function StudentLinkPage({ searchParams }: LinkPageProps) {
  const params = await searchParams;
  const code = normalizeCode(params.code);

  return (
    <AppShell>
      <section className="mx-auto max-w-xl rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-8 text-center">
        <p className="text-sm font-medium text-wy-primary">학생 연결</p>
        <h1 className="mt-3 text-3xl font-black">우열 학생 연결 코드</h1>
        {code ? (
          <>
            <p className="mt-4 leading-8 text-wy-text-sub">
              학부모·교사님은 우열 앱에서 아래 코드를 입력해 학생과 연결할 수
              있습니다.
            </p>
            <div className="mx-auto mt-8 max-w-sm rounded-[var(--wy-radius-md)] border-2 border-wy-primary bg-wy-surface-muted px-6 py-8">
              <p className="text-sm text-wy-text-sub">학생 고유번호</p>
              <p className="mt-2 text-3xl font-black tracking-widest">{code}</p>
            </div>
            <p className="mt-6 text-sm leading-7 text-wy-text-sub">
              우열 앱 → 설정 → 학생 연결에서 코드를 입력하면 자동으로
              연결됩니다.
            </p>
          </>
        ) : (
          <p className="mt-4 leading-8 text-wy-text-sub">
            유효한 연결 코드가 없습니다. 학생에게 받은{" "}
            <strong>WY-XXXXXX</strong> 형식 코드가 포함된 링크로 다시
            열어주세요.
          </p>
        )}
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link
            href="/"
            className="rounded-wy-md bg-wy-primary px-6 py-3 font-semibold text-white hover:bg-wy-primary-dark"
          >
            우열 홈
          </Link>
        </div>
      </section>
    </AppShell>
  );
}
