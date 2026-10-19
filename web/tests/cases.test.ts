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
  let requestedUrl: string | undefined;
  let redirect: RequestRedirect | undefined;
  const fetcher: typeof fetch = async (url, options) => {
    requestedUrl = String(url);
    redirect = options?.redirect;
    return Response.json({
      cases: records.map((item) => ({ ...item, secret: "not for public display" })),
    });
  };
  const result = await (await getCases("en", "https://api.example.com", fetcher)).json();
  assert.equal(requestedUrl, "https://api.example.com/v1/cases?locale=en&limit=5");
  assert.equal(redirect, "manual");
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
    { publishedAt: "2026-02-29" },
    { publishedAt: "2026-04-31" },
  ]) {
    assert.equal(parseCases({ cases: [{ ...item, ...override }] }), null);
  }
  const response = await getCases("en", "https://api.example.com", async () =>
    Response.json({ cases: [{ ...item, sourceUrl: "data:text/html,test" }] }),
  );
  assert.equal((await response.json()).source, "seed");
});
test("calendar dates accept leap days and sort newest first", () => {
  const item = seedCases("en")[0];
  const dates = ["2024-02-29", "2026-10-20", "2025-12-31"];
  const result = parseCases({
    cases: dates.map((publishedAt) => ({ ...item, id: publishedAt, publishedAt })),
  });
  assert.deepEqual(
    result?.map((entry) => entry.publishedAt),
    [...dates].sort().reverse(),
  );
});
test("upstream redirects fall back without following the destination", async () => {
  const response = await getCases(
    "en",
    "https://api.example.com",
    async () => new Response(null, { status: 302, headers: { Location: "http://127.0.0.1/" } }),
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
