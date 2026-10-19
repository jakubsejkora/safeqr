import { describe, expect, it, vi } from "vitest";
import { createWorker } from "../src/checks/worker.js";
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
  it("runs independent checks concurrently, matches the final destination, and deletes photos on model failure", async () => {
    const checks = new MemoryChecks();
    const files = media();
    const cases = intel();
    await checks.create({ ...record(), photoKey: `scenes/${id}.jpg` });
    const started: string[] = [];
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
        await barrier;
        return {
          report: { finalUrl: "https://destination.example/", hops: [] },
        };
      },
      sandbox: async () => {
        started.push("sandbox");
        await barrier;
        throw new Error("AgentCore unavailable");
      },
      scene: async () => {
        started.push("scene");
        release?.();
        throw new Error("Vision unavailable");
      },
      age: async () => undefined,
    });
    await worker({ id });
    expect(started.sort()).toEqual(["sandbox", "scene", "trace"]);
    const result = await checks.get(id);
    expect(result?.status).toBe("completed");
    expect(result?.result?.link?.finalUrl).toBe("https://destination.example/");
    expect(result?.result?.level).toBe("caution");
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
