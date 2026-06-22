import {
  hasMagicLinkEmailConfig,
  resolveAppPublicUrl,
  env,
} from "./env";

export function buildMagicLinkUrl(rawToken: string, requestOrigin?: string): string {
  const base = resolveAppPublicUrl(requestOrigin);
  return `${base}/auth/magic?token=${encodeURIComponent(rawToken)}`;
}

export function buildAppMagicDeepLink(rawToken: string): string {
  return `wooyeol://auth/magic?token=${encodeURIComponent(rawToken)}`;
}

export async function sendMagicLinkEmail(options: {
  email: string;
  rawToken: string;
  requestOrigin?: string;
}): Promise<{ delivered: boolean; devLink?: string }> {
  const link = buildMagicLinkUrl(options.rawToken, options.requestOrigin);
  const appLink = buildAppMagicDeepLink(options.rawToken);

  if (!hasMagicLinkEmailConfig()) {
    console.info("[magic-link] dev mode — email not configured");
    console.info(`[magic-link] to=${options.email}`);
    console.info(`[magic-link] url=${link}`);
    console.info(`[magic-link] app=${appLink}`);
    return { delivered: false, devLink: link };
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: env.magicLinkFromEmail,
      to: options.email,
      subject: "우열 로그인 링크",
      html: `
        <div style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;line-height:1.6;color:#1a1a2e;max-width:480px">
          <h2 style="margin:0 0 12px">우열 로그인</h2>
          <p style="margin:0 0 16px">아래 버튼을 눌러 로그인을 완료해 주세요. 링크는 15분 동안만 유효합니다.</p>
          <p style="margin:0 0 24px">
            <a href="${link}" style="display:inline-block;background:#007BFF;color:#fff;text-decoration:none;padding:12px 20px;border-radius:12px;font-weight:700">로그인하기</a>
          </p>
          <p style="margin:0;color:#5a6278;font-size:13px">앱이 설치되어 있다면 링크를 누른 뒤 <strong>앱에서 열기</strong>를 선택해 주세요.</p>
          <p style="margin:16px 0 0;color:#949bb0;font-size:12px">요청하지 않으셨다면 이 메일을 무시하셔도 됩니다.</p>
        </div>
      `,
    }),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(
      detail.trim() || `이메일 발송에 실패했습니다. (${response.status})`,
    );
  }

  return { delivered: true };
}
