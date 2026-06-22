import { AppShell } from "@/components/AppShell";
import Link from "next/link";
import {
  APP_NAME,
  accountDeletionUrl,
  deletedDataItems,
  supportEmail,
} from "@/lib/account-deletion-content";

const sections = [
  {
    title: "수집하는 정보",
    items: [
      "풀이 사진(이미지 바이너리) 및 업로드 시 파일 이름",
      "AI가 생성한 풀이 분석 결과(문제 텍스트, 학생 답 추정, 정답 추정, 단계·오류 요약, 약점 개념 등)",
      "자동 생성된 유사 문제 세트와 객관식·주관식 답안 제출·채점 기록",
      "카카오·Google·Apple·이메일 간편 가입 시 제공자가 부여하는 식별자와 표시 이름",
      "선택한 계정 역할(학생·학부모) 및 학생 계정의 고유번호(예: WY-XXXXXX)",
      "학부모 계정과 학생 계정 간 연결 관계(학생 고유번호로 연결)",
      "가입·세션 유지를 위한 JWT 세션 토큰(앱 로컬 저장)",
      "기기별 학습 데이터 병합을 위해 앱이 생성해 보내는 익명 기기 ID(HTTP 헤더 `X-Device-Id`)",
      "서비스 오류 대응을 위해 저장되는 API 오류 로그(경로, 메서드, userId, 오류 메시지 등)",
    ],
  },
  {
    title: "이용 목적",
    items: [
      "풀이 사진 분석 및 유사 문제 생성",
      "역할(학생·학부모)에 맞는 학습 기록·약점 개념·코칭 제공",
      "학부모가 연결한 학생의 활동·수준 조회",
      "서비스 장애 조사 및 품질 개선",
    ],
  },
  {
    title: "처리·저장의 근거 및 방식",
    items: [
      "핵심 기능 이용 전 **간편 가입(카카오·Google·Apple·이메일)** 이 필요합니다. 비밀번호 로그인은 없으며, 가입 후 세션으로 재접속합니다.",
      "서버(MongoDB)에 사용자·제출·분석·연습 기록 등이 저장됩니다.",
      "AI 분석 시 풀이 이미지 및 관련 텍스트는 Microsoft Azure OpenAI로 전송될 수 있습니다.",
      "풀이 사진은 MongoDB 또는 Cloudflare R2 등 객체 스토리지에 보관될 수 있습니다.",
    ],
  },
  {
    title: "보관 기간",
    items: [
      "수집·생성된 각 정보는 **생성일(또는 최종 갱신일) 기준 3년**이 지나면 별도의 동의 없이 삭제·파기합니다.",
      "운영상 자동 삭제 배치가 지연될 수 있으나, 3년 경과 후 합리적인 기간 내 파기를 목표로 합니다.",
    ],
  },
  {
    title: "삭제·열람 등 요청 절차",
    items: [
      "**앱에서 즉시 삭제(권장):** 로그인 후 **설정 → 계정 탈퇴**. 계정과 학습 데이터가 즉시 삭제됩니다.",
      `**웹 안내:** ${accountDeletionUrl()} (계정 및 데이터 삭제)`,
      `**이메일 요청:** 앱에 접속할 수 없는 경우 **${supportEmail()}** (또는 Google Play / App Store에 등록한 개발자 연락처)로 삭제를 요청할 수 있습니다.`,
      "**메일 제목 예:** `[우열] 계정 및 데이터 삭제 요청`",
      "**메일 본문:** 가입 이메일 또는 OAuth 제공자, 역할, 학생 고유번호(해당 시), 최근 이용 일시 등",
      "**처리 기한:** 본인 확인 후 **30일 이내** 삭제. 법령상 보관 의무가 있는 경우 해당 기간 동안만 보관합니다.",
      "**게스트 체험:** 로그인 없이 이용한 데이터는 기기 ID로 묶입니다. 앱 삭제만으로 서버 데이터는 지워지지 않으므로, 서버 삭제가 필요하면 이메일로 요청해 주세요.",
    ],
  },
];

export default function PrivacyPage() {
  return (
    <AppShell>
      <article className="mx-auto max-w-3xl">
        <p className="text-sm font-medium text-wy-primary">Privacy Policy</p>
        <h1 className="mt-3 text-4xl font-black">개인정보 처리방침</h1>
        <p className="mt-4 leading-8 text-wy-text-sub">
          <strong className="text-foreground">{APP_NAME}</strong>는 간편 가입 후 풀이
          사진을 분석하고 학습 기록을 제공하기 위해 아래와 같이 최소한의 정보를
          처리합니다. 계정·데이터 삭제 방법은{" "}
          <Link href="/account-deletion" className="text-wy-primary underline">
            계정 및 데이터 삭제
          </Link>{" "}
          페이지를 참고해 주세요.
        </p>

        <div className="mt-10 space-y-6">
          {sections.map((section) => (
            <section
              key={section.title}
              id={section.title === "삭제·열람 등 요청 절차" ? "deletion" : undefined}
              className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6"
            >
              <h2 className="text-xl font-bold">{section.title}</h2>
              <ul className="mt-4 list-disc space-y-2 pl-5 leading-7 text-wy-text-sub">
                {section.items.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
              {section.title === "삭제·열람 등 요청 절차" ? (
                <ul className="mt-4 list-disc space-y-2 pl-5 leading-7 text-wy-text-sub">
                  <li className="font-medium text-foreground">삭제 시 제거되는 주요 데이터:</li>
                  {deletedDataItems.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              ) : null}
            </section>
          ))}
        </div>

        <p className="mt-10 text-sm leading-7 text-wy-text-muted">
          시행일: 2026-06-22 · 내용 변경 시 본 페이지에 반영합니다.
        </p>
      </article>
    </AppShell>
  );
}
