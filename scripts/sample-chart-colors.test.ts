// 샘플 차트 색이 앱 파랑(#2A72E5)을 따르는지 확인한다.
// 실행: node --import tsx --test scripts/sample-chart-colors.test.ts
import assert from "node:assert/strict";
import test from "node:test";

import { sampleProblemSet } from "../src/lib/sample";

type Dataset = { borderColor?: unknown; backgroundColor?: unknown };

/** 샘플 안의 모든 차트 데이터셋(borderColor가 있는 객체)을 모은다. */
function datasets(value: unknown, found: Dataset[] = []): Dataset[] {
  if (Array.isArray(value)) {
    for (const item of value) datasets(item, found);
  } else if (value && typeof value === "object") {
    if ("borderColor" in value) found.push(value as Dataset);
    for (const child of Object.values(value)) datasets(child, found);
  }
  return found;
}

function hexToRgb(hex: string): [number, number, number] {
  const n = Number.parseInt(hex.replace("#", ""), 16);
  return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];
}

test("sample chart fill is the line color at 12%, not Bootstrap blue", () => {
  const all = datasets(sampleProblemSet);
  assert.ok(all.length > 0, "the sample has at least one chart");
  for (const d of all) {
    assert.equal(typeof d.borderColor, "string");
    const [r, g, b] = hexToRgb(d.borderColor as string);
    assert.equal(d.backgroundColor, `rgba(${r}, ${g}, ${b}, 0.12)`);
  }
  assert.ok(!JSON.stringify(sampleProblemSet).includes("0, 123, 255"));
});
