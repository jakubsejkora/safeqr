import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { chromium } from "@playwright/test";
import { DEMO_ORIGIN } from "../src/data/gallery.ts";

const origin = process.env.SITE_URL ?? "https://safeqr-web.jakub-f9d.workers.dev";
const screenDir = process.env.SCREEN_DIR ?? join(tmpdir(), "safeqr-web-screens");
await mkdir(screenDir, { recursive: true });
const browser = await chromium.launch();
const errors: string[] = [];
const results: unknown[] = [];
try {
  for (const device of [
    { name: "desktop", width: 1440, height: 1000 },
    { name: "mobile", width: 390, height: 844 },
  ]) {
    for (const colorScheme of ["light", "dark"] as const) {
      const context = await browser.newContext({ viewport: device, colorScheme });
      const page = await context.newPage();
      page.on("pageerror", (error) => errors.push(error.message));
      page.on("console", (message) => {
        if (message.type() === "error" && !message.text().includes("favicon"))
          errors.push(message.text());
      });
      for (const [name, path] of [
        ["home", "/"],
        ["gallery", "/galerie/"],
      ]) {
        const response = await page.goto(`${origin}${path}`, { waitUntil: "networkidle" });
        assert.equal(response?.status(), 200);
        const headers = await response?.allHeaders();
        for (const header of [
          "content-security-policy",
          "strict-transport-security",
          "referrer-policy",
          "permissions-policy",
        ])
          assert.ok(headers?.[header], `Missing ${header}`);
        assert.equal(
          await page.evaluate(() => document.documentElement.scrollWidth > innerWidth),
          false,
          `${name} overflows ${device.name}`,
        );
        const audit = await new AxeBuilder({ page })
          .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22a", "wcag22aa"])
          .analyze();
        results.push({ name, device: device.name, colorScheme, violations: audit.violations });
        await page.screenshot({
          path: join(screenDir, `web-${name}-${device.name}-${colorScheme}.png`),
        });
        if (name === "gallery") {
          await page.getByRole("button", { name: "SMS a volání", exact: true }).click();
          assert.equal(await page.locator("[data-qr-card]:visible").count(), 3);
          await page.getByRole("button", { name: "Všechny kódy" }).click();
          await page.getByLabel("Hledat v ukázkách").fill("kod uvnitr");
          assert.equal(await page.locator("[data-qr-card]:visible").count(), 1);
          await page.getByLabel("Hledat v ukázkách").fill("nothing-matches-this-query");
          assert.equal(await page.locator("[data-no-results]").isVisible(), true);
          await page.getByLabel("Hledat v ukázkách").fill("");
          await page.locator("#qr-platba summary").click();
          assert.ok(await page.locator("#qr-platba .payload").isVisible());
          await page.locator("#qr-platba").screenshot({
            path: join(screenDir, `web-gallery-detail-${device.name}-${colorScheme}.png`),
          });
        }
      }
      await context.close();
    }
  }
  const context = await browser.newContext({ viewport: { width: 320, height: 800 } });
  const page = await context.newPage();
  for (const path of [
    "/",
    "/en/",
    "/galerie/",
    "/en/gallery/",
    "/navody/",
    "/en/guides/",
    "/soukromi/",
    "/en/privacy/",
    "/kit/",
    "/en/kit/",
  ]) {
    assert.equal((await page.goto(`${origin}${path}`))?.status(), 200);
    assert.equal(
      await page.evaluate(() => document.documentElement.scrollWidth > innerWidth),
      false,
      `320px overflow: ${path}`,
    );
  }
  await page.setViewportSize({ width: 1440, height: 1000 });
  for (const path of ["/en/", "/navody/", "/soukromi/", "/kit/"]) {
    await page.goto(`${origin}${path}`);
    const audit = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22a", "wcag22aa"])
      .analyze();
    results.push({ path, violations: audit.violations });
  }
  await page.goto(`${origin}/kit/`);
  await page.setViewportSize({ width: 794, height: 1123 });
  await page.emulateMedia({ media: "print", colorScheme: "light" });
  await page.screenshot({ path: join(screenDir, "web-kit-print.png"), fullPage: true });
  const request = page.request;
  const feed = await request.get(`${origin}/api/cases?locale=cs`);
  assert.equal(feed.status(), 200);
  assert.equal(feed.headers()["cache-control"], "public, max-age=600");
  assert.equal((await feed.json()).source, "seed");
  assert.equal((await request.get(`${origin}/api/cases?locale=xx`)).status(), 400);
  assert.equal((await request.post(`${origin}/api/cases`)).status(), 405);
  assert.equal((await request.get(`${origin}/missing-page`)).status(), 404);
  const noJS = await browser.newPage({ javaScriptEnabled: false });
  await noJS.goto(`${origin}/galerie/`);
  assert.equal(await noJS.locator("[data-qr-card]:visible").count(), 30);
  await noJS.goto(origin);
  assert.ok((await noJS.locator("[data-case-list] article").count()) > 0);
  await noJS.close();
  const demoContext = await browser.newContext();
  const demo = await demoContext.newPage();
  const visited: string[] = [];
  demo.on("request", (request) => visited.push(new URL(request.url()).pathname));
  await demo.goto(`${DEMO_ORIGIN}/start`);
  await demo.waitForURL("**/pay");
  await demo.waitForLoadState("networkidle");
  assert.ok(["/start", "/step-2", "/step-3", "/pay"].every((path) => visited.includes(path)));
  await demo.locator("#card").fill("0000 0000 0000 0000");
  const before = visited.length;
  await demo.getByRole("button").click();
  assert.match(await demo.locator("output").innerText(), /Nothing was sent/);
  assert.equal(visited.length, before, "Demo must not send a request on completion");
  assert.equal(await demo.locator("#card").inputValue(), "");
  assert.equal((await request.post(`${DEMO_ORIGIN}/pay`, { data: "training-test" })).status(), 405);
  await demo.evaluate(() => window.scrollTo(0, 0));
  await demo.screenshot({ path: join(screenDir, "web-demo-desktop-light.png"), fullPage: true });
  const audit = await new AxeBuilder({ page: demo })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22a", "wcag22aa"])
    .analyze();
  results.push({ name: "demo", violations: audit.violations });
  await writeFile(
    join(screenDir, "web-browser-audit.json"),
    JSON.stringify({ results, errors }, null, 2),
  );
  assert.deepEqual(errors, [], "Browser errors");
  const violations = results.flatMap((result) => (result as { violations: unknown[] }).violations);
  assert.equal(
    violations.length,
    0,
    `Accessibility violations: ${JSON.stringify(violations.map((v) => (v as { id: string }).id))}`,
  );
  console.log(
    "Browser checks passed: light/dark, mobile/desktop/320px, accessibility, filters, no-JS, headers, feed fallback, print layout, and the complete no-submit demo flow.",
  );
} finally {
  await browser.close();
}
