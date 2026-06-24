import { AsyncLocalStorage } from "node:async_hooks";

import { getRequestAppVariant, type AppDbVariant } from "./request";

const storage = new AsyncLocalStorage<AppDbVariant>();

export function getActiveDbVariant(): AppDbVariant {
  return storage.getStore() ?? "full";
}

export async function withRequestDb<T>(
  request: Request,
  handler: () => Promise<T>,
): Promise<T> {
  return storage.run(getRequestAppVariant(request), handler);
}
