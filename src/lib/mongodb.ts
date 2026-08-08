import { MongoClient, type Db } from "mongodb";
import { getActiveDbVariant } from "./db-variant";
import { env, hasMongoConfig } from "./env";

const globalForMongo = globalThis as typeof globalThis & {
  mongoClient?: MongoClient;
  mongoClientPromise?: Promise<MongoClient>;
  mongoShutdownHooksRegistered?: boolean;
  mongoClosingPromise?: Promise<void>;
};

function resolveDbName(): string {
  return getActiveDbVariant() === "lite"
    ? env.mongodbDbNameLite
    : env.mongodbDbName;
}

export async function getMongoDb(): Promise<Db | null> {
  if (!hasMongoConfig() || !env.mongodbUri) {
    return null;
  }

  if (!globalForMongo.mongoClientPromise) {
    const client = new MongoClient(env.mongodbUri, {
      serverSelectionTimeoutMS: 8_000,
      maxIdleTimeMS: 60_000,
      minPoolSize: 1,
      maxPoolSize: 10,
    });
    globalForMongo.mongoClient = client;
    globalForMongo.mongoClientPromise = client
      .connect()
      .then((connected) => {
        globalForMongo.mongoClient = connected;
        return connected;
      })
      .catch((error) => {
        globalForMongo.mongoClient = undefined;
        globalForMongo.mongoClientPromise = undefined;
        throw error;
      });
  }

  const client = await globalForMongo.mongoClientPromise;
  return client.db(resolveDbName());
}

/**
 * MongoDB 클라이언트(커넥션 풀)를 안전하게 종료한다.
 * 서버 종료·워커 중지·스크립트 끝에서 호출한다.
 */
export async function closeMongoClient(): Promise<void> {
  if (globalForMongo.mongoClosingPromise) {
    return globalForMongo.mongoClosingPromise;
  }

  const client = globalForMongo.mongoClient;
  const pending = globalForMongo.mongoClientPromise;
  globalForMongo.mongoClient = undefined;
  globalForMongo.mongoClientPromise = undefined;

  if (!client && !pending) {
    return;
  }

  globalForMongo.mongoClosingPromise = (async () => {
    try {
      const resolved = client ?? (pending ? await pending : null);
      if (resolved) {
        await resolved.close();
      }
    } finally {
      globalForMongo.mongoClosingPromise = undefined;
    }
  })();

  return globalForMongo.mongoClosingPromise;
}

export type MongoShutdownHookOptions = {
  /**
   * true(기본): close 후 process.exit.
   * false: 커넥션만 닫고 종료는 런타임(Next 등)에 맡긴다.
   *        단 SIGINT/SIGTERM 리스너가 있으면 Node 기본 종료가 막히므로
   *        Next 등에서 자체 종료하지 않으면 프로세스가 남을 수 있다.
   */
  exitAfterClose?: boolean;
  /** 로그/부가 동작용 — close 직전에 호출 */
  onBeforeClose?: (signal: string) => void | Promise<void>;
};

/**
 * SIGINT / SIGTERM / beforeExit 에서 Mongo 커넥션을 닫도록 등록한다.
 * Next instrumentation·워커 진입점에서 한 번만 호출해도 안전하다.
 */
export function registerMongoShutdownHooks(
  options: MongoShutdownHookOptions = {},
): void {
  if (typeof process === "undefined") return;
  if (globalForMongo.mongoShutdownHooksRegistered) return;
  globalForMongo.mongoShutdownHooksRegistered = true;

  const exitAfterClose = options.exitAfterClose ?? true;
  let shuttingDown = false;

  const shutdown = async (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;

    try {
      await options.onBeforeClose?.(signal);
    } catch (error) {
      console.error("[mongo] onBeforeClose failed", error);
    }

    try {
      console.info(`[mongo] ${signal}: closing client…`);
      await closeMongoClient();
      console.info("[mongo] client closed");
    } catch (error) {
      console.error("[mongo] close failed", error);
    }

    if (exitAfterClose && signal !== "beforeExit") {
      // Node 기본(리스너 없을 때)과 같이 종료한다.
      const code = signal === "SIGINT" ? 130 : signal === "SIGTERM" ? 143 : 0;
      process.exit(code);
    }
  };

  process.once("SIGINT", () => {
    void shutdown("SIGINT");
  });
  process.once("SIGTERM", () => {
    void shutdown("SIGTERM");
  });
  process.once("beforeExit", () => {
    void shutdown("beforeExit");
  });
}
