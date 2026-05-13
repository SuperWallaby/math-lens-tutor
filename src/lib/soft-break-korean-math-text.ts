/**
 * 모델이 한 줄로만 붙여 보낸 "정답 문장 + 풀이 설명"을 읽기 좋게 나눕니다.
 * 이미 줄바꿈이 있으면 건드리지 않습니다.
 */
export function softBreakAnswerExplanation(input: string): string {
  const s = input.replace(/\r\n/g, "\n");
  if (!s.trim()) {
    return s;
  }
  if (/\n/.test(s)) {
    return s;
  }

  const expl = /\s+(?=코사인|사인\s*법칙|법칙을\s*이용|따라서|그러므로|먼저|여기(?:서|부터)|이를\s*이용|식(?:으로|을)\s*|두\s*삼각형|넓이|반지름|각도\s*를|평균|삼각(?:형|함수))/;
  const m = expl.exec(s);
  if (!m || m.index === undefined) {
    return s;
  }

  const head = s.slice(0, m.index).trimEnd();
  const tail = s.slice(m.index).trimStart();
  return `${head}\n\n${tail}`;
}
