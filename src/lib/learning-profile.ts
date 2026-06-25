import {
  GRADE_BAND_ORDER,
  GRADE_BAND_REPRESENTATIVE,
  gradeToBand,
  matchUnitForConcept,
  unitsForGrade,
  type GradeBand,
} from "./curriculum";
import {
  getAttempts,
  getLatestProblemSetForUser,
  getSubmissionsByUserId,
} from "./store";
import {
  aggregateUnitPracticeForUser,
  countActiveBankItemsGroupedByUnit,
  getPracticeMistakesForUser,
  getScannedProblemsForUser,
  type UnitPracticeAggregate,
} from "./problem-bank-store";
import { getLearningProfileForUser } from "./learning-profile-snapshot";
import { buildSampleInsight } from "./sample";
import { buildTrainingSnapshot } from "./concept-training";
import {
  buildParentCoachingCard,
  buildParentWrongExplains,
  pickGradingPoint,
  truncatePreserveBreaks,
} from "./parent-coaching";
import type {
  ConceptStatusItem,
  CurriculumUnitProgress,
  LearningProfile,
  ParentActionItem,
  PracticeMistakeRecord,
  ProblemAttempt,
  ScannedProblemRecord,
  SolutionSubmission,
  TeacherClassOverview,
  TeacherStudentOverview,
  User,
  WeeklyTrendPoint,
} from "./types";
import { findUserById, getLinkedStudents } from "./users";

function startOfWeek(date: Date): Date {
  const d = new Date(date);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

function weekKey(date: Date): string {
  return startOfWeek(date).toISOString().slice(0, 10);
}

function attemptsInWeek(
  attempts: ProblemAttempt[],
  weekStart: Date,
): ProblemAttempt[] {
  const end = new Date(weekStart);
  end.setDate(end.getDate() + 7);
  return attempts.filter((a) => {
    const t = new Date(a.createdAt).getTime();
    return t >= weekStart.getTime() && t < end.getTime();
  });
}

function accuracyOf(attempts: ProblemAttempt[]): number {
  if (attempts.length === 0) return 0;
  const correct = attempts.filter((a) => a.isCorrect).length;
  return Math.round((correct / attempts.length) * 100);
}

function collectConceptMisses(
  attempts: ProblemAttempt[],
  submissions: SolutionSubmission[],
  mistakes: PracticeMistakeRecord[],
  scanned: ScannedProblemRecord[],
): Map<string, number> {
  const misses = new Map<string, number>();

  for (const mistake of mistakes) {
    for (const concept of mistake.conceptTags) {
      const key = concept.trim();
      if (!key) continue;
      misses.set(key, (misses.get(key) ?? 0) + 1);
    }
    if (mistake.conceptPrimary.trim()) {
      const key = mistake.conceptPrimary.trim();
      misses.set(key, (misses.get(key) ?? 0) + 1);
    }
  }

  for (const record of scanned) {
    for (const concept of [...record.weakConcepts, ...record.conceptTags]) {
      const key = concept.trim();
      if (!key) continue;
      misses.set(key, (misses.get(key) ?? 0) + 1);
    }
  }

  for (const submission of submissions) {
    for (const concept of submission.analysis.weakConcepts) {
      const key = concept.trim();
      if (!key) continue;
      misses.set(key, (misses.get(key) ?? 0) + 1);
    }
  }

  return misses;
}

function collectConceptScores(
  attempts: ProblemAttempt[],
  submissions: SolutionSubmission[],
): Map<string, { correct: number; total: number }> {
  const scores = new Map<string, { correct: number; total: number }>();

  for (const submission of submissions.slice(0, 8)) {
    for (const concept of submission.analysis.recommendedFocus) {
      const key = concept.trim();
      if (!key) continue;
      const entry = scores.get(key) ?? { correct: 0, total: 0 };
      entry.total += 1;
      scores.set(key, entry);
    }
  }

  for (const attempt of attempts) {
    const key = attempt.isCorrect ? "연습 정답" : "연습 오답";
    const entry = scores.get(key) ?? { correct: 0, total: 0 };
    entry.total += 1;
    if (attempt.isCorrect) entry.correct += 1;
    scores.set(key, entry);
  }

  return scores;
}

function buildWeeklyTrend(attempts: ProblemAttempt[]): WeeklyTrendPoint[] {
  const now = startOfWeek(new Date());
  const points: WeeklyTrendPoint[] = [];

  for (let i = 3; i >= 0; i -= 1) {
    const weekStart = new Date(now);
    weekStart.setDate(weekStart.getDate() - i * 7);
    const weekAttempts = attemptsInWeek(attempts, weekStart);
    const acc = accuracyOf(weekAttempts);
    points.push({
      weekLabel: `${4 - i}주`,
      accuracy: acc,
      summary:
        weekAttempts.length === 0
          ? "이번 주 기록 없음"
          : `${weekAttempts.length}문제 풀이 · 정답률 ${acc}%`,
    });
  }

  return points;
}

function computeStreakWeeks(attempts: ProblemAttempt[]): number {
  if (attempts.length === 0) return 0;

  let streak = 0;
  const now = startOfWeek(new Date());
  for (let i = 0; i < 12; i += 1) {
    const weekStart = new Date(now);
    weekStart.setDate(weekStart.getDate() - i * 7);
    if (attemptsInWeek(attempts, weekStart).length > 0) {
      streak += 1;
    } else if (i > 0) {
      break;
    }
  }
  return streak;
}

function buildConceptStatus(
  misses: Map<string, number>,
): ConceptStatusItem[] {
  const items = [...misses.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([concept, count]) => {
      let status: ConceptStatusItem["status"] = "learning";
      let label = "연습 필요";
      if (count >= 5) {
        status = "weak";
        label = "취약";
      } else if (count <= 1) {
        status = "strong";
        label = "완료";
      }
      return { concept, misses: count, status, label };
    });

  return items.length > 0
    ? items
    : [
        {
          concept: "아직 약점 데이터가 쌓이지 않았어요",
          misses: 0,
          status: "learning" as const,
          label: "시작 전",
        },
      ];
}

function legacyUnitKeywordSignal(
  unit: { id: string },
  grade: string | undefined,
  misses: Map<string, number>,
  submissions: SolutionSubmission[],
  mistakes: PracticeMistakeRecord[],
  scanned: ScannedProblemRecord[],
): { hitCount: number; missCount: number } {
  let missCount = 0;
  let hitCount = 0;

  for (const [concept, count] of misses) {
    if (matchUnitForConcept(concept, grade)?.id === unit.id) {
      missCount += count;
    }
  }

  const textSources = [
    ...submissions.map((submission) =>
      [
        ...submission.analysis.weakConcepts,
        submission.analysis.errorSummary,
        submission.analysis.problemText,
      ].join(" "),
    ),
    ...scanned.map((record) =>
      [
        ...record.weakConcepts,
        ...record.conceptTags,
        record.errorSummary,
        record.problemText,
      ].join(" "),
    ),
    ...mistakes.map((record) =>
      [...record.conceptTags, record.conceptPrimary, record.feedback].join(" "),
    ),
  ];

  for (const text of textSources) {
    if (matchUnitForConcept(text, grade)?.id === unit.id) {
      hitCount += 1;
    }
  }

  return { hitCount, missCount };
}

function computeUnitPercent(params: {
  poolSize: number;
  practice: {
    attemptedUnique: number;
    correctUnique: number;
    gradedCount: number;
    correctCount: number;
  };
  legacy: { hitCount: number; missCount: number };
}): { percent: number; status: CurriculumUnitProgress["status"] } {
  const { poolSize, practice, legacy } = params;

  if (practice.attemptedUnique > 0) {
    const targetPool = Math.max(poolSize, practice.attemptedUnique, 10);
    const coverage = (practice.attemptedUnique / targetPool) * 100;
    const accuracy =
      practice.gradedCount > 0
        ? (practice.correctCount / practice.gradedCount) * 100
        : 0;
    const mastery = (practice.correctUnique / targetPool) * 100;
    const percent = Math.min(
      100,
      Math.round(coverage * 0.4 + accuracy * 0.35 + mastery * 0.25),
    );

    let status: CurriculumUnitProgress["status"] = "learning";
    if (percent >= 80 && accuracy >= 70 && practice.correctUnique >= 3) {
      status = "done";
    } else if (percent < 35 || (practice.gradedCount >= 5 && accuracy < 45)) {
      status = "weak";
    }
    return { percent, status };
  }

  if (legacy.hitCount > 0 || legacy.missCount > 0) {
    const percent = Math.max(
      5,
      Math.min(35, 28 - legacy.missCount * 4 + Math.min(legacy.hitCount, 3) * 2),
    );
    return { percent, status: "learning" };
  }

  return { percent: 0, status: "none" };
}

function buildCurriculumUnits(
  grade: string | undefined,
  misses: Map<string, number>,
  submissions: SolutionSubmission[],
  mistakes: PracticeMistakeRecord[],
  scanned: ScannedProblemRecord[],
  unitPractice: Map<string, UnitPracticeAggregate>,
  poolByUnit: Map<string, number>,
): CurriculumUnitProgress[] {
  const units = unitsForGrade(grade);
  if (units.length === 0) return [];

  return units.map((unit) => {
    const practice = unitPractice.get(unit.id) ?? {
      attemptedUnique: 0,
      correctUnique: 0,
      gradedCount: 0,
      correctCount: 0,
    };
    const poolSize = poolByUnit.get(unit.id) ?? 0;
    const legacy = legacyUnitKeywordSignal(
      unit,
      grade,
      misses,
      submissions,
      mistakes,
      scanned,
    );
    const { percent, status } = computeUnitPercent({ poolSize, practice, legacy });

    return {
      id: unit.id,
      section: unit.section,
      name: unit.name,
      subtitle: unit.subtitle,
      percent,
      status,
    };
  });
}

function buildCurriculumByBand(
  misses: Map<string, number>,
  submissions: SolutionSubmission[],
  mistakes: PracticeMistakeRecord[],
  scanned: ScannedProblemRecord[],
  unitPractice: Map<string, UnitPracticeAggregate>,
  poolByUnit: Map<string, number>,
): Record<GradeBand, CurriculumUnitProgress[]> {
  const byBand = {} as Record<GradeBand, CurriculumUnitProgress[]>;
  for (const band of GRADE_BAND_ORDER) {
    byBand[band] = buildCurriculumUnits(
      GRADE_BAND_REPRESENTATIVE[band],
      misses,
      submissions,
      mistakes,
      scanned,
      unitPractice,
      poolByUnit,
    );
  }
  return byBand;
}

async function buildMission(
  userId: string,
  attempts: ProblemAttempt[],
): Promise<LearningProfile["mission"]> {
  const latest = await getLatestProblemSetForUser(userId);
  if (!latest) return null;

  const answered = new Set(
    attempts.filter((a) => a.setId === latest.id).map((a) => a.problemId),
  );
  const remaining = latest.problems.filter((p) => !answered.has(p.id));
  if (remaining.length === 0) return null;

  const tags = latest.problems.flatMap((p) => p.conceptTags).slice(0, 2);

  return {
    title: latest.title,
    subtitle: latest.learningGoal,
    remainingCount: remaining.length,
    setId: latest.id,
    conceptTags: tags,
  };
}

async function buildParentActions(
  profile: Omit<
    LearningProfile,
    "parentActions" | "parentCoachingCard" | "parentWrongExplains"
  >,
  coaching: ReturnType<typeof buildParentCoachingCard>,
  wrongExplains: ReturnType<typeof buildParentWrongExplains>,
): Promise<ParentActionItem[]> {
  const actions: ParentActionItem[] = [];

  if (coaching) {
    actions.push({
      icon: "💬",
      title: "오늘 코칭 질문 해보기",
      subtitle: coaching.question,
    });
  }

  if (profile.mission && profile.mission.remainingCount > 0) {
    actions.push({
      icon: "✅",
      title: "유사문제 풀었는지 확인하기",
      subtitle: `${profile.mission.title} · ${profile.mission.remainingCount}개 남음`,
    });
  }

  if (wrongExplains.length > 0) {
    const first = wrongExplains[0];
    actions.push({
      icon: "📖",
      title: "틀린 문제, 이렇게 설명해 주세요",
      subtitle: truncatePreserveBreaks(first.easyExplain, 72),
    });
  }

  if (profile.strongConcepts.length > 0) {
    const top = profile.strongConcepts[0];
    actions.push({
      icon: "🎉",
      title: `${top.concept} 잘하고 있어요 — 칭찬해 주세요`,
      subtitle: "짧은 격려가 다음 학습 동기가 됩니다.",
    });
  }

  return actions.slice(0, 4);
}

function truncatePlain(text: string, max: number): string {
  const t = text.replace(/\s+/g, " ").trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max - 1)}…`;
}

export async function buildLearningProfile(
  userId: string,
  grade?: string | null,
): Promise<LearningProfile> {
  const [attempts, submissions, mistakes, scanned, unitPractice, poolByUnit, user] =
    await Promise.all([
      getAttempts(userId),
      getSubmissionsByUserId(userId, 30),
      getPracticeMistakesForUser(userId),
      getScannedProblemsForUser(userId),
      aggregateUnitPracticeForUser(userId),
      countActiveBankItemsGroupedByUnit(),
      findUserById(userId),
    ]);

  const insight = buildSampleInsight(attempts);
  const weeklyTrend = buildWeeklyTrend(attempts);
  const thisWeek = attemptsInWeek(attempts, startOfWeek(new Date()));
  const lastWeekStart = startOfWeek(new Date());
  lastWeekStart.setDate(lastWeekStart.getDate() - 7);
  const lastWeek = attemptsInWeek(attempts, lastWeekStart);

  const thisAcc = accuracyOf(thisWeek);
  const lastAcc = accuracyOf(lastWeek);
  const misses = collectConceptMisses(attempts, submissions, mistakes, scanned);
  const conceptStatus = buildConceptStatus(misses);
  const curriculumByBand = buildCurriculumByBand(
    misses,
    submissions,
    mistakes,
    scanned,
    unitPractice,
    poolByUnit,
  );
  const band = gradeToBand(grade);
  const curriculumUnits = curriculumByBand[band];

  const scores = collectConceptScores(attempts, submissions);
  const strongConcepts = [...scores.entries()]
    .map(([concept, s]) => ({
      concept,
      score: s.total ? Math.round((s.correct / s.total) * 100) : 0,
    }))
    .filter((s) => s.score >= 70 && s.concept !== "연습 오답")
    .sort((a, b) => b.score - a.score)
    .slice(0, 4);

  const mission = await buildMission(userId, attempts);
  const training = await buildTrainingSnapshot({
    userId,
    displayName: user?.displayName,
    attempts,
    mistakes,
    scanned,
    submissions,
  });

  const base: Omit<
    LearningProfile,
    "parentActions" | "parentCoachingCard" | "parentWrongExplains"
  > = {
    grade: grade?.trim() || "중1",
    insight: {
      ...insight,
      trendChart: {
        type: "bar",
        data: {
          labels: weeklyTrend.map((w) => w.weekLabel),
          datasets: [
            {
              label: "주차별 정답률",
              data: weeklyTrend.map((w) => w.accuracy),
              backgroundColor: ["#FF8C00", "#B8860B", "#2ECC40", "#007BFF"],
            },
          ],
        },
        options: { responsive: true },
      },
    },
    stats: {
      accuracy: thisAcc || insight.accuracy,
      accuracyDelta: thisAcc - lastAcc,
      totalProblems: attempts.length,
      problemsDelta: thisWeek.length - lastWeek.length,
      streakWeeks: computeStreakWeeks(attempts),
    },
    mission,
    training,
    conceptStatus,
    strongConcepts,
    weeklyTrend,
    curriculumUnits,
    curriculumByBand,
    chainWarning: null,
    weeklyReport: {
      weekLabel: "이번 주",
      period: formatWeekPeriod(startOfWeek(new Date())),
      cycle: buildWeeklyCycle(submissions, insight, thisAcc, lastAcc),
      unitMastery: curriculumUnits
        .filter((u) => u.percent > 0)
        .slice(0, 4)
        .map((u) => ({ name: u.name, percent: u.percent })),
    },
  };

  const parentWrongExplains = buildParentWrongExplains({
    submissions,
    mistakes,
  });
  const parentCoachingCard = buildParentCoachingCard({
    submissions,
    mistakes,
  });
  const parentActions = await buildParentActions(
    base,
    parentCoachingCard,
    parentWrongExplains,
  );

  return { ...base, parentCoachingCard, parentWrongExplains, parentActions };
}

function formatWeekPeriod(start: Date): string {
  const end = new Date(start);
  end.setDate(end.getDate() + 6);
  const fmt = (d: Date) =>
    `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, "0")}.${String(d.getDate()).padStart(2, "0")}`;
  return `${fmt(start)} ~ ${fmt(end)}`;
}

function buildWeeklyCycle(
  submissions: SolutionSubmission[],
  insight: LearningProfile["insight"],
  thisAcc: number,
  lastAcc: number,
) {
  const latest = submissions[0];
  const weak =
    insight.weakConcepts[0]?.concept ??
    latest?.analysis.weakConcepts[0] ??
    "부족한 개념";

  return [
    {
      step: 1,
      label: "약점 발견",
      title: "약점 발견",
      text: latest
        ? `${latest.analysis.errorSummary.slice(0, 80)}`
        : `${weak}에서 반복 오류가 관찰됩니다.`,
    },
    {
      step: 2,
      label: "솔루션 제시",
      title: "솔루션 제시",
      text: latest
        ? `유사문제 5개와 ${latest.analysis.recommendedFocus.slice(0, 2).join(", ") || "추천 학습"} 제공`
        : "AI 유사문제 세트로 보완 학습을 진행했습니다.",
    },
    {
      step: 3,
      label: "결과 확인",
      title: "결과 확인",
      text: `정답률 ${lastAcc}% → ${thisAcc || insight.accuracy}% (${thisAcc - lastAcc >= 0 ? "+" : ""}${thisAcc - lastAcc}%)`,
    },
    {
      step: 4,
      label: "성장 증명",
      title: "성장 증명",
      text:
        thisAcc >= lastAcc
          ? "꾸준히 정답률이 개선되고 있어요!"
          : "이번 주는 다시 한번 유사문제 연습이 필요해요.",
    },
    {
      step: 5,
      label: "부모 확인",
      title: "부모님이 확인할 것",
      text: latest
        ? "자녀가 유사문제를 끝까지 풀었는지, 포기하지 않았는지 확인해 주세요."
        : "이번 주 학습 기록을 함께 살펴보세요.",
    },
    {
      step: 6,
      label: "대화하기",
      title: "오늘의 코칭 질문",
      text: latest
        ? `「${pickGradingPoint(latest.analysis)}」 — 왜 그렇게 생각했는지 물어보세요.`
        : `${weak} 개념을 일상 예시로 설명해 보세요.`,
    },
    {
      step: 7,
      label: "채점 포인트",
      title: "핵심 채점 포인트",
      text: latest
        ? pickGradingPoint(latest.analysis)
        : "틀린 문제의 핵심 개념을 아이에게 설명해 달라고 요청해 보세요.",
    },
  ];
}

function studentStatus(
  accuracy: number,
): Pick<TeacherStudentOverview, "status" | "statusLabel"> {
  if (accuracy < 40) return { status: "danger", statusLabel: "위험" };
  if (accuracy < 60) return { status: "warning", statusLabel: "주의" };
  if (accuracy >= 80) return { status: "excellent", statusLabel: "우수" };
  return { status: "normal", statusLabel: "보통" };
}

export async function buildTeacherClassOverview(
  teacher: User,
): Promise<TeacherClassOverview> {
  const linked = await getLinkedStudents(teacher.id);
  const profiles = await Promise.all(
    linked.map(async (student) => {
      const user = await findUserById(student.id);
      const profile = await getLearningProfileForUser(
        student.id,
        user?.grade ?? "중1",
      );
      const acc = profile.stats.accuracy || profile.insight.accuracy;
      const status = studentStatus(acc);
      return {
        id: student.id,
        displayName: student.displayName,
        studentCode: student.studentCode,
        accuracy: acc,
        ...status,
        weakConcept:
          profile.conceptStatus.find((c) => c.status === "weak")?.concept ??
          profile.insight.weakConcepts[0]?.concept ??
          "데이터 수집 중",
        totalAttempts: profile.insight.totalAttempts,
        profile,
      };
    }),
  );

  const accuracies = profiles.map((p) => p.accuracy);
  const classAverage = accuracies.length
    ? Math.round(accuracies.reduce((a, b) => a + b, 0) / accuracies.length)
    : 0;
  const deltas = profiles.map((p) => p.profile.stats.accuracyDelta);
  const avgDelta = deltas.length
    ? Math.round(deltas.reduce((a, b) => a + b, 0) / deltas.length)
    : 0;

  const dangerStudents = profiles
    .filter((p) => p.status === "danger" || p.status === "warning")
    .sort((a, b) => a.accuracy - b.accuracy);

  const unitMap = new Map<string, number[]>();
  for (const p of profiles) {
    for (const unit of p.profile.curriculumUnits) {
      if (unit.percent <= 0) continue;
      const list = unitMap.get(unit.name) ?? [];
      list.push(unit.percent);
      unitMap.set(unit.name, list);
    }
  }

  const classUnitAverages = [...unitMap.entries()]
    .map(([name, values]) => ({
      name,
      percent: Math.round(values.reduce((a, b) => a + b, 0) / values.length),
    }))
    .sort((a, b) => a.percent - b.percent)
    .slice(0, 4);

  const weakestUnit = classUnitAverages[0];

  const recommendations = [];
  if (weakestUnit) {
    recommendations.push({
      icon: "📌",
      title: `${weakestUnit.name} 집중 설명을 권장해요`,
      subtitle: `반 평균 ${weakestUnit.percent}%로 가장 취약합니다.`,
    });
  }
  if (dangerStudents.length > 0) {
    recommendations.push({
      icon: "👥",
      title: `위험군 ${dangerStudents.length}명 개별 면담 권장`,
      subtitle: dangerStudents
        .slice(0, 3)
        .map((s) => s.displayName)
        .join(" · "),
    });
  }

  return {
    totalStudents: profiles.length,
    atRiskCount: dangerStudents.filter((s) => s.status === "danger").length,
    classAverageAccuracy: classAverage,
    accuracyDelta: avgDelta,
    organizationName: teacher.organizationName ?? null,
    dangerStudents: dangerStudents.map(({ profile: _, ...rest }) => rest),
    students: profiles
      .map(({ profile: _, ...rest }) => rest)
      .sort((a, b) => a.accuracy - b.accuracy),
    classUnitAverages,
    recommendations,
  };
}
