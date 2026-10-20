import { describe, expect, it, vi } from "vitest";
import { createWorker, type WorkerDependencies } from "../src/checks/worker.js";
import {
  draft,
  failing,
  id,
  intel,
  MemoryChecks,
  media,
  record,
  returning,
} from "./helpers.js";

describe("worker orchestration", () => {
  it("runs the profile check alongside the sandbox and labels only applicable public-information progress", async () => {
    const checks = new MemoryChecks();
    const files = media();
    await checks.create(record());
    let release: (() => void) | undefined;
    const profileStarted = new Promise<void>((resolve) => {
      release = resolve;
    });
    const finalUrl = "https://instagram.com/example_profile/";
    const social = vi.fn<NonNullable<WorkerDependencies["social"]>>(
      async (_input, dependencies) => {
        await dependencies?.progress?.();
        release?.();
        return {
          report: {
            links: [
              {
                url: "https://onlyfans.com/example",
                domain: "onlyfans.com",
                category: "adult" as const,
              },
            ],
            unresolvedForwarders: [],
          },
          limitations: [],
        };
      },
    );
    await createWorker({
      checks,
      media: files,
      intel: intel(),
      model: () => returning(draft),
      trace: async () => ({ report: { finalUrl, hops: [] } }),
      sandbox: async () => {
        await profileStarted;
        return {
          report: { finalUrl, hops: [] },
          screenshot: new Uint8Array(),
          downloads: false,
          restricted: false,
          navigationFailed: false,
          modelFailed: false,
        };
      },
      age: async () => 5000,
      social,
    })({ id });
    const result = await checks.get(id);
    expect(social).toHaveBeenCalledOnce();
    expect(result?.steps.find((step) => step.id === "intel")?.label).toContain(
      "(Apify)",
    );
    expect(result?.result?.score).toBe(40);
    expect(result?.result).not.toHaveProperty("social");
    expect(files.put).not.toHaveBeenCalled();
  });
  it("keeps a failed destination at caution with an explicit explanation", async () => {
    const checks = new MemoryChecks();
    await checks.create(record());
    await createWorker({
      checks,
      media: media(),
      intel: intel(),
      model: () => returning(draft),
      trace: async () => ({
        report: {
          finalUrl: "https://example.com/",
          hops: [{ url: "https://example.com/", status: 403, via: "http" }],
        },
        limitation: "unavailable",
      }),
      sandbox: async () => ({
        report: { finalUrl: "https://example.com/", hops: [] },
        screenshot: new Uint8Array(),
        downloads: false,
        restricted: false,
        navigationFailed: true,
        modelFailed: false,
      }),
      age: async () => undefined,
    })({ id });
    const result = await checks.get(id);
    expect(result?.status).toBe("completed");
    expect(result?.result?.level).toBe("caution");
    expect(result?.steps.find((step) => step.id === "sandbox")?.status).toBe(
      "failed",
    );
  });
  it("runs independent checks concurrently, gives the scene the traced destination, and deletes photos on model failure", async () => {
    const checks = new MemoryChecks();
    const files = media();
    const cases = intel();
    await checks.create({ ...record(), photoKey: `scenes/${id}.jpg` });
    const started: string[] = [];
    let sceneDestination: string | undefined;
    let release: (() => void) | undefined;
    const barrier = new Promise<void>((resolve) => {
      release = resolve;
    });
    const worker = createWorker({
      checks,
      media: files,
      intel: cases,
      model: () => failing(),
      trace: async () => {
        started.push("trace");
        return {
          report: { finalUrl: "https://destination.example/", hops: [] },
        };
      },
      sandbox: async () => {
        started.push("sandbox");
        await barrier;
        throw new Error("AgentCore unavailable");
      },
      scene: async (_request, _image, _model, destination) => {
        started.push("scene");
        sceneDestination = destination;
        release?.();
        throw new Error("Vision unavailable");
      },
      age: async () => undefined,
    });
    await worker({ id });
    expect(started.sort()).toEqual(["sandbox", "scene", "trace"]);
    expect(sceneDestination).toBe("https://destination.example/");
    const result = await checks.get(id);
    expect(result?.status).toBe("completed");
    expect(result?.result?.link?.finalUrl).toBe("https://destination.example/");
    expect(result?.result?.level).toBe("safe");
    expect(files.delete).toHaveBeenCalledWith(`scenes/${id}.jpg`);
    expect(result?.request).toBeUndefined();
    expect(cases.match).toHaveBeenCalledWith(
      expect.arrayContaining([
        { type: "domain", value: "destination.example" },
      ]),
      "en",
    );
  });
  it("does not start a browser for SMS and refuses duplicate worker deliveries", async () => {
    const checks = new MemoryChecks();
    const base = record();
    await checks.create({
      ...base,
      request: {
        ...base.request,
        ...{
          payload: "SMSTO:9001234:START",
          kind: "sms",
          locale: "en",
          device: { score: 70, floor: 70, findingIds: [] },
        },
      },
    });
    const sandbox = vi.fn();
    const model = vi.fn(() => returning(draft));
    const worker = createWorker({
      checks,
      media: media(),
      intel: intel(),
      model,
      sandbox,
    });
    await Promise.all([worker({ id }), worker({ id })]);
    expect(model).toHaveBeenCalledTimes(1);
    expect(sandbox).not.toHaveBeenCalled();
    expect((await checks.get(id))?.result?.score).toBe(70);
    expect(
      (await checks.get(id))?.steps.find((step) => step.id === "sandbox")
        ?.status,
    ).toBe("skipped");
  });
  it("retries failed immediate deletion after analysis finishes", async () => {
    const checks = new MemoryChecks();
    const files = media();
    vi.mocked(files.delete).mockRejectedValueOnce(
      new Error("temporary failure"),
    );
    await checks.create({ ...record(), photoKey: `scenes/${id}.jpg` });
    await createWorker({
      checks,
      media: files,
      intel: intel(),
      model: () => returning(draft),
      trace: async () => ({ limitation: "unavailable" }),
      sandbox: async () => {
        throw new Error();
      },
      scene: async () => ({ summary: "A poster." }),
    })({ id });
    expect(files.delete).toHaveBeenCalledTimes(2);
    expect((await checks.get(id))?.result?.limitations.join(" ")).toContain(
      "photo deletion",
    );
  });
});
