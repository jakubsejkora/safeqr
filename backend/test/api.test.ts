import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { describe, expect, it, vi } from "vitest";
import { createApi } from "../src/api/handler.js";
import { QuotaExceeded } from "../src/shared/storage.js";
import { id, intel, MemoryChecks, media, record, request } from "./helpers.js";

function event(routeKey: string, body?: unknown): APIGatewayProxyEventV2 {
  return {
    version: "2.0",
    routeKey,
    rawPath: "/v1/checks",
    rawQueryString: "",
    headers: { "content-type": "application/json" },
    isBase64Encoded: false,
    body: body === undefined ? undefined : JSON.stringify(body),
    requestContext: {
      accountId: "test",
      apiId: "test",
      domainName: "example.com",
      domainPrefix: "test",
      http: {
        method: "POST",
        path: "/v1/checks",
        protocol: "HTTP/1.1",
        sourceIp: "127.0.0.1",
        userAgent: "test",
      },
      requestId: "test",
      routeKey,
      stage: "$default",
      time: "",
      timeEpoch: 0,
    },
  };
}

describe("HTTP contract and retention", () => {
  it("returns 202, queues only a capability ID, and hides internal state when polled", async () => {
    const checks = new MemoryChecks();
    const invoke = vi.fn().mockResolvedValue(undefined);
    const api = createApi({
      checks,
      media: media(),
      intel: intel(),
      invoke,
      admit: async () => undefined,
    });
    const accepted = await api(event("POST /v1/checks", request));
    expect(accepted.statusCode).toBe(202);
    const body = JSON.parse(accepted.body ?? "");
    expect(body.id).toMatch(/^chk_[a-f0-9]{32}$/);
    expect(invoke).toHaveBeenCalledWith(body.id);
    const result = await api({
      ...event("GET /v1/checks/{checkId}"),
      pathParameters: { checkId: body.id },
    });
    expect(Object.keys(JSON.parse(result.body ?? ""))).toEqual([
      "id",
      "status",
      "steps",
    ]);
  });
  it("returns RFC 9457 errors without reflecting the payload", async () => {
    const api = createApi({
      checks: new MemoryChecks(),
      media: media(),
      intel: intel(),
      invoke: vi.fn(),
      admit: vi.fn(),
    });
    const result = await api(
      event("POST /v1/checks", {
        ...request,
        device: { floor: -1 },
        payload: "secret@example.com",
      }),
    );
    expect(result.statusCode).toBe(400);
    expect(result.headers?.["content-type"]).toBe("application/problem+json");
    expect(result.body).not.toContain("secret@example.com");
  });
  it("enforces request sizes before parsing and returns application throttling errors", async () => {
    const api = createApi({
      checks: new MemoryChecks(),
      media: media(),
      intel: intel(),
      invoke: vi.fn(),
      admit: async () => {
        throw new QuotaExceeded();
      },
    });
    expect(
      (await api({ ...event("POST /v1/checks"), body: "a".repeat(2_100_001) }))
        .statusCode,
    ).toBe(413);
    const result = await api(event("POST /v1/checks", request));
    expect(result.statusCode).toBe(429);
    expect(JSON.parse(result.body ?? "").status).toBe(429);
  });
  it("hides expired checks even before DynamoDB's delayed TTL deletion", async () => {
    const checks = new MemoryChecks();
    await checks.create({ ...record(), expiresAt: 1 });
    const api = createApi({
      checks,
      media: media(),
      intel: intel(),
      invoke: vi.fn(),
      admit: vi.fn(),
    });
    expect(
      (
        await api({
          ...event("GET /v1/checks/{checkId}"),
          pathParameters: { checkId: id },
        })
      ).statusCode,
    ).toBe(404);
  });
  it("turns a stranded invocation into a failure instead of polling forever", async () => {
    const checks = new MemoryChecks();
    const files = media();
    await checks.create({
      ...record(),
      createdAt: Math.floor(Date.now() / 1000) - 200,
      photoKey: `scenes/${id}.jpg`,
    });
    const api = createApi({
      checks,
      media: files,
      intel: intel(),
      invoke: vi.fn(),
      admit: vi.fn(),
    });
    const result = await api({
      ...event("GET /v1/checks/{checkId}"),
      pathParameters: { checkId: id },
    });
    expect(JSON.parse(result.body ?? "").status).toBe("failed");
    expect(files.delete).toHaveBeenCalledWith(`scenes/${id}.jpg`);
  });
  it("defaults the case feed to English and validates its limit", async () => {
    const cases = intel();
    const api = createApi({
      checks: new MemoryChecks(),
      media: media(),
      intel: cases,
      invoke: vi.fn(),
      admit: vi.fn(),
    });
    await api(event("GET /v1/cases"));
    expect(cases.list).toHaveBeenCalledWith("en", 20);
    expect(
      (
        await api({
          ...event("GET /v1/cases"),
          queryStringParameters: { limit: "51" },
        })
      ).statusCode,
    ).toBe(400);
  });
});
