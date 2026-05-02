import { MongoClient, type Db } from "mongodb";
import { env, hasMongoConfig } from "./env";

const globalForMongo = globalThis as typeof globalThis & {
  mongoClientPromise?: Promise<MongoClient>;
};

export async function getMongoDb(): Promise<Db | null> {
  if (!hasMongoConfig() || !env.mongodbUri) {
    return null;
  }

  if (!globalForMongo.mongoClientPromise) {
    const client = new MongoClient(env.mongodbUri);
    globalForMongo.mongoClientPromise = client.connect();
  }

  const client = await globalForMongo.mongoClientPromise;
  return client.db(env.mongodbDbName);
}
