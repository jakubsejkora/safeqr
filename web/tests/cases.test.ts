import assert from "node:assert/strict";
import { test } from "node:test";
import { seedCases } from "../src/data/cases.ts";
import { getCases, parseCases } from "../worker/cases.ts";
import { secure } from "../worker/security.ts";

test("unconfigured and failed backends return a labeled localized seed", async () => {
  for (const backend of [undefined, "https://unreachable.test"]) {
    const response = await getCases("cs", backend, async () => {
      throw new Error("Offline");
    });
    const data = await response.json();
    assert.equal(data.source, "seed");
    assert.deepEqual(data.cases, seedCases("cs"));
    assert.equal(response.headers.get("Cache-Control"), "public, max-age=600");
  }
});
test("live feed uses the contract path and locale, and strips unrelated fields", async () => {
  const records = seedCases("en");
  const fetcher: typeof fetch = async (url, options) => {
    assert.equal(String(url), "https://api.example.com/v1/cases?locale=en&limit=5");
    assert.equal(options?.redirect, "error");
    return Response.json({
      cases: records.map((item) => ({ ...item, secret: "not for public display" })),
    });
  };
  const result = await (await getCases("en", "https://api.example.com", fetcher)).json();
  assert.equal(result.source, "live");
  assert.deepEqual(
    result.cases,
    records.map(({ region: _region, ...item }) => item),
  );
});
test("malformed and unsafe upstream data cannot enter the feed", async () => {
  const item = seedCases("cs")[0];
  for (const override of [
    { sourceUrl: "javascript:alert(1)" },
    { sourceUrl: "https://user:pass@example.com" },
    { title: 5 },
    { summary: "x".repeat(2001) },
    { publishedAt: "not a date" },
  ]) {
    assert.equal(parseCases({ cases: [{ ...item, ...override }] }), null);
  }
  const response = await getCases("en", "https://api.example.com", async () =>
    Response.json({ cases: [{ ...item, sourceUrl: "data:text/html,test" }] }),
  );
  assert.equal((await response.json()).source, "seed");
});
test("empty live results are valid; oversized responses fall back safely", async () => {
  assert.deepEqual(parseCases({ cases: [] }), []);
  const response = await getCases("en", "https://api.example.com", async () =>
    Response.json({ cases: [], padding: "x".repeat(70000) }),
  );
  assert.equal((await response.json()).source, "seed");
});
test("security headers protect even error responses", () => {
  const response = secure(new Response("missing", { status: 404 }), true);
  assert.equal(response.status, 404);
  assert.match(response.headers.get("Content-Security-Policy") ?? "", /form-action 'none'/);
  assert.match(response.headers.get("Content-Security-Policy") ?? "", /connect-src 'none'/);
  assert.equal(response.headers.get("Referrer-Policy"), "no-referrer");
  assert.equal(response.headers.get("X-Robots-Tag"), "noindex, nofollow");
});
