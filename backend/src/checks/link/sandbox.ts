import { setTimeout as delay } from "node:timers/promises";
import type { Page } from "playwright-core";
import { z } from "zod";
import { MODELS } from "../../shared/config.js";
import type { Model } from "../../shared/model.js";
import { safeFetch, type WebFetch, webUrl } from "../../shared/network.js";
import { redact } from "../../shared/privacy.js";
import type { LinkReport } from "../../shared/schemas.js";
import { isInstagramUrl } from "../social/links.js";
import { type BrowserSession, startBrowser } from "./agentcore.js";
import { inspectControls, riskyDownload } from "./page-requests.js";
import { BROWSER_PROMPT } from "./prompt.v2.js";

const decisionSchema = z.object({
  candidateIndex: z.number().int().min(0).max(7).nullable(),
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
  const snapshot = await page.evaluate(() => {
    const text = document.body?.innerText.slice(0, 8000) ?? "";
    const controls: string[] = [];
    for (const element of [
      ...document.querySelectorAll<HTMLElement>(
        "input, select, textarea, iframe, button, [role=button]",
      ),
      ...document.querySelectorAll<HTMLElement>("a[href]"),
    ]) {
      if (
        !element.checkVisibility({
          checkOpacity: true,
          checkVisibilityCSS: true,
        }) ||
        element.closest('[hidden], [inert], [aria-hidden="true"]') ||
        element.matches(":disabled")
      )
        continue;
      const clone = element.cloneNode(true) as HTMLElement;
      const labels =
        "labels" in element
          ? [...((element as HTMLInputElement).labels ?? [])].map(
              (label) => label.textContent ?? "",
            )
          : [];
      for (const id of (element.getAttribute("aria-labelledby") ?? "").split(
        /\s+/,
      )) {
        if (id) labels.push(document.getElementById(id)?.textContent ?? "");
      }
      clone.setAttribute("data-safeqr-label", labels.join(" ").slice(0, 500));
      controls.push(clone.outerHTML.slice(0, 4000));
      if (controls.length >= 200) break;
    }
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
      controls: controls.join(""),
      url: location.href,
    };
  });
  return { ...snapshot, ...inspectControls(snapshot.controls, snapshot.url) };
}

async function settledEvidence(page: Page): Promise<PageEvidence> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const previous = page.url();
    try {
      await page
        .waitForLoadState("domcontentloaded", { timeout: 2000 })
        .catch(() => undefined);
      const navigated = await page
        .waitForURL((url) => url.href !== previous, {
          timeout: 1100,
          waitUntil: "domcontentloaded",
        })
        .then(
          () => true,
          () => false,
        );
      if (!navigated) {
        const evidence = await pageEvidence(page);
        if (page.url() === previous) return evidence;
      }
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
          (request.resourceType() === "image" &&
            (isInstagramUrl(page.url()) ||
              /(^|\.)(cdninstagram\.com|fbcdn\.net)$/.test(
                new URL(request.url()).hostname,
              ))) ||
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
        if (mainNavigation) navigationFailed = response.status >= 400;
        if (receivedBytes > 8_000_000) {
          restricted = true;
          if (mainNavigation) navigationFailed = true;
          await route.abort();
          return;
        }
        if (/attachment/i.test(response.headers["content-disposition"] ?? "")) {
          const disposition = response.headers["content-disposition"] ?? "";
          const filename =
            disposition.match(/filename\*?=(?:UTF-8'')?["']?([^"';]+)/i)?.[1] ??
            "";
          downloads ||= riskyDownload(
            request.url(),
            filename,
            response.headers["content-type"],
          );
          restricted = true;
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
      downloads ||= riskyDownload(download.url(), download.suggestedFilename());
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
    };
    try {
      if (before.candidates.length)
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
    const screenshot = isInstagramUrl(finalUrl)
      ? new Uint8Array()
      : await page.screenshot({
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
        asksFor: after.asksFor,
      },
      screenshot,
      downloads: downloads || before.downloads || after.downloads,
      restricted,
      navigationFailed,
      modelFailed,
    };
  }
}
