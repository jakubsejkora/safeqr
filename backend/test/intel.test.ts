import { Ajv } from "ajv";
import { Ajv2020 } from "ajv/dist/2020.js";
import formats from "ajv-formats";
import { describe, expect, it, vi } from "vitest";
import actors from "../data/actors.json" with { type: "json" };
import researchSchema from "../data/case-schema.json" with { type: "json" };
import seeds from "../data/verified-cases.json" with { type: "json" };
import {
  extractIndicators,
  matchesIndicator,
} from "../src/checks/intel/indicators.js";
import { Apify } from "../src/intel/apify.js";
import { robotsAllows } from "../src/intel/article.js";
import { collect } from "../src/intel/collector.js";
import { prepareArticle } from "../src/intel/extract.js";
import { matchingIndicators, validateCase } from "../src/intel/schema.js";
import { actorJobs, canonicalSource } from "../src/intel/sources.js";
import { redact, redactArticle } from "../src/shared/privacy.js";
import { QuotaExceeded } from "../src/shared/storage.js";
import { failing, intel } from "./helpers.js";

describe("intel evidence and privacy", () => {
  it("includes Czech seven-digit SMS codes and non-Bitcoin crypto destinations", () => {
    expect(extractIndicators("SMSTO:9001234:START")).toContainEqual({
      type: "shortCode",
      value: "9001234",
    });
    const address = "So11111111111111111111111111111111111111112";
    expect(extractIndicators(`solana:${address}?amount=1`)).toContainEqual({
      type: "cryptoAddress",
      value: address,
    });
  });
  it("validates all sourced seeds against the research schema and never invents scam indicators", () => {
    const ajv = new Ajv2020({ strict: false });
    formats.default(ajv);
    const validate = ajv.compile(researchSchema);
    for (const seed of seeds) {
      expect(validate(seed.record), JSON.stringify(validate.errors)).toBe(true);
      expect(matchingIndicators(validateCase(seed.record))).toEqual([]);
    }
  });
  it("matches exact identifiers and bounded URL patterns, never substrings", () => {
    expect(
      matchesIndicator(
        { type: "domain", value: "evil.example" },
        { type: "domain", value: "evil.example" },
      ),
    ).toBe(true);
    expect(
      matchesIndicator(
        { type: "domain", value: "evil.example.good.example" },
        { type: "domain", value: "evil.example" },
      ),
    ).toBe(false);
    expect(
      matchesIndicator(
        { type: "urlPattern", value: "https://evil.example/pay/123" },
        { type: "urlPattern", value: "https://evil.example/pay/*" },
      ),
    ).toBe(true);
    expect(
      matchesIndicator(
        { type: "urlPattern", value: "https://good.example/pay/123" },
        { type: "urlPattern", value: "https://evil.example/pay/*" },
      ),
    ).toBe(false);
    expect(extractIndicators("SMSTO:+420900123456:START")).toContainEqual({
      type: "phone",
      value: "+420900123456",
    });
  });
  it("strips direct personal details and secrets before any model call", () => {
    const text = redactArticle(
      "QR podvod: Jan Novák, jan@example.com, +420 777 123 456, CZ6508000000192000145399.",
    );
    for (const personal of ["Jan Novák", "jan@example.com", "777", "CZ6508"])
      expect(text).not.toContain(personal);
    expect(redact("WIFI:T:WPA;S:cafe;P:secret-pass;;")).not.toContain(
      "secret-pass",
    );
    expect(
      redact("https://name:password@example.com/path?token=secret#secret"),
    ).toBe("https://example.com/path");
    expect(redact("Published 2026-10-19.")).toContain("2026-10-19");
  });
  it("only preserves indicators explicitly labeled fraudulent and never an official help domain", () => {
    const prepared = prepareArticle({
      sourceUrl: "https://policie.gov.cz/report",
      text: "QR kód byl podvod. Podvodná doména evil.example láká na platbu. Pomoc je na policie.gov.cz.",
    });
    expect(prepared.candidates).toEqual([
      { token: "[FRAUD_INDICATOR_0]", type: "domain", value: "evil.example" },
    ]);
    expect(prepared.text).not.toContain("evil.example");
    expect(
      prepareArticle({
        sourceUrl: "https://policie.gov.cz/report",
        text: "QR podvod: podvodná doména policie.gov.cz",
      }).candidates,
    ).toEqual([]);
  });
  it("rejects groups, profiles and unapproved source domains", () => {
    expect(
      canonicalSource("https://www.facebook.com/groups/scams"),
    ).toBeUndefined();
    expect(canonicalSource("https://evil.example/news")).toBeUndefined();
    expect(
      canonicalSource("https://policie.gov.cz/clanek/qr.aspx?utm_source=x"),
    ).toBe("https://policie.gov.cz/clanek/qr.aspx");
  });
  it("honors robots disallows and more specific allows", () => {
    const rules = "User-agent: *\nDisallow: /private\nAllow: /private/public\n";
    expect(robotsAllows(rules, "/private/report")).toBe(false);
    expect(robotsAllows(rules, "/private/public/report")).toBe(true);
  });
});

describe("Apify limits and actor contracts", () => {
  it("uses inputs accepted by the pinned official actor schemas with total caps below $1", () => {
    const ajv = new Ajv({ strict: false, validateFormats: false });
    const jobs = actorJobs();
    for (const job of jobs) {
      const actor = Object.values(actors).find((item) => item.id === job.actor);
      expect(actor).toBeDefined();
      const validate = ajv.compile(actor?.inputSchema ?? {});
      expect(validate(job.input), JSON.stringify(validate.errors)).toBe(true);
    }
    expect(jobs.reduce((sum, job) => sum + job.capUsd, 0)).toBeLessThan(1);
  });
  it("sends caps as run parameters, keeps the token out of URLs, and deletes all temporary stores", async () => {
    const calls: { url: string; method: string; body?: unknown }[] = [];
    const fetcher: typeof fetch = vi.fn(async (input, init) => {
      const url = String(input);
      calls.push({ url, method: init?.method ?? "GET", body: init?.body });
      if (init?.method === "DELETE") return new Response(null, { status: 204 });
      if (url.includes("/items?"))
        return Response.json([
          { sourceUrl: "https://policie.gov.cz/clanek/qr" },
        ]);
      return Response.json({
        data: {
          id: "run",
          status: "SUCCEEDED",
          defaultDatasetId: "data",
          defaultKeyValueStoreId: "kv",
          defaultRequestQueueId: "queue",
        },
      });
    });
    const job = actorJobs()[0];
    if (!job) throw new Error();
    const apify = new Apify("test-secret", fetcher);
    expect(await apify.run(job)).toHaveLength(1);
    expect(calls[0]?.url).toContain("maxTotalChargeUsd=0.2");
    expect(calls.every((call) => !call.url.includes("test-secret"))).toBe(true);
    expect(calls.filter((call) => call.method === "DELETE")).toHaveLength(4);
    await expect(apify.run({ ...job, capUsd: 0.7 })).rejects.toThrow("budget");
  });
  it("a repeated daily run performs no paid work", async () => {
    const run = vi.fn();
    const result = await collect({
      apify: { run },
      intel: intel(),
      model: failing(),
      claim: async () => {
        throw new QuotaExceeded();
      },
    });
    expect(result.skipped).toBe(true);
    expect(run).not.toHaveBeenCalled();
  });
});
