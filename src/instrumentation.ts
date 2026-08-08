/**
 * Next.js 서버(Node) 기동 시 한 번 실행 — Mongo 커넥션을
 * SIGINT/SIGTERM/beforeExit 때 안전하게 닫는다.
 *
 * Edge 런타임에서는 Mongo 드라이버를 쓰지 않으므로 스킵.
 */
export async function register() {
  if (process.env.NEXT_RUNTIME === "edge") {
    return;
  }

  const { registerMongoShutdownHooks } = await import("./lib/mongodb");
  // Next가 자체 종료 흐름을 갖고 있어도, 시그널 리스너를 붙이면
  // 기본 종료가 막히므로 close 후 exit 한다.
  registerMongoShutdownHooks({ exitAfterClose: true });
}
