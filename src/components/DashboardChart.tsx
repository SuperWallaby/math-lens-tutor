"use client";

import { ChartRenderer } from "./ChartRenderer";
import type { LearningInsight } from "@/lib/types";

export function DashboardChart({
  chart,
}: {
  chart: LearningInsight["trendChart"];
}) {
  return <ChartRenderer chart={chart} />;
}
