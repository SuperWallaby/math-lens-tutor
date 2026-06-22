/** API 값 easy | medium | hard → UI 한글 */
export function formatDifficultyLabel(difficulty: string): string {
  switch (difficulty.trim().toLowerCase()) {
    case "easy":
      return "쉬움";
    case "hard":
      return "어려움";
    default:
      return "보통";
  }
}
