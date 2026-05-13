/**
 * 한국 Cognitive Services 계정(TestAzResourceAi)의 GPT-5 배포에 대해
 * Chat Completions: (1) 텍스트만 JSON (2) image_url 포함 멀티모달
 * 을 호출하고 성공 여부만 출력합니다.
 *
 * 실행: node scripts/smoke-gpt5-vision-kr.mjs
 *
 * 엔드포인트·키는 `az` CLI 로 읽습니다(로그인 필요). 키는 출력하지 않습니다.
 */
import { execSync } from "node:child_process";

const RG = process.env.AZ_RG ?? "test-az-sb-1";
const ACCOUNT = process.env.AZ_AI_ACCOUNT ?? "TestAzResourceAi";
const DEPLOYMENT = process.env.AZ_EXP_DEPLOYMENT ?? "exp-kr-gpt-5";
const API_VERSION = process.env.AZ_OPENAI_API_VERSION ?? "2024-08-01-preview";

const ONE_PX_PNG =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

function az(args) {
  return execSync(`az ${args}`, { encoding: "utf8" }).trim();
}

function run() {
  const endpoint = az(
    `cognitiveservices account show -n "${ACCOUNT}" -g "${RG}" --query properties.endpoint -o tsv`,
  ).replace(/\/$/, "");
  const key = az(
    `cognitiveservices account keys list -n "${ACCOUNT}" -g "${RG}" --query key1 -o tsv`,
  );
  const chatUrl = `${endpoint}/openai/deployments/${encodeURIComponent(DEPLOYMENT)}/chat/completions?api-version=${encodeURIComponent(API_VERSION)}`;

  async function post(body) {
    const res = await fetch(chatUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "api-key": key,
      },
      body: JSON.stringify(body),
    });
    const text = await res.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      data = { raw: text.slice(0, 400) };
    }
    return { ok: res.ok, status: res.status, data };
  }

  return { endpoint, post };
}

async function main() {
  console.log(`Account=${ACCOUNT} deployment=${DEPLOYMENT} api-version=${API_VERSION}`);
  const { endpoint, post } = run();
  console.log(`Endpoint host: ${new URL(endpoint).host}`);

  // ① 텍스트 전용 + json_object (비전 호출에는 쓰이지 않지만 배포 상태 확인용)
  const textOnly = await post({
    messages: [
      {
        role: "user",
        content: 'Reply JSON only: {"hello":"gpt5"}',
      },
    ],
    max_completion_tokens: 256,
    response_format: { type: "json_object" },
  });
  console.log(
    `\n[1] text+json_object → ${textOnly.ok ? "OK" : "FAIL"} ${textOnly.status}`,
  );
  if (!textOnly.ok) {
    console.log(JSON.stringify(textOnly.data?.error ?? textOnly.data).slice(0, 900));
    process.exitCode = 1;
  } else {
    const c = textOnly.data?.choices?.[0]?.message?.content ?? "";
    console.log("snippet:", String(c).slice(0, 200));
  }

  // ② 멀티모달 (analyzeSolutionImage 와 같은 형태: image URL + 텍스트, response_format 없음)
  const dataUrl = `data:image/png;base64,${ONE_PX_PNG}`;
  const vision = await post({
    messages: [
      {
        role: "user",
        content: [
          {
            type: "text",
            text: "This is a minimal test image. Reply with JSON only: {\"sees\":\"image\",\"color\":\"guess\"}",
          },
          { type: "image_url", image_url: { url: dataUrl } },
        ],
      },
    ],
    max_completion_tokens: 512,
  });
  console.log(
    `\n[2] vision (image_url) → ${vision.ok ? "OK" : "FAIL"} ${vision.status}`,
  );
  if (!vision.ok) {
    console.log(JSON.stringify(vision.data?.error ?? vision.data).slice(0, 900));
    process.exitCode = 1;
  } else {
    const c = vision.data?.choices?.[0]?.message?.content ?? "";
    console.log("snippet:", String(c).slice(0, 400));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
