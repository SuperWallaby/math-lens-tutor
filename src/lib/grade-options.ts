export const GRADE_OPTIONS = [
  "초1",
  "초2",
  "초3",
  "초4",
  "초5",
  "초6",
  "중1",
  "중2",
  "중3",
  "고1",
  "고2",
  "고3",
  "대학생 이상",
] as const;

export type GradeOption = (typeof GRADE_OPTIONS)[number];

const GRADE_AGES: Record<GradeOption, number> = {
  초1: 8,
  초2: 9,
  초3: 10,
  초4: 11,
  초5: 12,
  초6: 13,
  중1: 14,
  중2: 15,
  중3: 16,
  고1: 17,
  고2: 18,
  고3: 19,
  "대학생 이상": 22,
};

export function ageFromGrade(grade: string): number | undefined {
  return GRADE_AGES[grade as GradeOption];
}

export function isValidGrade(grade: string): grade is GradeOption {
  return (GRADE_OPTIONS as readonly string[]).includes(grade);
}
