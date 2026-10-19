import type { Browser, Route } from "playwright-core";
import { describe, expect, it, vi } from "vitest";
import { inspectLink } from "../src/checks/link/sandbox.js";
import { failing, returning } from "./helpers.js";

describe("isolated browser lifecycle", () => {
  it("blocks page POSTs before network access and permits only one vetted click", async () => {
    const abort = vi.fn();
    const fetchPage = vi.fn();
    const stop = vi.fn();
    const click = vi.fn();
    const evidence = {
      text: "Continue",
      candidates: [
        { index: 0, text: "Continue", href: "https://final.example/" },
      ],
      asksFor: [],
      downloads: false,
    };
    const page = {
      on: vi.fn(),
      goto: vi.fn(),
      evaluate: vi.fn().mockResolvedValue(evidence),
      url: () => "https://final.example/",
      screenshot: vi.fn().mockResolvedValue(new Uint8Array()),
      title: async () => "Destination",
      locator: () => ({ click, evaluate: vi.fn().mockResolvedValue(true) }),
      mainFrame: vi.fn(),
      waitForURL: vi.fn().mockRejectedValue(new Error("No navigation")),
      waitForLoadState: vi.fn().mockResolvedValue(undefined),
    };
    const context = {
      routeWebSocket: vi.fn(),
      addInitScript: vi.fn(),
      newPage: async () => page,
      route: async (
        _pattern: string,
        handler: (route: Route) => Promise<void>,
      ) =>
        handler({
          request: () => ({
            method: () => "POST",
            resourceType: () => "fetch",
          }),
          abort,
        } as unknown as Route),
    };
    const browser = { newContext: async () => context } as unknown as Browser;
    await inspectLink(
      "https://example.com/",
      returning({ candidateIndex: 0, asksFor: [], downloads: false }),
      { start: async () => ({ browser, stop }), fetch: fetchPage },
    );
    expect(abort).toHaveBeenCalledOnce();
    expect(fetchPage).not.toHaveBeenCalled();
    expect(click).toHaveBeenCalledOnce();
    expect(stop).toHaveBeenCalledOnce();
  });
  it("always stops the AgentCore session when setup fails", async () => {
    const stop = vi.fn().mockResolvedValue(undefined);
    const browser = {
      newContext: vi.fn().mockRejectedValue(new Error("Browser disconnected")),
    } as unknown as Browser;
    await expect(
      inspectLink("https://example.com", failing(), {
        start: async () => ({ browser, stop }),
      }),
    ).rejects.toThrow("disconnected");
    expect(stop).toHaveBeenCalledOnce();
  });
  it("survives navigation during evidence capture, ignores unlisted actions, and retains observations on model failure", async () => {
    const stop = vi.fn().mockResolvedValue(undefined);
    const click = vi.fn();
    const evidence = {
      text: "Enter your password",
      candidates: [],
      asksFor: ["password"],
      downloads: false,
    };
    const page = {
      on: vi.fn(),
      goto: vi.fn(),
      evaluate: vi
        .fn()
        .mockRejectedValueOnce(
          new Error(
            "Execution context was destroyed, most likely because of a navigation",
          ),
        )
        .mockResolvedValue(evidence),
      url: () => "https://example.com",
      screenshot: vi.fn().mockResolvedValue(new Uint8Array()),
      title: async () => "Login",
      locator: () => ({ click }),
      mainFrame: vi.fn(),
      waitForURL: vi.fn().mockRejectedValue(new Error("No navigation")),
    };
    const context = {
      routeWebSocket: vi.fn(),
      route: vi.fn(),
      addInitScript: vi.fn(),
      newPage: async () => page,
    };
    const browser = { newContext: async () => context } as unknown as Browser;
    const result = await inspectLink(
      "https://example.com",
      returning({ candidateIndex: 7, asksFor: [], downloads: false }),
      { start: async () => ({ browser, stop }) },
    );
    expect(result.report.asksFor).toContain("password");
    expect(click).not.toHaveBeenCalled();
    expect(stop).toHaveBeenCalledOnce();
    const degraded = await inspectLink("https://example.com", failing(), {
      start: async () => ({ browser, stop }),
    });
    expect(degraded.modelFailed).toBe(true);
    expect(degraded.report.asksFor).toContain("password");
  });
});
