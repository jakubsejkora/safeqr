import { randomBytes } from "node:crypto";
import { InvokeCommand, LambdaClient } from "@aws-sdk/client-lambda";
import type {
  APIGatewayProxyEventV2,
  APIGatewayProxyStructuredResultV2,
} from "aws-lambda";
import { z } from "zod";
import { progress } from "../checks/verdict/copy.js";
import { DynamoIntelStore, type IntelStore } from "../intel/store.js";
import { env, LIMITS, REGION } from "../shared/config.js";
import { type MediaStore, S3MediaStore } from "../shared/media.js";
import { count, measured } from "../shared/observability.js";
import { cleanPhoto } from "../shared/photo.js";
import {
  acceptedSchema,
  checkIdSchema,
  checkSchema,
  localeSchema,
  requestSchema,
} from "../shared/schemas.js";
import {
  type CheckRecord,
  type CheckStore,
  DynamoCheckStore,
  QuotaExceeded,
  type StoredRequest,
  takeQuota,
} from "../shared/storage.js";

interface ApiDependencies {
  checks: CheckStore;
  media: MediaStore;
  intel: Pick<IntelStore, "list">;
  invoke(id: string): Promise<void>;
  admit(): Promise<void>;
}
const response = (
  statusCode: number,
  body: unknown,
  problem = false,
): APIGatewayProxyStructuredResultV2 => ({
  statusCode,
  headers: {
    "content-type": problem ? "application/problem+json" : "application/json",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    ...(statusCode === 429 ? { "retry-after": "60" } : {}),
  },
  body: JSON.stringify(body),
});
const problem = (status: number, title: string, detail: string) =>
  response(status, { type: "about:blank", title, status, detail }, true);

export function createApi(deps: ApiDependencies) {
  return async (
    event: APIGatewayProxyEventV2,
  ): Promise<APIGatewayProxyStructuredResultV2> => {
    try {
      // The HTTP API's default integration also receives CORS preflight requests.
      if (event.requestContext.http.method === "OPTIONS")
        return { statusCode: 204, headers: { "cache-control": "no-store" } };
      if (event.routeKey === "POST /v1/checks") return await start(event);
      if (event.routeKey === "GET /v1/checks/{checkId}") {
        const id = checkIdSchema.safeParse(event.pathParameters?.checkId);
        if (!id.success)
          return problem(
            404,
            "Check not found",
            "This check does not exist or has expired.",
          );
        let record = await deps.checks.get(id.data);
        if (!record)
          return problem(
            404,
            "Check not found",
            "This check does not exist or has expired.",
          );
        // An async invocation can expire before starting; polling must not remain running forever.
        if (
          record.status === "running" &&
          record.createdAt < Date.now() / 1000 - 150
        ) {
          if (record.photoKey)
            await deps.media
              .delete(record.photoKey)
              .catch(() => count("PhotoDeletionFailed"));
          await deps.checks.fail(record.id);
          record = await deps.checks.get(id.data);
          if (!record)
            return problem(
              404,
              "Check not found",
              "This check does not exist or has expired.",
            );
        }
        if (record.status === "failed")
          record.steps = record.steps.map((step) =>
            step.status === "running" || step.status === "pending"
              ? { ...step, status: "failed" }
              : step,
          );
        if (record.result?.link && record.screenshotKey)
          record.result.link.screenshotUrl = await deps.media.sign(
            record.screenshotKey,
          );
        return response(200, checkSchema.parse(record));
      }
      if (event.routeKey === "GET /v1/cases") {
        const query = z
          .object({
            locale: localeSchema.default("en"),
            limit: z.coerce.number().int().min(1).max(50).default(20),
          })
          .safeParse(event.queryStringParameters ?? {});
        if (!query.success)
          return problem(
            400,
            "Invalid query",
            "Use locale cs or en and a limit from 1 to 50.",
          );
        return response(200, {
          cases: await deps.intel.list(query.data.locale, query.data.limit),
        });
      }
      return problem(404, "Not found", "This endpoint does not exist.");
    } catch (error) {
      if (error instanceof QuotaExceeded)
        return problem(
          429,
          "Please wait",
          "The service is busy. Please try again later.",
        );
      count("ApiFailure");
      return problem(
        503,
        "Service unavailable",
        "The online check is temporarily unavailable.",
      );
    }
  };

  async function start(
    event: APIGatewayProxyEventV2,
  ): Promise<APIGatewayProxyStructuredResultV2> {
    const body = event.isBase64Encoded
      ? Buffer.from(event.body ?? "", "base64").toString("utf8")
      : (event.body ?? "");
    if (Buffer.byteLength(body) > LIMITS.requestBytes)
      return problem(413, "Request too large", "Use a smaller photo or code.");
    if (
      !/^application\/json(?:\s*;|$)/i.test(
        event.headers["content-type"] ?? event.headers["Content-Type"] ?? "",
      )
    )
      return problem(400, "Invalid request", "Send a JSON request.");
    let input: unknown;
    try {
      input = JSON.parse(body);
    } catch {
      return problem(400, "Invalid request", "The request is not valid JSON.");
    }
    const parsed = requestSchema.safeParse(input);
    if (!parsed.success)
      return problem(
        400,
        "Invalid request",
        "Check the code, language and device assessment.",
      );
    const { scene, ...base } = parsed.data;
    const request: StoredRequest = {
      ...base,
      ...(scene
        ? { scene: { source: scene.source, codeBounds: scene.codeBounds } }
        : {}),
    };
    if (Buffer.byteLength(JSON.stringify(request)) > 250_000)
      return problem(
        413,
        "Request too large",
        "The device assessment is too large.",
      );
    let image: Uint8Array | undefined;
    if (scene) {
      try {
        image = cleanPhoto(scene.image);
      } catch {
        return problem(
          400,
          "Invalid photo",
          "Use a JPEG photo encoded as base64.",
        );
      }
      const bounds = scene.codeBounds;
      if (
        bounds &&
        (Object.values(bounds).some((value) => value < 0 || value > 1) ||
          bounds.x + bounds.width > 1.00001 ||
          bounds.y + bounds.height > 1.00001)
      )
        return problem(
          400,
          "Invalid photo bounds",
          "Photo bounds must fit inside the image.",
        );
    }
    await deps.admit();
    const id = `chk_${randomBytes(16).toString("hex")}`;
    const createdAt = Math.floor(Date.now() / 1000);
    const record: CheckRecord = {
      id,
      status: "running",
      request,
      createdAt,
      expiresAt: createdAt + LIMITS.retentionSeconds,
      steps: (
        ["redirects", "sandbox", "scene", "intel", "verdict"] as const
      ).map((step) => progress(request.locale, step, "pending")),
      ...(image ? { photoKey: `scenes/${id}.jpg` } : {}),
    };
    let stored = false;
    try {
      if (image && record.photoKey)
        await deps.media.put(record.photoKey, image);
      await deps.checks.create(record);
      stored = true;
      await deps.invoke(id);
      count("CheckAccepted");
      return response(
        202,
        acceptedSchema.parse({ id, status: "running", pollAfterMs: 1000 }),
      );
    } catch (error) {
      if (record.photoKey)
        await deps.media
          .delete(record.photoKey)
          .catch(() => count("PhotoDeletionFailed"));
      if (stored) await deps.checks.fail(id);
      throw error;
    } finally {
      image?.fill(0);
    }
  }
}

const lambda = new LambdaClient({ region: REGION, maxAttempts: 1 });
export const handler = (event: APIGatewayProxyEventV2) =>
  measured("api", () =>
    createApi({
      checks: new DynamoCheckStore(env("CHECKS_TABLE")),
      media: new S3MediaStore(env("MEDIA_BUCKET")),
      intel: new DynamoIntelStore(env("INTEL_TABLE")),
      invoke: async (id) => {
        const result = await lambda.send(
          new InvokeCommand({
            FunctionName: env("WORKER_NAME"),
            InvocationType: "Event",
            Payload: Buffer.from(JSON.stringify({ id })),
          }),
        );
        if (result.StatusCode !== 202) throw new Error("Worker unavailable");
      },
      admit: async () => {
        await takeQuota(
          env("CHECKS_TABLE"),
          "starts",
          60,
          LIMITS.checkStartsPerMinute,
        );
        await takeQuota(
          env("CHECKS_TABLE"),
          "daily",
          86_400,
          LIMITS.checksPerDay,
        );
      },
    })(event),
  );
