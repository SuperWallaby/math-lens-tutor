import { AppShell } from "@/components/AppShell";
import { DashboardChart } from "@/components/DashboardChart";
import { MathMixedRich } from "@/components/MathMixedRich";
import { DEMO_USER_ID, getLearningInsight } from "@/lib/store";

export default async function DashboardPage() {
  const insight = await getLearningInsight(DEMO_USER_ID);

  return (
    <AppShell>
      <div className="mb-8">
        <p className="text-sm font-medium text-blue-200">Learning Profile</p>
        <h1 className="mt-3 text-4xl font-black">사용자 수준 피드백</h1>
        <p className="mt-4 max-w-3xl leading-8 text-slate-300">
          제출한 풀이와 유사 문제 응답을 누적해 현재 수준, 약점 개념, 다음
          학습 액션을 요약합니다.
        </p>
      </div>

      <section className="grid gap-6 md:grid-cols-3">
        <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
          <p className="text-sm text-slate-400">현재 수준</p>
          <p className="mt-3 text-3xl font-black">{insight.levelLabel}</p>
        </div>
        <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
          <p className="text-sm text-slate-400">숙련도 점수</p>
          <p className="mt-3 text-3xl font-black">{insight.masteryScore}</p>
        </div>
        <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
          <p className="text-sm text-slate-400">누적 정답률</p>
          <p className="mt-3 text-3xl font-black">{insight.accuracy}%</p>
        </div>
      </section>

      <section className="mt-6 grid gap-6 lg:grid-cols-[0.9fr_1.1fr]">
        <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
          <h2 className="text-xl font-bold">약점 개념</h2>
          <div className="mt-5 space-y-3">
            {insight.weakConcepts.map((item) => (
              <div
                key={item.concept}
                className="flex items-center justify-between rounded-2xl bg-slate-900 p-4"
              >
                <span>{item.concept}</span>
                <span className="text-sm text-red-200">오답 {item.misses}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
          <h2 className="text-xl font-bold">풀이 결과 차트</h2>
          <div className="mt-5 rounded-2xl bg-white p-4">
            <DashboardChart chart={insight.trendChart} />
          </div>
        </div>
      </section>

      <section className="mt-6 rounded-3xl border border-white/10 bg-white/10 p-6">
        <h2 className="text-xl font-bold">다음 학습 피드백</h2>
        <div className="mt-5 grid gap-3 md:grid-cols-2">
          {insight.recentFeedback.map((feedback) => (
            <p
              key={feedback}
              className="rounded-2xl bg-slate-900 p-4 leading-7 text-slate-300"
            >
              <MathMixedRich text={feedback} />
            </p>
          ))}
        </div>
      </section>
    </AppShell>
  );
}
