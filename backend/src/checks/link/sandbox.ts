import type { Page } from "playwright-core";
import { z } from "zod";
import { MODELS } from "../../shared/config.js";
import type { Model } from "../../shared/model.js";
import { safeFetch, type WebFetch, webUrl } from "../../shared/network.js";
import { redact } from "../../shared/privacy.js";
import { asksForSchema, type LinkReport } from "../../shared/schemas.js";
import { type BrowserSession, startBrowser } from "./agentcore.js";
import { BROWSER_PROMPT } from "./prompt.v1.js";

const decisionSchema = z.object({
  candidateIndex: z.number().int().min(0).max(7).nullable(),
  asksFor: z.array(asksForSchema).max(9),
  downloads: z.boolean(),
});
interface Candidate {
  index: number;
  text: string;
  href: string | null;
}
interface PageEvidence {
  text: string;
  candidates: Candidate[];
  asksFor: LinkReport["asksFor"];
  downloads: boolean;
}
export interface SandboxResult {
  report: LinkReport;
  screenshot: Uint8Array;
  downloads: boolean;
  restricted: boolean;
  navigationFailed: boolean;
  modelFailed: boolean;
}

async function pageEvidence(page: Page): Promise<PageEvidence> {
  return page.evaluate(() => {
    const text = document.body?.innerText.slice(0, 8000) ?? "";
    const inputHints = [...document.querySelectorAll("input")]
      .map((input) =>
        [input.type, input.name, input.autocomplete, input.placeholder].join(
          " ",
        ),
      )
      .join(" ");
    const hints = `${inputHints} ${text}`.toLowerCase();
    const asksFor: NonNullable<LinkReport["asksFor"]> = [];
    if (/password|heslo/.test(hints)) asksFor.push("password");
    if (
      /credit.?card|card number|číslo karty|platební kart|cc-number|cvv|cvc/.test(
        hints,
      )
    )
      asksFor.push("card");
    if (/bank.?login|bankid|bankovní identit|přihlášení.{0,20}bank/.test(hints))
      asksFor.push("bankLogin");
    if (/phone|telefon|autocomplete.?tel/.test(hints)) asksFor.push("phone");
    if (
      /one-time|otp|sms.{0,12}kód|verification code|ověřovací kód/.test(hints)
    )
      asksFor.push("otp");
    if (/e-mail|email|home address|bydliště|datum narození/.test(hints))
      asksFor.push("personalData");
    if (/pay|payment|platba|zaplatit|parkovné/.test(hints))
      asksFor.push("payment");
    if (/install|instalovat|stáhnout aplikaci/.test(hints))
      asksFor.push("appInstall");
    if (
      /allow notifications|povolit oznámení|povolit přístup|grant permission/.test(
        hints,
      )
    )
      asksFor.push("permission");
    const candidates: Candidate[] = [];
    for (const element of document.querySelectorAll<
      HTMLAnchorElement | HTMLButtonElement
    >("a[href], button[type=button]")) {
      if (candidates.length === 8) break;
      const label = element.innerText.trim();
      if (
        !/^(continue|continue to (site|website)|open (site|website)|pay parking|pokračovat|přejít na web|zaplatit parkovné|reject all|reject cookies|odmítnout vše|odmítnout cookies|close|zavřít)$/i.test(
          label,
        )
      )
        continue;
      if (
        element.closest("form") ||
        element.getAttribute("download") !== null ||
        element.getBoundingClientRect().width === 0
      )
        continue;
      const href = element instanceof HTMLAnchorElement ? element.href : null;
      if (
        href &&
        (!/^https?:/.test(href) ||
          /\b(submit|confirm|purchase|subscribe|delete|logout|install|authorize)\b/i.test(
            href,
          ))
      )
        continue;
      const index = candidates.length;
      element.setAttribute("data-safeqr-choice", String(index));
      candidates.push({ index, text: label, href });
    }
    return {
      text,
      candidates,
      asksFor,
      downloads: Boolean(
        document.querySelector(
          "a[download], a[href$='.apk'], a[href$='.exe'], a[href$='.dmg']",
        ),
      ),
    };
  });
}

async function settledEvidence(page: Page): Promise<PageEvidence> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const previous = page.url();
    try {
      const evidence = await pageEvidence(page);
      const navigated = await page
        .waitForURL((url) => url.href !== previous, {
          timeout: 1100,
          waitUntil: "domcontentloaded",
        })
        .then(
          () => true,
          () => false,
        );
      if (!navigated) return evidence;
    } catch (error) {
      if (
        !(error instanceof Error) ||
        !/context was destroyed|Cannot find context/i.test(error.message)
      )
        throw error;
      await delay(100);
    }
  }
  throw new Error("Page kept redirecting during inspection");
}

export async function inspectLink(
  input: string,
  model: Model,
  dependencies: {
    start?: () => Promise<BrowserSession>;
    fetch?: WebFetch;
  } = {},
): Promise<SandboxResult> {
  webUrl(input);
  const session = await (dependencies.start ?? startBrowser)();
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      inspect(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(
          () => reject(new Error("Browser time limit")),
          18_000,
        );
      }),
    ]);
  } finally {
    clearTimeout(timer);
    await session.stop();
  }

  async function inspect(): Promise<SandboxResult> {
    const context = await session.browser.newContext({
      acceptDownloads: false,
      serviceWorkers: "block",
      permissions: [],
      viewport: { width: 1280, height: 800 },
    });
    let restricted = false;
    let navigationFailed = false;
    let downloads = false;
    let requests = 0;
    let inFlight = 0;
    let receivedBytes = 0;
    const httpRedirects = new Set<string>();
    await context.routeWebSocket("**/*", (socket) => socket.close());
    await context.route("**/*", async (route) => {
      let active = false;
      const request = route.request();
      let mainNavigation = false;
      try {
        mainNavigation =
          request.isNavigationRequest() && request.frame() === page.mainFrame();
        if (
          request.method() !== "GET" ||
          ["media", "font"].includes(request.resourceType()) ||
          ++requests > 64 ||
          inFlight >= 6 ||
          receivedBytes >= 8_000_000
        ) {
          restricted = true;
          if (mainNavigation) navigationFailed = true;
          await route.abort();
          return;
        }
        inFlight++;
        active = true;
        // Fulfilling from the pinned fetcher prevents a second, unvalidated browser DNS lookup.
        const response = await (dependencies.fetch ?? safeFetch)(
          request.url(),
          { signal: AbortSignal.timeout(2500) },
        );
        receivedBytes += response.body.byteLength;
        if (mainNavigation && response.status >= 400) navigationFailed = true;
        if (receivedBytes > 8_000_000) {
          restricted = true;
          if (mainNavigation) navigationFailed = true;
          await route.abort();
          return;
        }
        if (/attachment/i.test(response.headers["content-disposition"] ?? "")) {
          downloads = true;
          if (mainNavigation) navigationFailed = true;
          await route.abort();
          return;
        }
        // Chromium follows fulfilled HTTP redirects without routing the next request.
        if ([301, 302, 303, 307, 308].includes(response.status)) {
          if (!request.isNavigationRequest() || !response.headers.location) {
            restricted = true;
            if (mainNavigation) navigationFailed = true;
            await route.abort();
            return;
          }
          const target = webUrl(
            new URL(response.headers.location, request.url()).href,
          ).href;
          httpRedirects.add(target);
          await route.fulfill({
            status: 200,
            headers: {
              "content-type": "text/html; charset=utf-8",
              "cache-control": "no-store",
            },
            body: `<script>location.replace(${JSON.stringify(target).replace(/</g, "\\u003c")})</script>`,
          });
          return;
        }
        const headers = { ...response.headers };
        delete headers["content-disposition"];
        await route.fulfill({
          status: response.status,
          headers,
          body: response.body,
        });
      } catch {
        restricted = true;
        if (mainNavigation) navigationFailed = true;
        await route.abort().catch(() => undefined);
      } finally {
        if (active) inFlight--;
      }
    });
    await context.addInitScript(() => {
      document.addEventListener(
        "submit",
        (event) => {
          event.preventDefault();
          event.stopImmediatePropagation();
        },
        true,
      );
      HTMLFormElement.prototype.submit = () => undefined;
      HTMLFormElement.prototype.requestSubmit = () => undefined;
      window.open = () => null;
    });
    const page = await context.newPage();
    page.on("dialog", (dialog) => {
      void dialog.dismiss();
    });
    page.on("download", (download) => {
      downloads = true;
      void download.cancel();
    });
    const hops: LinkReport["hops"] = [];
    page.on("framenavigated", (frame) => {
      if (
        frame === page.mainFrame() &&
        /^https?:/.test(frame.url()) &&
        hops.length < 10
      )
        hops.push({
          url: frame.url(),
          via: httpRedirects.has(frame.url()) ? "http" : "javascript",
        });
    });
    await page.goto(input, { waitUntil: "domcontentloaded", timeout: 6000 });
    const before = await settledEvidence(page);
    let modelFailed = false;
    let decision: z.infer<typeof decisionSchema> = {
      candidateIndex: null,
      asksFor: [],
      downloads: false,
    };
    try {
      decision = await model.ask({
        model: MODELS.haiku,
        system: BROWSER_PROMPT,
        schema: decisionSchema,
        data: {
          text: redact(before.text),
          candidates: before.candidates.map((candidate) => ({
            ...candidate,
            href: candidate.href ? redact(candidate.href) : null,
          })),
        },
        maxTokens: 350,
      });
    } catch {
      modelFailed = true;
    }
    const selected = before.candidates.find(
      (candidate) => candidate.index === decision.candidateIndex,
    );
    if (selected) {
      if (selected.href) webUrl(selected.href);
      const element = page.locator(`[data-safeqr-choice="${selected.index}"]`);
      const unchanged = await element
        .evaluate((node, expected) => {
          return (
            node instanceof HTMLElement &&
            !node.closest("form") &&
            node.innerText.trim() === expected.text &&
            (node instanceof HTMLAnchorElement
              ? node.href === expected.href && !node.hasAttribute("download")
              : node instanceof HTMLButtonElement && node.type === "button")
          );
        }, selected)
        .catch(() => false);
      if (unchanged) {
        const previousUrl = page.url();
        await Promise.all([
          page
            .waitForURL((url) => url.href !== previousUrl, {
              timeout: 2000,
              waitUntil: "domcontentloaded",
            })
            .catch(() => undefined),
          element.click({ timeout: 2000, noWaitAfter: true }),
        ]);
      }
      await page
        .waitForLoadState("domcontentloaded", { timeout: 2000 })
        .catch(() => undefined);
    }
    const after = await settledEvidence(page);
    const finalUrl = webUrl(page.url()).href;
    const screenshot = await page.screenshot({
      type: "jpeg",
      quality: 55,
      fullPage: false,
      timeout: 2000,
    });
    return {
      report: {
        finalUrl,
        hops,
        pageTitle: (await page.title()).slice(0, 200),
        asksFor: [
          ...new Set([
            ...(before.asksFor ?? []),
            ...decision.asksFor,
            ...(after.asksFor ?? []),
          ]),
        ],
      },
      screenshot,
      downloads:
        downloads || before.downloads || decision.downloads || after.downloads,
      restricted,
      navigationFailed,
      modelFailed,
    };
  }
}

import { setTimeout as delay } from "node:timers/promises";
