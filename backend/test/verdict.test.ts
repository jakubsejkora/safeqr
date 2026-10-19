import { describe, expect, it } from "vitest";
import {
  createVerdict,
  deterministicVerdict,
} from "../src/checks/verdict/agent.js";
import type { Case } from "../src/shared/schemas.js";
import { draft, failing, request, returning } from "./helpers.js";

const known: Case = {
  id: "case",
  title: "Reported case",
  summary: "A reported scam",
  sourceUrl: "https://policie.gov.cz/article",
  publishedAt: "2026-10-19",
};

describe("deterministic safety boundaries", () => {
  it("raises concealed card collection to danger while an ordinary card form remains caution", () => {
    const link = {
      finalUrl: "https://parking.example/pay",
      asksFor: ["card" as const],
      hops: [
        {
          url: "https://parking.example/start",
          status: 302,
          via: "http" as const,
        },
        {
          url: "https://parking.example/next",
          status: 200,
          via: "http" as const,
        },
        {
          url: "https://parking.example/wait",
          status: 200,
          via: "meta" as const,
        },
        { url: "https://parking.example/pay", via: "javascript" as const },
      ],
    };
    expect(
      deterministicVerdict(request, { intel: [], limitations: [], link }).score,
    ).toBe(75);
    expect(
      deterministicVerdict(request, {
        intel: [],
        limitations: [],
        link: { ...link, hops: [] },
      }).score,
    ).toBe(40);
    expect(
      deterministicVerdict(request, {
        intel: [],
        limitations: [],
        link: { ...link, asksFor: [] },
      }).score,
    ).toBe(request.device.score);
  });
  it("an AI response cannot lower the device floor or contradict its headline", async () => {
    const result = await createVerdict(
      { ...request, device: { score: 85, floor: 85, findingIds: ["danger"] } },
      { intel: [], limitations: [] },
      returning(draft),
    );
    expect(result.score).toBe(85);
    expect(result.level).toBe("danger");
    expect(result.headline).toBe("Dangerous.");
    expect(result.findings.some((finding) => finding.source === "device")).toBe(
      true,
    );
  });
  it("an exact intel match forces at least 80", async () => {
    const result = await createVerdict(
      request,
      { intel: [known], limitations: [] },
      returning(draft),
    );
    expect(result.score).toBe(80);
    expect(result.findings.some((finding) => finding.source === "intel")).toBe(
      true,
    );
  });
  it("invalid model output produces a localized, conservative result", async () => {
    const result = await createVerdict(
      { ...request, locale: "cs" },
      { intel: [], limitations: [] },
      returning({ score: -500 }),
    );
    expect(result.level).toBe("caution");
    expect(result.headline).toBe("Buďte opatrní.");
    expect(result.limitations.join(" ")).toContain("nebylo dostupné");
  });
  it("a model outage keeps factual findings and correct SMS consequences", async () => {
    const result = await createVerdict(
      { ...request, kind: "sms", payload: "SMSTO:9001234:START" },
      { intel: [known], limitations: [] },
      failing(),
    );
    expect(result.score).toBeGreaterThanOrEqual(80);
    expect(result.consequences.join(" ")).toContain(
      "Sending it may cost money",
    );
  });
  it.each([
    [29, "safe"],
    [30, "caution"],
    [69, "caution"],
    [70, "danger"],
  ] as const)("derives the boundary at %i", (score, level) => {
    expect(
      deterministicVerdict(
        { ...request, device: { score, floor: score, findingIds: [] } },
        { intel: [], limitations: [] },
      ).level,
    ).toBe(level);
  });
  it("does not claim safe when the website could not be inspected", () => {
    const result = deterministicVerdict(request, {
      intel: [],
      limitations: ["sandbox"],
    });
    expect(result.score).toBeGreaterThanOrEqual(30);
  });
});
