import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

/**
 * Flutter Web 등 다른 localhost 포트에서 /api 호출 시 브라우저 CORS(preflight 포함).
 */
function corsHeadersFor(origin: string | null): Headers {
  const headers = new Headers();
  headers.set(
    "Access-Control-Allow-Methods",
    "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  );
  headers.set(
    "Access-Control-Allow-Headers",
    "Content-Type, X-Device-Id, Authorization",
  );
  headers.set("Access-Control-Max-Age", "86400");

  if (!origin) {
    headers.set("Access-Control-Allow-Origin", "*");
    return headers;
  }

  try {
    const { hostname } = new URL(origin);
    const local =
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "::1";
    if (local) {
      headers.set("Access-Control-Allow-Origin", origin);
      headers.set("Vary", "Origin");
    } else if (process.env.NODE_ENV !== "production") {
      headers.set("Access-Control-Allow-Origin", origin);
      headers.set("Vary", "Origin");
    } else {
      const allowed = (process.env.CORS_ORIGIN ?? "")
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      if (allowed.includes(origin)) {
        headers.set("Access-Control-Allow-Origin", origin);
        headers.set("Vary", "Origin");
      }
    }
  } catch {
    headers.set("Access-Control-Allow-Origin", "*");
  }

  return headers;
}

export function middleware(request: NextRequest) {
  const origin = request.headers.get("origin");
  const h = corsHeadersFor(origin);

  if (request.method === "OPTIONS") {
    return new NextResponse(null, { status: 204, headers: h });
  }

  const res = NextResponse.next();
  h.forEach((value, key) => {
    res.headers.set(key, value);
  });
  return res;
}

export const config = {
  matcher: "/api/:path*",
};
