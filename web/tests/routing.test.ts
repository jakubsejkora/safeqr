import assert from "node:assert/strict";
import { test } from "node:test";
import worker from "../worker/index.ts";

const context = {} as Parameters<typeof worker.fetch>[2];

test("www redirects permanently to HTTPS apex without losing path or query", async () => {
  const env = {
    ASSETS: {
      fetch: async () => {
        throw new Error("Redirects must not fetch assets");
      },
    },
  } as unknown as Parameters<typeof worker.fetch>[1];
  for (const method of ["GET", "HEAD", "POST"]) {
    const response = await worker.fetch(
      new Request("https://www.bezpecneqr.cz/en/kit/?demo=a%20b", { method }),
      env,
      context,
    );
    assert.equal(response.status, 308);
    assert.equal(response.headers.get("Location"), "https://bezpecneqr.cz/en/kit/?demo=a%20b");
    assert.ok(response.headers.get("Strict-Transport-Security"));
  }
});

test("missing English pages use the English error page and retain 404 status", async () => {
  const env = {
    ASSETS: {
      fetch: async (request: Request) =>
        new URL(request.url).pathname === "/en/404/"
          ? new Response("Page not found")
          : new Response("Stránka nenalezena", {
              status: new URL(request.url).pathname === "/404" ? 200 : 404,
            }),
    },
  } as unknown as Parameters<typeof worker.fetch>[1];
  for (const path of ["/en/missing/", "/en/404/", "/missing/", "/404"]) {
    const response = await worker.fetch(new Request(`https://bezpecneqr.cz${path}`), env, context);
    assert.equal(response.status, 404);
    assert.equal(
      await response.text(),
      path.startsWith("/en/") ? "Page not found" : "Stránka nenalezena",
    );
  }
});
