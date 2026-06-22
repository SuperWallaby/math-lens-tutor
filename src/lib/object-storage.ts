import {
  DeleteObjectsCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";

export type StoredImageKind = "solution" | "profile" | "quiz";

const DEFAULT_BUCKET = "neo-study-uploads";

function requiredEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} 환경 변수가 필요합니다.`);
  }
  return value;
}

export function r2BucketName(): string {
  return process.env.R2_BUCKET_NAME?.trim() || DEFAULT_BUCKET;
}

export function isR2Configured(): boolean {
  return Boolean(
    process.env.R2_ACCOUNT_ID?.trim() &&
      process.env.R2_ACCESS_KEY_ID?.trim() &&
      process.env.R2_SECRET_ACCESS_KEY?.trim(),
  );
}

function getR2Client(): S3Client {
  const accountId = requiredEnv("R2_ACCOUNT_ID");
  return new S3Client({
    region: "auto",
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: requiredEnv("R2_ACCESS_KEY_ID"),
      secretAccessKey: requiredEnv("R2_SECRET_ACCESS_KEY"),
    },
  });
}

export function buildR2ObjectKey(
  userId: string,
  kind: StoredImageKind,
  imageId: string,
  mimeType: string,
): string {
  const ext = extensionFromMimeType(mimeType);
  return `${userId}/${kind}/${imageId}${ext}`;
}

export function buildQuizR2Key(quizId: string): string {
  return `system/quiz/${quizId}.webp`;
}

export function publicUrlForR2Key(key: string): string | null {
  const base = process.env.R2_PUBLIC_BASE_URL?.trim().replace(/\/$/, "");
  if (!base) return null;
  return `${base}/${key}`;
}

export async function uploadToR2(options: {
  key: string;
  body: Buffer;
  contentType: string;
  cacheControl?: string;
}): Promise<void> {
  const client = getR2Client();
  await client.send(
    new PutObjectCommand({
      Bucket: r2BucketName(),
      Key: options.key,
      Body: options.body,
      ContentType: options.contentType,
      ...(options.cacheControl
        ? { CacheControl: options.cacheControl }
        : {}),
    }),
  );
}

export async function getFromR2(
  key: string,
): Promise<{ body: Buffer; contentType: string } | null> {
  const client = getR2Client();
  try {
    const response = await client.send(
      new GetObjectCommand({
        Bucket: r2BucketName(),
        Key: key,
      }),
    );
    if (!response.Body) return null;
    const bytes = Buffer.from(await response.Body.transformToByteArray());
    return {
      body: bytes,
      contentType: response.ContentType || "application/octet-stream",
    };
  } catch {
    return null;
  }
}

export async function deleteR2ObjectsWithPrefix(prefix: string): Promise<void> {
  const client = getR2Client();
  const bucket = r2BucketName();
  let continuationToken: string | undefined;

  do {
    const listed = await client.send(
      new ListObjectsV2Command({
        Bucket: bucket,
        Prefix: prefix,
        ContinuationToken: continuationToken,
      }),
    );

    const keys = (listed.Contents ?? [])
      .map((item) => item.Key)
      .filter((key): key is string => Boolean(key));

    if (keys.length > 0) {
      await client.send(
        new DeleteObjectsCommand({
          Bucket: bucket,
          Delete: {
            Objects: keys.map((key) => ({ Key: key })),
          },
        }),
      );
    }

    continuationToken = listed.IsTruncated
      ? listed.NextContinuationToken
      : undefined;
  } while (continuationToken);
}

function extensionFromMimeType(mimeType: string): string {
  switch (mimeType) {
    case "image/png":
      return ".png";
    case "image/webp":
      return ".webp";
    case "image/gif":
      return ".gif";
    case "image/heic":
    case "image/heif":
      return ".heic";
    default:
      return ".jpg";
  }
}
