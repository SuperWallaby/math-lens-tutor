import { AppShell } from "@/components/AppShell";

const sections = [
  {
    title: "수집하는 정보",
    items: [
      "풀이 사진 및 파일 이름",
      "AI가 생성한 풀이 분석, 약점 개념, 추천 학습 내용",
      "자동 생성된 유사 문제와 답안 제출 기록",
      "로그인 없이 사용자를 구분하기 위한 익명 기기 ID",
      "서비스 오류 분석을 위한 API 에러 로그",
    ],
  },
  {
    title: "이용 목적",
    items: [
      "풀이 사진 분석과 유사 문제 생성",
      "기기별 학습 기록, 정답률, 약점 개념 제공",
      "서비스 장애 조사 및 품질 개선",
    ],
  },
  {
    title: "저장 및 처리 위치",
    items: [
      "앱은 로그인 정보를 요구하지 않으며, 익명 기기 ID만 서버 API에 전송합니다.",
      "풀이 사진과 학습 데이터는 서버의 MongoDB에 저장될 수 있습니다.",
      "AI 분석을 위해 풀이 사진과 분석 프롬프트가 서버에서 Azure OpenAI로 전송될 수 있습니다.",
      "MongoDB가 설정되지 않은 개발 환경에서는 데이터가 서버 메모리에만 임시 저장됩니다.",
    ],
  },
  {
    title: "보관 및 삭제",
    items: [
      "정식 운영 전까지 데이터 보관 기간과 삭제 요청 절차는 운영 정책에 맞춰 확정합니다.",
      "사용자가 삭제를 요청하면 익명 기기 ID 기준으로 관련 제출, 분석, 풀이 기록을 삭제할 수 있도록 운영합니다.",
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
          Math Lens Tutor는 로그인 없이 풀이 사진을 분석하고 학습 기록을
          제공하기 위해 최소한의 정보를 처리합니다. 본 방침은 출시 전 검토용
          초안이며, 실제 운영 시 회사명, 연락처, 보관 기간, 삭제 절차를 확정해
          게시해야 합니다.
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
      </article>
    </AppShell>
  );
}
