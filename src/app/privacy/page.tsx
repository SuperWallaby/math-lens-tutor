import { AppShell } from "@/components/AppShell";

const sections = [
  {
    title: "수집하는 정보",
    items: [
      "풀이 사진(이미지 바이너리) 및 업로드 시 파일 이름",
      "AI가 생성한 풀이 분석 결과(문제 텍스트, 학생 답 추정, 정답 추정, 단계·오류 요약, 약점 개념 등)",
      "자동 생성된 유사 문제 세트와 객관식·주관식 답안 제출·채점 기록",
      "로그인 없이 기기별 학습 데이터를 구분하기 위해 앱이 생성해 보내는 익명 기기 ID(HTTP 헤더 `X-Device-Id`)",
      "서비스 오류 대응을 위해 저장되는 API 오류 로그(경로, 메서드, 위와 연결되는 userId, 오류 메시지, User-Agent 등)",
    ],
  },
  {
    title: "이용 목적",
    items: [
      "풀이 사진 분석 및 유사 문제 생성",
      "기기(익명 ID) 단위 학습 기록·정답률·약점 개념·대시보드 형태의 피드백 제공",
      "서비스 장애 조사 및 품질 개선",
    ],
  },
  {
    title: "처리·저장의 근거 및 방식",
    items: [
      "회원가입을 요구하지 않으며, 식별은 익명 기기 ID에 한합니다.",
      "서버에 MongoDB가 설정된 경우: 위 정보는 MongoDB 컬렉션(예: `solution_images`, `solution_submissions`, `generated_problem_sets`, `problem_attempts`, `api_error_logs`)에 저장됩니다.",
      "MongoDB가 없는 환경: 동일 성격의 데이터가 서버 프로세스 메모리에만 임시 보관될 수 있으며, 재시작 등으로 소실될 수 있습니다.",
      "AI 분석 시 풀이 이미지 및 관련 텍스트는 Microsoft Azure OpenAI로 전송될 수 있습니다.",
      "서버는 요청 헤더의 기기 ID를 `device:` 접두사가 붙은 `userId`로 저장합니다. 헤더가 없거나 형식이 맞지 않으면 내부 데모용 식별자로 묶일 수 있어, 실제 기기별 삭제를 원하면 앱이 정상적으로 기기 ID를 보내는지 확인하는 것이 좋습니다.",
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
      "**접수 채널:** Google Play 또는 Apple App Store에 등록한 **고객 지원 이메일**(또는 동일 목적의 공식 연락처)로 메일을 보내 주세요. 본 웹 서비스는 `https://study-alpha-rosy.vercel.app` 에서 제공됩니다.",
      "**메일 제목 예:** `[Math Lens Tutor] 개인정보 삭제 요청`",
      "**메일 본문에 포함할 내용:** (1) 요청 유형: 삭제·열람·정정 중 무엇인지 (2) 가능하면 앱이 서버로 보내는 **익명 기기 ID 문자열 전체**(앱 설정에 표시되지 않을 수 있으나, 운영자가 안내하는 방법으로 확인 가능한 경우) (3) 기기 ID를 적기 어렵다면, **문제 제출·분석을 수행한 대략적인 일시(타임존 포함)**·사용 경로(웹/안드로이드/iOS 등)를 알려 주시면, 다른 이용자와 혼동되지 않도록 확인하는 데 도움이 됩니다.",
      "**처리:** 신청인이 해당 데이터의 주체임을 합리적으로 확인한 뒤, 접수일로부터 **30일 이내**에 MongoDB(및 동일 데이터를 보관하는 시스템)에서 위 `userId` 및 동일 기기와 연결된 풀이 이미지·제출·문제 세트·시도·관련 오류 로그를 삭제합니다. 법령에 따라 보관해야 하는 경우에는 그에 따릅니다.",
      "**앱 삭제:** 단말기에서 앱을 삭제하면 기기에 저장된 익명 ID가 제거되고, 재설치 시 **새 ID**가 발급됩니다. 서버에 이미 저장된 이전 ID와 연결된 데이터까지 지우려면 위 메일 절차로 **별도 삭제 요청**이 필요합니다.",
    ],
  },
];

export default function PrivacyPage() {
  return (
    <AppShell>
      <article className="mx-auto max-w-3xl">
        <p className="text-sm font-medium text-blue-200">Privacy Policy</p>
        <h1 className="mt-3 text-4xl font-black">개인정보 처리방침</h1>
        <p className="mt-4 leading-8 text-slate-300">
          <strong className="text-white">Math Lens Tutor</strong>는 로그인 없이 풀이
          사진을 분석하고 학습 기록을 제공하기 위해 아래와 같이 최소한의 정보를
          처리합니다. 본 방침은 서비스 동작 및 서버 구현에 맞추어 작성되었으며,
          고객 지원 연락처는 각 앱 마켓플레이스에 등록한 정보를 따릅니다.
        </p>

        <div className="mt-10 space-y-6">
          {sections.map((section) => (
            <section
              key={section.title}
              className="rounded-3xl border border-white/10 bg-white/5 p-6"
            >
              <h2 className="text-xl font-bold">{section.title}</h2>
              <ul className="mt-4 list-disc space-y-2 pl-5 leading-7 text-slate-300">
                {section.items.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </section>
          ))}
        </div>

        <p className="mt-10 text-sm leading-7 text-slate-400">
          시행일: 본 문서 게시일 이후 제공되는 서비스부터 적용합니다. 내용이
          변경되면 동일 페이지에 개정 시행일과 함께 반영합니다.
        </p>
      </article>
    </AppShell>
  );
}
