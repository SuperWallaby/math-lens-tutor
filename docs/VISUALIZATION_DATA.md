# visualization_data 스키마

문제·풀이에 그래프/도형을 붙이는 통합 필드입니다. 앱은 **bake된 정적 PNG**(`imageUrl`)만 표시합니다.

## 공통 형태 (bake 후)

```json
{
  "type": "function_graph | geometry | coordinate | chart",
  "engine": "static",
  "data": {
    "imageUrl": "/viz/abc123.png",
    "width": 800,
    "height": 400,
    "contentHash": "abc123..."
  }
}
```

시각화가 필요 없으면 `null`. `imageUrl` 없으면 클라이언트에서 그래프를 표시하지 않습니다.

## function_graph

AI 생성 시 `engine: desmos` + `expression` 등으로 들어오고, 마이그레이션/bake 단계에서 `static` + PNG로 변환됩니다.

```json
{
  "type": "function_graph",
  "engine": "static",
  "data": {
    "expression": "y=\\sin\\left(3x\\right)",
    "xRange": [-6.28, 6.28],
    "yRange": [-1.2, 1.2],
    "imageUrl": "/viz/abc123.png",
    "width": 800,
    "height": 400,
    "captionKo": "사인 그래프"
  }
}
```

## geometry / coordinate / chart

동일하게 bake 후 `engine: static` + `imageUrl`. 원본 JSON(points, elements, chart data)은 재생성·디버그용으로 유지됩니다.

## 풀이용 필드

- `solutionVisualizationData`: 풀이 설명에 **추가** 그림이 필요할 때만 (문제 그림과 동일하면 `null`).

## 마이그레이션 · bake

| 필드 | 값 |
|------|-----|
| `visualizationMigrationStatus` | `pending` \| `processing` \| `completed` \| `failed` |
| `visualizationMigrationError` | 실패 시 메시지 |

```bash
npm run bake:viz -- --expression "y=sin(3x)"   # 단건 PNG 테스트
npm run migrate:visualization                  # bank + sets 배치 20건 (AI + bake)
npm run migrate:visualization -- --all
npm run migrate:visualization -- --rebake      # imageUrl 재생성
npm run migrate:visualization -- --skip-bake   # AI만 (bake 생략)
npm run migrate:visualization -- --target bank
npm run migrate:visualization -- --id <bank-item-id|set-id>
```

PNG 생성: Playwright + `public/viz-capture/` (Desmos / JSXGraph / Chart.js). 저장: R2 또는 `public/viz/` + `flutter_app/web/viz/`.

**자동 bake 시점**

- `ingestGeneratedProblems` / `saveProblemSet` — 저장 직후 **백그라운드** bake (응답은 즉시 반환)
- 클라이언트 — `imageUrl` 없으면 그래프 자리에 로딩 표시, 2초마다 problem set 재조회
- `migrate:visualization` — 기존 DB 일괄 변환 (`--rebake`로 전량 재생성)

## Flutter / Next 렌더링

- `VisualizationView` / `VisualizationRenderer` — `data.imageUrl`만 `Image` / `<img>`로 표시
- 런타임 Desmos / JSXGraph / Chart.js 없음

## 신규 AI 생성

`azure.ts` 프롬프트에 `visualizationData`·`solutionVisualizationData` 포함.  
생성 직후 `visualization-bake` 파이프라인에서 PNG로 변환됩니다.

`DESMOS_API_KEY` / `NEXT_PUBLIC_DESMOS_API_KEY` — **bake 스크립트 전용** (런타임 아님).
