import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { LIMITS, REGION } from "./config.js";

export interface MediaStore {
  put(key: string, bytes: Uint8Array): Promise<void>;
  get(key: string): Promise<Uint8Array>;
  delete(key: string): Promise<void>;
  sign(key: string): Promise<string>;
}

export class S3MediaStore implements MediaStore {
  private readonly s3 = new S3Client({ region: REGION, maxAttempts: 2 });
  constructor(private readonly bucket: string) {}
  async put(key: string, bytes: Uint8Array): Promise<void> {
    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: bytes,
        ContentType: "image/jpeg",
        ServerSideEncryption: "AES256",
        CacheControl: "private, no-store",
      }),
    );
  }
  async get(key: string): Promise<Uint8Array> {
    const response = await this.s3.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
    );
    if (!response.Body || (response.ContentLength ?? 0) > 1_500_000)
      throw new Error("Invalid image");
    const bytes = await response.Body.transformToByteArray();
    if (bytes.byteLength > 1_500_000) throw new Error("Invalid image");
    return bytes;
  }
  async delete(key: string): Promise<void> {
    await this.s3.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
    );
  }
  sign(key: string): Promise<string> {
    return getSignedUrl(
      this.s3,
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      { expiresIn: LIMITS.screenshotSeconds },
    );
  }
}
