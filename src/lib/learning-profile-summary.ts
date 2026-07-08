import type { LearningProfile } from "./types";

/** 허브·훈련 탭용 — curriculum/chart/parent payload 제외 */
export type LearningProfileSummary = Pick<
  LearningProfile,
  "grade" | "stats" | "mission" | "training"
> & {
  insight: Pick<
    LearningProfile["insight"],
    | "levelLabel"
    | "masteryScore"
    | "totalAttempts"
    | "accuracy"
    | "weakConcepts"
    | "recentFeedback"
  >;
};

export function toLearningProfileSummary(
  profile: LearningProfile,
): LearningProfileSummary {
  const {
    levelLabel,
    masteryScore,
    totalAttempts,
    accuracy,
    weakConcepts,
    recentFeedback,
  } = profile.insight;
  return {
    grade: profile.grade,
    stats: profile.stats,
    mission: profile.mission,
    training: profile.training,
    insight: {
      levelLabel,
      masteryScore,
      totalAttempts,
      accuracy,
      weakConcepts,
      recentFeedback,
    },
  };
}
