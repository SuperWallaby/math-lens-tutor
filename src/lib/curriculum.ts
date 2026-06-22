export type CurriculumUnit = {
  id: string;
  section: string;
  name: string;
  subtitle: string;
  keywords: string[];
};

export type GradeBand =
  | "e12"
  | "e34"
  | "e56"
  | "m1"
  | "m2"
  | "m3"
  | "h1"
  | "h2"
  | "h3";

/** 2022 개정 교육과정 기준 학년대별 목차 */
export const GRADE_BAND_LABELS: Record<GradeBand, string> = {
  e12: "초1~2",
  e34: "초3~4",
  e56: "초5~6",
  m1: "중1",
  m2: "중2",
  m3: "중3",
  h1: "고1",
  h2: "고2",
  h3: "고3",
};

export const CHAIN_WARNINGS: Record<GradeBand, string> = {
  e12: "초등 기초가 탄탄해야 중학교 수학이 쉬워요!",
  e34: "분수·소수 개념이 중학교 유리수의 기초예요!",
  e56: "비와 비율이 약하면 중학교 비례식·함수에 영향이 있어요!",
  m1: "일차방정식이 약하면 중2 연립방정식 전에 보완이 필요해요!",
  m2: "일차함수가 약하면 중3 이차함수, 고1 함수에도 영향이 있어요!",
  m3: "이차방정식·이차함수가 약하면 고1 공통수학에 영향을 줄 수 있어요!",
  h1: "공통수학 함수가 약하면 고2 수학Ⅱ 미분·적분에 영향이 있어요!",
  h2: "미적분 기초가 약하면 고3 미적분 심화에 영향을 줄 수 있어요!",
  h3: "수능 대비 최종 단계입니다. 선택과목을 집중 점검하세요!",
};

export const GRADE_BAND_ORDER: GradeBand[] = [
  "e12",
  "e34",
  "e56",
  "m1",
  "m2",
  "m3",
  "h1",
  "h2",
  "h3",
];

/** 학년대 탭 → 대표 학년 (목차·개념 매칭용) */
export const GRADE_BAND_REPRESENTATIVE: Record<GradeBand, string> = {
  e12: "초1",
  e34: "초3",
  e56: "초5",
  m1: "중1",
  m2: "중2",
  m3: "중3",
  h1: "고1",
  h2: "고2",
  h3: "고3",
};

export const GRADE_BAND_PLACEHOLDER: Record<
  GradeBand,
  { title: string; subtitle: string }
> = {
  e12: {
    title: "초1~2학년",
    subtitle: "9·50까지의 수, 덧셈·뺄셈, 도형, 길이·시간, 규칙 찾기",
  },
  e34: {
    title: "초3~4학년",
    subtitle: "곱셈·나눗셈, 분수, 도형, 규칙과 대응, 자료 정리",
  },
  e56: {
    title: "초5~6학년",
    subtitle: "약수·배수, 분수·소수, 비와 비율, 넓이·부피, 가능성",
  },
  m1: {
    title: "중1",
    subtitle: "수와 연산·문자와 식·좌표와 그래프·도형·통계 (2022 개정)",
  },
  m2: {
    title: "중2",
    subtitle: "유리수·연립방정식·일차함수·도형의 성질·닮음·확률",
  },
  m3: {
    title: "중3",
    subtitle: "제곱근·인수분해·이차방정식·이차함수·삼각비·통계",
  },
  h1: {
    title: "고1",
    subtitle: "공통수학Ⅰ·Ⅱ — 다항식·방정식·경우의 수·행렬·함수·수열",
  },
  h2: {
    title: "고2",
    subtitle: "수학Ⅰ·Ⅱ — 지수·로그·삼각함수·수열·극한·미분·적분",
  },
  h3: {
    title: "고3",
    subtitle: "선택과목 — 확률과 통계·미적분·기하",
  },
};

const E12_UNITS: CurriculumUnit[] = [
  {
    id: "e12-numbers-9",
    section: "1. 수와 연산",
    name: "① 9까지의 수",
    subtitle: "수 세기·수 읽기·수 쓰기·수의 순서",
    keywords: ["9까지", "수 세기", "수 읽기", "수 쓰기", "수의 순서"],
  },
  {
    id: "e12-numbers-50",
    section: "1. 수와 연산",
    name: "② 50까지의 수",
    subtitle: "두 자리 수·수직선·수의 크기 비교",
    keywords: ["50까지", "두 자리", "수직선", "크기 비교"],
  },
  {
    id: "e12-add-sub",
    section: "1. 수와 연산",
    name: "③ 덧셈과 뺄셈",
    subtitle: "받아올림·받아내림·세 자리 수",
    keywords: ["덧셈", "뺄셈", "받아올림", "받아내림"],
  },
  {
    id: "e12-shapes",
    section: "2. 도형",
    name: "④ 여러 가지 도형",
    subtitle: "삼각형·사각형·원·도형 만들기",
    keywords: ["도형", "삼각형", "사각형", "원", "평면"],
  },
  {
    id: "e12-measure",
    section: "3. 측정",
    name: "⑤ 길이와 시간",
    subtitle: "길이 재기·시각·날짜·시간",
    keywords: ["길이", "시간", "시각", "날짜", "측정"],
  },
  {
    id: "e12-patterns",
    section: "4. 규칙성",
    name: "⑥ 규칙 찾기",
    subtitle: "규칙성·패턴·배열",
    keywords: ["규칙", "패턴", "규칙성", "배열"],
  },
];

const E34_UNITS: CurriculumUnit[] = [
  {
    id: "e34-mult-div",
    section: "1. 수와 연산",
    name: "① 곱셈과 나눗셈",
    subtitle: "곱셈구구·나눗셈·곱셈과 나눗셈의 관계",
    keywords: ["곱셈", "나눗셈", "구구단", "몫", "나머지"],
  },
  {
    id: "e34-fractions",
    section: "1. 수와 연산",
    name: "② 분수",
    subtitle: "분수의 의미·크기 비교·분수의 덧셈과 뺄셈",
    keywords: ["분수", "분자", "분모", "약분", "통분"],
  },
  {
    id: "e34-circle",
    section: "2. 도형",
    name: "③ 원",
    subtitle: "원의 중심·반지름·지름",
    keywords: ["원", "반지름", "지름", "중심"],
  },
  {
    id: "e34-polygon",
    section: "2. 도형",
    name: "④ 여러 가지 도형",
    subtitle: "각·다각형·대칭",
    keywords: ["다각형", "각", "대칭", "평면도형"],
  },
  {
    id: "e34-measure",
    section: "3. 측정",
    name: "⑤ 들이와 무게·길이와 시간",
    subtitle: "들이·무게·길이·시간 단위",
    keywords: ["들이", "무게", "길이", "시간", "단위"],
  },
  {
    id: "e34-correspondence",
    section: "4. 규칙성",
    name: "⑥ 규칙과 대응",
    subtitle: "규칙 찾기·대응 관계",
    keywords: ["규칙", "대응", "함수", "관계"],
  },
  {
    id: "e34-data",
    section: "5. 자료와 가능성",
    name: "⑦ 자료의 정리",
    subtitle: "표·그림그래프·막대그래프",
    keywords: ["자료", "표", "그래프", "막대그래프", "꺾은선"],
  },
];

const E56_UNITS: CurriculumUnit[] = [
  {
    id: "e56-mixed",
    section: "1. 수와 연산",
    name: "① 자연수의 혼합 계산",
    subtitle: "덧셈·뺄셈·곱셈·나눗셈 혼합",
    keywords: ["혼합 계산", "연산", "괄호", "순서"],
  },
  {
    id: "e56-factor",
    section: "1. 수와 연산",
    name: "② 약수와 배수",
    subtitle: "약수·배수·공약수·공배수",
    keywords: ["약수", "배수", "공약수", "공배수", "최대공약", "최소공배"],
  },
  {
    id: "e56-fraction-decimal",
    section: "1. 수와 연산",
    name: "③ 분수와 소수",
    subtitle: "분수·소수 연산·관계",
    keywords: ["분수", "소수", "분수 연산", "소수 연산"],
  },
  {
    id: "e56-ratio",
    section: "1. 수와 연산",
    name: "④ 비와 비율",
    subtitle: "비·비율·백분율",
    keywords: ["비", "비율", "백분율", "비례"],
  },
  {
    id: "e56-proportion",
    section: "4. 규칙성",
    name: "⑤ 정비례와 반비례",
    subtitle: "정비례·반비례 관계",
    keywords: ["정비례", "반비례", "비례식", "비례"],
  },
  {
    id: "e56-area",
    section: "2. 도형",
    name: "⑥ 다각형의 넓이·원의 넓이",
    subtitle: "직사각형·삼각형·평행사변형·원",
    keywords: ["넓이", "다각형", "원의 넓이", "삼각형", "평행사변형"],
  },
  {
    id: "e56-solid",
    section: "2. 도형",
    name: "⑦ 입체도형",
    subtitle: "각기둥·각뿔·원기둥·원뿔·부피·겉넓이",
    keywords: ["입체", "부피", "겉넓이", "원기둥", "각기둥", "각뿔"],
  },
  {
    id: "e56-stats",
    section: "5. 자료와 가능성",
    name: "⑧ 평균과 가능성",
    subtitle: "평균·가능성·경우의 수",
    keywords: ["평균", "가능성", "경우의 수", "확률"],
  },
];

const M1_UNITS: CurriculumUnit[] = [
  {
    id: "m1-factor",
    section: "Ⅰ. 수와 연산",
    name: "① 소인수분해",
    subtitle: "소수·합성수·소인수분해·최대공약수·최소공배수",
    keywords: ["소인수", "소인수분해", "약수", "최대공약", "최소공배", "합성수"],
  },
  {
    id: "m1-integers",
    section: "Ⅰ. 수와 연산",
    name: "② 정수와 유리수",
    subtitle: "양수·음수·절댓값·유리수의 사칙연산",
    keywords: ["정수", "유리수", "절댓값", "음수", "양수", "사칙연산"],
  },
  {
    id: "m1-expressions",
    section: "Ⅱ. 문자와 식",
    name: "③ 문자의 사용과 식",
    subtitle: "문자 사용·식의 값·일차식 계산",
    keywords: ["문자", "일차식", "식", "다항식", "항", "계수"],
  },
  {
    id: "m1-equations",
    section: "Ⅱ. 문자와 식",
    name: "④ 일차방정식",
    subtitle: "방정식의 풀이·활용",
    keywords: ["일차방정식", "방정식", "이항", "미지수", "근"],
  },
  {
    id: "m1-coordinates",
    section: "Ⅲ. 좌표평면과 그래프",
    name: "⑤ 좌표평면과 그래프",
    subtitle: "순서쌍·좌표·좌표평면",
    keywords: ["좌표", "순서쌍", "좌표평면", "x축", "y축"],
  },
  {
    id: "m1-proportion-graph",
    section: "Ⅲ. 좌표평면과 그래프",
    name: "⑥ 정비례와 반비례",
    subtitle: "정비례·반비례 관계와 그래프",
    keywords: ["정비례", "반비례", "그래프", "비례"],
  },
  {
    id: "m1-basic-shapes",
    section: "Ⅳ. 기본 도형",
    name: "⑦ 기본 도형",
    subtitle: "점·선·면·각·위치 관계",
    keywords: ["점", "선", "면", "각", "평행", "수직", "기본 도형"],
  },
  {
    id: "m1-plane-shapes",
    section: "Ⅴ. 평면도형",
    name: "⑧ 평면도형",
    subtitle: "삼각형·사각형·원·다각형",
    keywords: ["삼각형", "사각형", "원", "다각형", "평면도형", "합동"],
  },
  {
    id: "m1-statistics",
    section: "Ⅵ. 통계",
    name: "⑨ 자료의 정리와 해석",
    subtitle: "도수분포표·히스토그램·줄기-잎 그림",
    keywords: ["통계", "자료", "도수", "히스토그램", "줄기", "평균"],
  },
];

const M2_UNITS: CurriculumUnit[] = [
  {
    id: "m2-rational",
    section: "Ⅰ. 수와 식",
    name: "① 유리수와 순환소수",
    subtitle: "유리수·순환소수·유리수와 순환소수의 관계",
    keywords: ["유리수", "순환소수", "무한소수", "분수"],
  },
  {
    id: "m2-systems",
    section: "Ⅰ. 수와 식",
    name: "② 연립일차방정식",
    subtitle: "가감법·대입법·연립방정식의 활용",
    keywords: ["연립", "일차방정식", "대입", "가감", "연립방정식"],
  },
  {
    id: "m2-functions",
    section: "Ⅱ. 함수",
    name: "③ 일차함수",
    subtitle: "일차함수의 그래프·기울기·절편·활용",
    keywords: ["일차함수", "기울기", "함수", "그래프", "절편", "y=ax+b"],
  },
  {
    id: "m2-shape-properties",
    section: "Ⅲ. 도형",
    name: "④ 도형의 성질",
    subtitle: "삼각형·사각형의 성질",
    keywords: ["삼각형", "사각형", "이등변", "직각", "평행사변형", "도형의 성질"],
  },
  {
    id: "m2-similarity",
    section: "Ⅲ. 도형",
    name: "⑤ 도형의 닮음",
    subtitle: "닮음·닮음비·닮음의 활용",
    keywords: ["닮음", "닮음비", "닮은 도형", "축척"],
  },
  {
    id: "m2-probability",
    section: "Ⅳ. 확률",
    name: "⑥ 확률",
    subtitle: "경우의 수·확률",
    keywords: ["확률", "경우의 수", "가능성"],
  },
];

const M3_UNITS: CurriculumUnit[] = [
  {
    id: "m3-sqrt",
    section: "Ⅰ. 실수와 그 계산",
    name: "① 제곱근과 실수",
    subtitle: "제곱근·근호·실수·수직선",
    keywords: ["제곱근", "근호", "실수", "무리수", "√"],
  },
  {
    id: "m3-factorization",
    section: "Ⅱ. 다항식",
    name: "② 다항식의 곱셈과 인수분해",
    subtitle: "곱셈공식·인수분해",
    keywords: ["인수분해", "곱셈공식", "다항식", "완전제곱"],
  },
  {
    id: "m3-quadratic-eq",
    section: "Ⅲ. 방정식",
    name: "③ 이차방정식",
    subtitle: "인수분해·제곱근·근의 공식",
    keywords: ["이차방정식", "근의 공식", "인수분해", "판별식"],
  },
  {
    id: "m3-quadratic-fn",
    section: "Ⅳ. 함수",
    name: "④ 이차함수",
    subtitle: "그래프·꼭짓점·최댓값·최솟값",
    keywords: ["이차함수", "포물선", "꼭짓점", "최솟값", "최댓값", "완전제곱식"],
  },
  {
    id: "m3-trig",
    section: "Ⅴ. 삼각비",
    name: "⑤ 삼각비",
    subtitle: "sin·cos·tan·삼각비의 활용",
    keywords: ["삼각비", "sin", "cos", "tan", "사인", "코사인", "탄젠트"],
  },
  {
    id: "m3-statistics",
    section: "Ⅵ. 통계",
    name: "⑥ 통계",
    subtitle: "산포도·상관관계",
    keywords: ["통계", "산포도", "상관", "분산", "표준편차"],
  },
];

const H1_UNITS: CurriculumUnit[] = [
  {
    id: "h1-polynomial",
    section: "공통수학Ⅰ",
    name: "① 다항식",
    subtitle: "다항식의 연산·나머지정리·인수분해",
    keywords: ["다항식", "인수분해", "나머지", "나머지정리", "조립제법"],
  },
  {
    id: "h1-equations",
    section: "공통수학Ⅰ",
    name: "② 방정식과 부등식",
    subtitle: "복이차·연립·이차부등식",
    keywords: ["방정식", "부등식", "연립", "복이차", "이차부등식"],
  },
  {
    id: "h1-combinatorics",
    section: "공통수학Ⅰ",
    name: "③ 경우의 수",
    subtitle: "합의 법칙·곱의 법칙·순열·조합",
    keywords: ["경우의 수", "순열", "조합", "합의 법칙", "곱의 법칙"],
  },
  {
    id: "h1-matrix",
    section: "공통수학Ⅰ",
    name: "④ 행렬",
    subtitle: "행렬의 연산·역행렬",
    keywords: ["행렬", "역행렬", "행렬식"],
  },
  {
    id: "h1-rational-fn",
    section: "공통수학Ⅱ",
    name: "⑤ 유리함수",
    subtitle: "유리함수의 그래프·점근선",
    keywords: ["유리함수", "점근선", "분수함수"],
  },
  {
    id: "h1-irrational-fn",
    section: "공통수학Ⅱ",
    name: "⑥ 무리함수",
    subtitle: "무리함수의 그래프",
    keywords: ["무리함수", "근호", "√"],
  },
  {
    id: "h1-exp-log",
    section: "공통수학Ⅱ",
    name: "⑦ 지수함수와 로그함수",
    subtitle: "지수·로그·지수방정식·로그방정식",
    keywords: ["지수", "로그", "지수함수", "로그함수", "log"],
  },
  {
    id: "h1-trig-fn",
    section: "공통수학Ⅱ",
    name: "⑧ 삼각함수",
    subtitle: "삼각함수의 그래프·주기",
    keywords: ["삼각함수", "sin", "cos", "tan", "주기", "라디안"],
  },
  {
    id: "h1-sequences",
    section: "공통수학Ⅱ",
    name: "⑨ 수열",
    subtitle: "등차·등비·수열의 합",
    keywords: ["수열", "등차", "등비", "공차", "공비", "급수"],
  },
];

const H2_UNITS: CurriculumUnit[] = [
  {
    id: "h2-exp-log",
    section: "수학Ⅰ",
    name: "① 지수함수와 로그함수",
    subtitle: "지수·로그의 성질·그래프·방정식",
    keywords: ["지수함수", "로그함수", "지수", "로그"],
  },
  {
    id: "h2-trig",
    section: "수학Ⅰ",
    name: "② 삼각함수",
    subtitle: "삼각함수의 정의·그래프·공식",
    keywords: ["삼각함수", "sin", "cos", "tan", "사인법칙", "코사인법칙"],
  },
  {
    id: "h2-sequences",
    section: "수학Ⅰ",
    name: "③ 수열",
    subtitle: "등차·등비·수학적 귀납법",
    keywords: ["수열", "등차", "등비", "귀납법", "수학적 귀납"],
  },
  {
    id: "h2-limit",
    section: "수학Ⅱ",
    name: "④ 함수의 극한과 연속",
    subtitle: "극한·좌극한·우극한·연속",
    keywords: ["극한", "연속", "좌극한", "우극한", "lim"],
  },
  {
    id: "h2-diff",
    section: "수학Ⅱ",
    name: "⑤ 미분",
    subtitle: "도함수·미분법·접선·극값",
    keywords: ["미분", "도함수", "접선", "극값", "변곡점"],
  },
  {
    id: "h2-integral",
    section: "수학Ⅱ",
    name: "⑥ 적분",
    subtitle: "부정적분·정적분·넓이",
    keywords: ["적분", "부정적분", "정적분", "넓이"],
  },
];

const H3_UNITS: CurriculumUnit[] = [
  {
    id: "h3-probability",
    section: "확률과 통계",
    name: "① 확률",
    subtitle: "조건부 확률·독립·베이즈",
    keywords: ["확률", "조건부", "독립", "베이즈"],
  },
  {
    id: "h3-statistics",
    section: "확률과 통계",
    name: "② 통계",
    subtitle: "확률분포·추정·검정",
    keywords: ["통계", "확률분포", "정규분포", "추정", "검정"],
  },
  {
    id: "h3-calc-limit",
    section: "미적분",
    name: "③ 수열의 극한",
    subtitle: "수열의 극한·급수",
    keywords: ["수열", "극한", "급수", "발산", "수렴"],
  },
  {
    id: "h3-calc-diff",
    section: "미적분",
    name: "④ 미분법",
    subtitle: "여러 가지 미분·도함수 활용",
    keywords: ["미분", "도함수", "연쇄", "음함수", "매개변수"],
  },
  {
    id: "h3-calc-integral",
    section: "미적분",
    name: "⑤ 적분법",
    subtitle: "치환·부분적분·정적분 활용",
    keywords: ["적분", "치환적분", "부분적분", "정적분"],
  },
  {
    id: "h3-conic",
    section: "기하",
    name: "⑥ 이차곡선",
    subtitle: "포물선·타원·쌍곡선",
    keywords: ["이차곡선", "포물선", "타원", "쌍곡선", "초점"],
  },
  {
    id: "h3-space",
    section: "기하",
    name: "⑦ 공간도형",
    subtitle: "직선과 평면·다면체",
    keywords: ["공간", "직선", "평면", "다면체", "정사면체"],
  },
  {
    id: "h3-vector",
    section: "기하",
    name: "⑧ 벡터",
    subtitle: "벡터의 연산·내적·외적",
    keywords: ["벡터", "내적", "외적", "스칼라"],
  },
];

const UNITS_BY_BAND: Record<GradeBand, CurriculumUnit[]> = {
  e12: E12_UNITS,
  e34: E34_UNITS,
  e56: E56_UNITS,
  m1: M1_UNITS,
  m2: M2_UNITS,
  m3: M3_UNITS,
  h1: H1_UNITS,
  h2: H2_UNITS,
  h3: H3_UNITS,
};

/** 학년대별 전체 목차 (API·UI에서 참조) */
export const CURRICULUM_TABLE_OF_CONTENTS: Record<GradeBand, CurriculumUnit[]> =
  UNITS_BY_BAND;

export function gradeToBand(grade?: string | null): GradeBand {
  const g = grade?.trim() ?? "중1";
  if (g.startsWith("대학")) return "h3";
  if (g.startsWith("초1") || g.startsWith("초2")) return "e12";
  if (g.startsWith("초3") || g.startsWith("초4")) return "e34";
  if (g.startsWith("초5") || g.startsWith("초6")) return "e56";
  if (g.startsWith("중2")) return "m2";
  if (g.startsWith("중3")) return "m3";
  if (g.startsWith("고1")) return "h1";
  if (g.startsWith("고2")) return "h2";
  if (g.startsWith("고3")) return "h3";
  return "m1";
}

export type SchoolLevel = "elementary" | "middle" | "high";

export function schoolLevelFromGrade(grade?: string | null): SchoolLevel {
  const g = grade?.trim() ?? "중1";
  if (g.startsWith("대학") || g.startsWith("고")) return "high";
  if (g.startsWith("초")) return "elementary";
  return "middle";
}

/** 튜터·오답 해설 프롬프트용 학년 맥락 */
export function tutorGradeContext(grade?: string | null): {
  gradeLabel: string;
  schoolLevel: SchoolLevel;
  promptBlock: string;
} {
  const trimmed = grade?.trim();
  const gradeLabel = trimmed && trimmed.length > 0
    ? trimmed
    : GRADE_BAND_LABELS[gradeToBand(grade)];
  const schoolLevel = schoolLevelFromGrade(grade);
  const levelKo =
    schoolLevel === "elementary"
      ? "초등"
      : schoolLevel === "middle"
        ? "중등"
        : "고등";

  const styleGuide =
    schoolLevel === "elementary"
      ? "Use short, friendly Korean sentences. Avoid advanced jargon and high-school-only notation unless the problem already uses it. Prefer concrete numbers and step-by-step intuition."
      : schoolLevel === "middle"
        ? "Use standard Korean middle-school (중학교) math vocabulary and clear step-by-step reasoning."
        : "Use precise Korean high-school math terminology with concise, rigorous reasoning.";

  return {
    gradeLabel,
    schoolLevel,
    promptBlock: `Student grade: ${gradeLabel} (${levelKo}).
Tailor errorSummary and all tutor prose to this level.
${styleGuide}`,
  };
}

export function unitsForGrade(grade?: string | null): CurriculumUnit[] {
  const band = gradeToBand(grade);
  return UNITS_BY_BAND[band] ?? [];
}

export function bandForGradeTabIndex(index: number): GradeBand {
  return GRADE_BAND_ORDER[index] ?? "m1";
}

export function findCurriculumUnit(
  unitId: string,
): { unit: CurriculumUnit; gradeBand: GradeBand } | null {
  const normalized = unitId.trim();
  if (!normalized) return null;
  for (const band of GRADE_BAND_ORDER) {
    const unit = UNITS_BY_BAND[band].find((u) => u.id === normalized);
    if (unit) return { unit, gradeBand: band };
  }
  return null;
}

export function listCurriculumUnits(params?: {
  gradeBand?: GradeBand;
}): { unit: CurriculumUnit; gradeBand: GradeBand }[] {
  const bands = params?.gradeBand ? [params.gradeBand] : GRADE_BAND_ORDER;
  return bands.flatMap((band) =>
    UNITS_BY_BAND[band].map((unit) => ({ unit, gradeBand: band })),
  );
}

export function matchUnitForConcept(
  concept: string,
  grade?: string | null,
): CurriculumUnit | null {
  const normalized = concept.toLowerCase();
  for (const unit of unitsForGrade(grade)) {
    if (unit.keywords.some((kw) => normalized.includes(kw.toLowerCase()))) {
      return unit;
    }
    if (
      normalized.includes(unit.name.replace(/[①-⑨\d.\s]/g, "").toLowerCase()) ||
      normalized.includes(unit.subtitle.toLowerCase())
    ) {
      return unit;
    }
  }
  return null;
}
