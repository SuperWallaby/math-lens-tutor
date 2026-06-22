import type { Metadata } from "next";
import Link from "next/link";
import type { ReactNode } from "react";

import { AppShell } from "@/components/AppShell";
import {
  APP_NAME,
  APP_NAME_EN,
  accountDeletionUrl,
  deletedDataItems,
  retainedDataItems,
  supportEmail,
} from "@/lib/account-deletion-content";

export const metadata: Metadata = {
  title: `계정 및 데이터 삭제 | ${APP_NAME}`,
  description: `${APP_NAME} 계정 탈퇴 및 개인정보·학습 데이터 삭제 방법 (Google Play / App Store)`,
};

function StepCard({
  step,
  title,
  children,
}: {
  step: string;
  title: string;
  children: ReactNode;
}) {
  return (
    <section className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
      <p className="text-xs font-bold uppercase tracking-wide text-wy-primary">
        {step}
      </p>
      <h2 className="mt-2 text-xl font-bold">{title}</h2>
      <div className="mt-4 space-y-3 leading-7 text-wy-text-sub">{children}</div>
    </section>
  );
}

export default function AccountDeletionPage() {
  const email = supportEmail();
  const mailSubject = encodeURIComponent(`[${APP_NAME}] 계정 및 데이터 삭제 요청`);
  const mailBody = encodeURIComponent(
    [
      "요청 유형: 계정 및 관련 데이터 삭제",
      "",
      "가입 이메일 또는 OAuth 제공자(Google/Apple/Kakao):",
      "앱에서 사용한 역할(학생/학부모):",
      "학생 고유번호(해당 시):",
      "추가 확인 정보(최근 업로드 일시 등):",
    ].join("\n"),
  );
  const mailto = `mailto:${email}?subject=${mailSubject}&body=${mailBody}`;

  return (
    <AppShell>
      <article className="mx-auto max-w-3xl">
        <p className="text-sm font-medium text-wy-primary">Account &amp; Data Deletion</p>
        <h1 className="mt-3 text-4xl font-black">계정 및 데이터 삭제</h1>
        <p className="mt-4 leading-8 text-wy-text-sub">
          <strong className="text-foreground">{APP_NAME}</strong>({APP_NAME_EN}) 이용자는
          아래 방법으로 <strong className="text-foreground">계정과 관련 학습 데이터</strong>를
          삭제할 수 있습니다. Google Play · App Store 심사 및 이용자 문의용 공개 페이지입니다.
        </p>

        <div className="mt-10 space-y-6">
          <StepCard step="방법 1 · 권장" title="앱에서 즉시 탈퇴 (로그인 상태)">
            <ol className="list-decimal space-y-2 pl-5">
              <li>앱을 실행하고 로그인합니다.</li>
              <li>
                하단 탭 <strong>설정</strong>으로 이동합니다.
              </li>
              <li>
                화면 하단 <strong>계정 탈퇴</strong>를 누르고 확인합니다.
              </li>
            </ol>
            <p>
              확인 즉시 서버에서 계정과 아래 「삭제되는 데이터」가 삭제되며, 되돌릴 수
              없습니다.
            </p>
          </StepCard>

          <StepCard step="방법 2" title="이메일로 삭제 요청 (앱 접속 불가 시)">
            <p>
              앱에 로그인할 수 없거나 기기를 분실한 경우, 등록된 고객 지원 이메일로
              요청해 주세요.
            </p>
            <p>
              <strong>이메일:</strong>{" "}
              <a href={mailto} className="font-semibold text-wy-primary underline">
                {email}
              </a>
            </p>
            <p>
              <strong>제목 예:</strong> [{APP_NAME}] 계정 및 데이터 삭제 요청
            </p>
            <p>본문에 가입에 사용한 이메일·OAuth 제공자, 역할, 학생 고유번호(해당 시),
              최근 이용 일시 등을 적어 주시면 본인 확인 후 처리합니다.</p>
            <p>
              접수 후 <strong>30일 이내</strong> 삭제를 완료합니다.
            </p>
          </StepCard>

          <section className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
            <h2 className="text-xl font-bold">삭제되는 데이터</h2>
            <ul className="mt-4 list-disc space-y-2 pl-5 leading-7 text-wy-text-sub">
              {deletedDataItems.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </section>

          <section className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
            <h2 className="text-xl font-bold">일부 보관·지연 삭제</h2>
            <ul className="mt-4 list-disc space-y-2 pl-5 leading-7 text-wy-text-sub">
              {retainedDataItems.map((item) => (
                <li key={item}>{item}</li>
              ))}
              <li>
                생성일 기준 <strong>3년</strong>이 지난 데이터는 정책에 따라 자동 파기될 수
                있습니다.
              </li>
            </ul>
          </section>

          <section className="rounded-[var(--wy-radius-md)] border border-dashed border-wy-border bg-wy-bg p-6">
            <h2 className="text-xl font-bold">English (for app store review)</h2>
            <div className="mt-4 space-y-3 leading-7 text-wy-text-sub">
              <p>
                <strong>In-app (recommended):</strong> Sign in → open{" "}
                <strong>Settings</strong> (설정) → tap <strong>Delete account</strong>{" "}
                (계정 탈퇴) → confirm. Account and learning data are deleted immediately.
              </p>
              <p>
                <strong>By email:</strong> If you cannot access the app, email{" "}
                <a href={mailto} className="text-wy-primary underline">
                  {email}
                </a>{" "}
                with subject &quot;[{APP_NAME_EN}] Account deletion request&quot;. We
                verify ownership and delete within <strong>30 days</strong>.
              </p>
              <p>
                <strong>Guest mode:</strong> &quot;Try without signing in&quot; stores data
                under a device ID. Uninstalling the app removes the local ID; to delete
                server data tied to a guest session, use the email method with approximate
                usage time.
              </p>
            </div>
          </section>
        </div>

        <p className="mt-10 text-sm leading-7 text-wy-text-muted">
          자세한 개인정보 처리 내용은{" "}
          <Link href="/privacy" className="text-wy-primary underline">
            개인정보 처리방침
          </Link>
          을 참고해 주세요.
          <br />
          공개 URL: {accountDeletionUrl()}
        </p>
      </article>
    </AppShell>
  );
}
