#!/usr/bin/env node
import { sanitizeFunctionGraphData } from "../src/lib/desmos-latex";

const samples = [
  { expression: "y=log_2(x-1)+log_2(x-3)", expressions: ["y=log_2(x-1)+log_2(x-3)", "y=3"] },
  {
    expression: "g(x) = \\frac{|x-1|}{x-1}",
    expressions: ["g(x) = \\frac{|x-1|}{x-1}", "\\lim_{x \\to 1^-} g(x) = -1"],
  },
  { expression: "y=(a*x+b)/(x+d)" },
  { expression: "x^2/1 - y^2/8 = 1", expressions: ["F_1 = (-3,0)", "F_2 = (3,0)"] },
];

for (const sample of samples) {
  console.log(JSON.stringify(sanitizeFunctionGraphData(sample), null, 2));
}
