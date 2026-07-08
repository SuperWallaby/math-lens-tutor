import { MongoClient, type Db } from "mongodb";
import { getActiveDbVariant } from "./db-variant";
import { env, hasMongoConfig } from "./env";

const globalForMongo = globalThis as typeof globalThis & {
  mongoClientPromise?: Promise<MongoClient>;
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
    globalForMongo.mongoClientPromise = client.connect();
  }

  const client = await globalForMongo.mongoClientPromise;
  return client.db(resolveDbName());
}
