"use client";

import {
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Legend,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
} from "chart.js";
import { Bar, Line } from "react-chartjs-2";
import type { GeneratedProblem } from "@/lib/types";

ChartJS.register(
  BarElement,
  CategoryScale,
  Legend,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
);

type ChartConfig = NonNullable<GeneratedProblem["chart"]>;

export function ChartRenderer({ chart }: { chart: ChartConfig }) {
  if (chart.type === "line" || chart.type === "scatter") {
    return <Line data={chart.data as never} options={chart.options as never} />;
  }

  return <Bar data={chart.data as never} options={chart.options as never} />;
}
