/** 그래프/도형이 문제 풀이에 꼭 필요한지 판단하는 공통 기준 */

export const GRAPH_REQUIRED_CRITERION = `판단 기준 (가장 중요):
- needed=true / graphRequiredToSolve=true: **그림·그래프 없이는 이 문제를 합리적으로 풀 수 없을 때만**
  - 본문에 없는 시각 정보가 필요함 (좌표, 교점, 도형 배치, 그래프 모양을 읽어야 답이 나옴)
  - "다음 그림", "아래 그래프", "그림과 같이" 등 **제시된 도형을 보고** 풀도록 되어 있음
  - 점·선·원의 위치 관계를 글로만으로는 파악하기 어렵고, 도형을 봐야 함
- needed=false / graphRequiredToSolve=false: **글·식만으로 충분히 풀 수 있으면**
  - 방정식 풀기, 식 전개·인수분해, 값 대입, 공식 적용, 경우의 수·확률 계산, 통계량 계산
  - 함수/그래프 단원이어도 **식만 주어지고 계산으로 답이 나오면** 그래프 불필요
  - 그래프는 이해를 돕거나 장식용일 뿐, 없어도 풀이에 필요한 정보가 빠지지 않음
  - 도형 조건이 글과 기호로 이미 충분히 주어짐

주의: "그래프가 있으면 좋다", "시각화하면 이해가 된다"만으로는 true가 아님. **꼭 있어야 하는가**로 판단.`;

export const VISUALIZATION_GENERATION_PROMPT = `You analyze Korean math problems and decide whether a graph or geometry diagram is **required to solve** the problem.

Return JSON only:
{
  "needed": boolean,
  "visualizationData": null | {
    "type": "function_graph" | "geometry" | "coordinate",
    "engine": "desmos" | "jsxgraph",
    "data": {}
  },
  "solutionVisualizationData": null | { same shape as visualizationData },
  "reason": "short Korean explanation"
}

${GRAPH_REQUIRED_CRITERION}

Technical rules:
- function_graph + engine desmos: data.expression **required** (e.g. "y=2^x"). Optional data.expressions array. Optional xRange/yRange [-5,5] tuples
- geometry + engine jsxgraph: shape triangle|rectangle|circle|polygon|custom, points { "A": [x,y], ... }, showLabels
- coordinate + engine jsxgraph: board.boundingbox + elements array for JSXGraph
- If not required to solve, needed=false and both visualization fields null
- If you cannot produce valid expression/points, set needed=false (do not omit expression)
- solutionVisualizationData only when the **solution step** needs a **different** figure (auxiliary lines, completed construction). Not a repeat of the prompt figure.
- Prefer null over optional or decorative visuals`;

export const VISUALIZATION_AUDIT_PROMPT = `You audit whether an existing math problem **requires** a graph or geometry diagram to solve.

Read only the problem text (title, prompt, explanation, tags). Do NOT assume any figure exists. Ask: "Can a student solve this with the text and equations alone?"

Return JSON only:
{
  "graphRequiredToSolve": boolean,
  "reason": "short Korean explanation"
}

${GRAPH_REQUIRED_CRITERION}`;

export function buildVisualizationGenerationUserPrompt(params: {
  title: string;
  prompt: string;
  explanation: string;
  conceptTags: string[];
}): string {
  return `${VISUALIZATION_GENERATION_PROMPT}

Problem title: ${params.title}
Prompt: ${params.prompt}
Explanation: ${params.explanation}
Concept tags: ${params.conceptTags.join(", ")}`;
}

export function buildVisualizationAuditUserPrompt(params: {
  title: string;
  prompt: string;
  explanation: string;
  conceptTags: string[];
}): string {
  return `${VISUALIZATION_AUDIT_PROMPT}

Problem title: ${params.title}
Prompt: ${params.prompt}
Explanation: ${params.explanation}
Concept tags: ${params.conceptTags.join(", ")}`;
}
