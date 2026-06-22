import { buildAppMagicDeepLink } from "@/lib/email";

import { MagicLinkRedirect } from "./MagicLinkRedirect";

type PageProps = {
  searchParams: Promise<{ token?: string }>;
};

export default async function MagicLinkPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const token = params.token?.trim() ?? "";
  const appLink = token ? buildAppMagicDeepLink(token) : "";

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: 24,
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        background: "#f5f5f5",
        color: "#1a1a2e",
      }}
    >
      <div
        style={{
          width: "100%",
          maxWidth: 420,
          background: "#fff",
          borderRadius: 16,
          padding: 28,
          boxShadow: "0 8px 32px rgba(0,0,0,0.08)",
        }}
      >
        <h1 style={{ margin: "0 0 8px", fontSize: 24 }}>우열 로그인</h1>
        {token ? (
          <>
            <p style={{ margin: "0 0 20px", lineHeight: 1.6, color: "#5a6278" }}>
              아래 버튼을 눌러 앱에서 로그인을 완료해 주세요.
            </p>
            <MagicLinkRedirect appLink={appLink} />
            <a
              href={appLink}
              style={{
                display: "inline-block",
                background: "#007BFF",
                color: "#fff",
                textDecoration: "none",
                padding: "12px 20px",
                borderRadius: 12,
                fontWeight: 700,
              }}
            >
              앱에서 로그인하기
            </a>
            <MagicLinkRedirect appLink={appLink} />
            <p style={{ margin: "16px 0 0", fontSize: 13, color: "#949bb0" }}>
              앱이 자동으로 열리지 않으면 우열 앱을 연 뒤 다시 링크를 눌러 주세요.
            </p>
          </>
        ) : (
          <p style={{ margin: 0, color: "#5a6278" }}>
            유효하지 않은 링크입니다. 이메일의 최신 링크를 사용해 주세요.
          </p>
        )}
      </div>
    </main>
  );
}
