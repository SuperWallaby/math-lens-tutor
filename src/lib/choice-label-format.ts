import { normalizeAnswerForGrade } from "./answer-normalize";

const CIRCLE_NUMBERS = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩"];

function escapeRegex(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** 선지 label 앞의 "1. ", "1) ", "(1) ", "①" 등 중복 번호 제거 */
export function stripLeadingChoiceMarker(
  label: string,
  choiceId?: string,
): string {
  let text = label.trim();
  if (!text) return text;

  const id = choiceId?.trim();
  if (id) {
    const num = Number.parseInt(id, 10);
    if (num >= 1 && num <= CIRCLE_NUMBERS.length) {
      const circle = CIRCLE_NUMBERS[num - 1]!;
      if (text.startsWith(circle)) {
        text = text.slice(circle.length).trim();
      }
    }

    const escaped = escapeRegex(id);
    const idPatterns = [
      new RegExp(`^\\(?${escaped}\\)?\\.\\s+`),
      new RegExp(`^\\(?${escaped}\\)?\\)\\s+`),
      new RegExp(`^${escaped}:\\s+`),
      new RegExp(`^${escaped}\\s+(?!\\d)`),
    ];
    for (const pattern of idPatterns) {
      if (pattern.test(text)) {
        text = text.replace(pattern, "").trim();
        break;
      }
    }
  }

  text = text.replace(/^[①②③④⑤⑥⑦⑧⑨⑩]\s*/, "");
  text = text.replace(/^\(?[1-9]\)?[.):：、]\s+/, "");

  return text;
}

export function formatChoiceDisplayLabel(id: string, label: string): string {
  return `${id}. ${stripLeadingChoiceMarker(label, id)}`;
}

export function sanitizeProblemChoices<T extends { id: string; label: string }>(
  choices: T[] | undefined,
): T[] | undefined {
  if (!choices?.length) return choices;
  return choices.map((choice) => ({
    ...choice,
    label: stripLeadingChoiceMarker(choice.label, choice.id),
  }));
}

/** 객관식 선지·정답 문자열에서 중복 번호 제거 */
export function normalizeMultipleChoiceProblem<
  T extends {
    type: string;
    correctAnswer: string;
    choices?: { id: string; label: string }[];
  },
>(problem: T): { problem: T; changed: boolean } {
  if (problem.type !== "multiple_choice" || !problem.choices?.length) {
    return { problem, changed: false };
  }

  let changed = false;
  const choices = problem.choices.map((choice) => {
    const label = stripLeadingChoiceMarker(choice.label, choice.id);
    if (label !== choice.label) changed = true;
    return { ...choice, label };
  });

  let correctAnswer = problem.correctAnswer;
  const trimmed = correctAnswer.trim();
  const byId = choices.find((choice) => choice.id === trimmed);
  if (!byId) {
    for (const choice of choices) {
      const strippedCorrect = stripLeadingChoiceMarker(trimmed, choice.id);
      if (
        normalizeAnswerForGrade(strippedCorrect) ===
        normalizeAnswerForGrade(choice.label)
      ) {
        if (correctAnswer !== choice.label) {
          correctAnswer = choice.label;
          changed = true;
        }
        break;
      }
    }
  }

  return {
    problem: { ...problem, choices, correctAnswer },
    changed,
  };
}
