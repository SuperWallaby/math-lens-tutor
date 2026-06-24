# visualization_data 스키마

문제·풀이에 그래프/도형을 붙이는 통합 필드입니다. 기존 `chart`·`jsxGraph`는 유지되며, 앱은 `visualizationData`를 우선 렌더링합니다.

## 공통 형태

```json
{
  "type": "function_graph | geometry | coordinate | chart",
  "engine": "desmos | jsxgraph | chartjs",
  "data": {}
}
```

시각화가 필요 없으면 `null`.

## function_graph (Desmos)

```json
{
  "type": "function_graph",
  "engine": "desmos",
  "data": {
    "expression": "y=x^2-4x+3",
    "xRange": [-5, 5],
    "yRange": [-5, 10],
    "captionKo": "포물선 그래프"
  }
}
```

## geometry (JSXGraph)

```json
{
  "type": "geometry",
  "engine": "jsxgraph",
  "data": {
    "shape": "triangle",
    "points": {
      "A": [0, 0],
      "B": [4, 0],
      "C": [2, 3]
    },
    "showLabels": true,
    "captionKo": "삼각형 ABC"
  }
}
```

## coordinate (JSXGraph 요소 배열)

```json
{
  "type": "coordinate",
  "engine": "jsxgraph",
  "data": {
    "board": { "boundingbox": [-2, 12, 14, -4], "axis": true },
    "elements": [
      { "elType": "point", "id": "P", "coord": [1, 3] }
    ]
  }
}
```

## chart (Chart.js — 통계 막대/선)

```json
{
  "type": "chart",
  "engine": "chartjs",
  "data": {
    "type": "bar",
    "data": { "labels": ["A", "B"], "datasets": [{ "data": [3, 5] }] }
  }
}
```

## 풀이용 필드

- `solutionVisualizationData`: 풀이 설명에 **추가** 그림이 필요할 때만 (문제 그림과 동일하면 `null`).

## 마이그레이션 상태 (`problem_bank_items`)

| 필드 | 값 |
|------|-----|
| `visualizationMigrationStatus` | `pending` \| `processing` \| `completed` \| `failed` |
| `visualizationMigrationError` | 실패 시 메시지 |

```bash
npm run migrate:visualization              # bank + sets 배치 20건
npm run migrate:visualization -- --all     # 남은 항목 전체 (bank + sets)
npm run migrate:visualization -- --target bank
npm run migrate:visualization -- --target sets
npm run migrate:visualization -- --only failed
npm run migrate:visualization -- --id <bank-item-id|set-id>
npm run migrate:visualization -- --dry-run
```

## Flutter 렌더링

- `VisualizationView` — engine/type에 따라 Desmos WebView / JSXGraph / fl_chart
- `QuestionView` — `MixedMathText` + `VisualizationView` + 풀이 블록

Desmos API 키(선택): `--dart-define=DESMOS_API_KEY=...`

## 신규 AI 생성

`azure.ts` 프롬프트에 `visualizationData`·`solutionVisualizationData` 포함.  
`sanitizeGeneratedProblem()`에서 legacy `chart`/`jsxGraph`를 자동 정규화합니다.
