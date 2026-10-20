import { describe, expect, it } from "vitest";
import {
  createVerdict,
  deterministicVerdict,
} from "../src/checks/verdict/agent.js";
import {
  effectiveDevice,
  establishedDestination,
} from "../src/checks/verdict/calibration.js";
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
  it.each([undefined, 366, 3000])(
    "ordinary own-site forms add information without points (age %s)",
    (domainAgeDays) => {
      const result = deterministicVerdict(request, {
        intel: [],
        limitations: ["restricted", "domain", "model", "browserModel"],
        link: {
          finalUrl: request.payload,
          hops: [],
          domainAgeDays,
          asksFor: ["password", "card", "phone", "personalData"],
        },
      });
      expect(result.score).toBe(10);
      expect(result.findings).toEqual([
        expect.objectContaining({ id: "page-request", severity: "info" }),
      ]);
    },
  );
  it("unknown domain age after a normal redirect is not evidence of deception", () => {
    const result = deterministicVerdict(request, {
      intel: [],
      limitations: ["domain"],
      link: { finalUrl: "https://other.example/", hops: [], asksFor: ["card"] },
    });
    expect(result.score).toBe(10);
  });
  it("a sensitive request on a known young domain is a warning", () => {
    const result = deterministicVerdict(request, {
      intel: [],
      limitations: [],
      link: {
        finalUrl: "https://other.example/",
        hops: [],
        domainAgeDays: 100,
        asksFor: ["card"],
      },
    });
    expect(result.score).toBe(40);
    expect(result.findings).toContainEqual(
      expect.objectContaining({ id: "sensitive-request", severity: "warning" }),
    );
  });
  it("resolves shortener and HTTP findings while preserving other findings and every floor", () => {
    const link = { finalUrl: "https://destination.example/", hops: [] };
    const deviceRequest = {
      ...request,
      device: {
        score: 40,
        floor: 0,
        findingIds: ["link.shortener", "link.http"],
      },
    };
    expect(effectiveDevice(deviceRequest, link).score).toBe(0);
    expect(effectiveDevice(deviceRequest).score).toBe(40);
    expect(
      effectiveDevice(
        { ...deviceRequest, device: { ...deviceRequest.device, floor: 35 } },
        link,
      ).score,
    ).toBe(35);
    expect(
      effectiveDevice(
        {
          ...deviceRequest,
          device: {
            ...deviceRequest.device,
            findingIds: ["link.shortener", "link.unusualHost"],
          },
        },
        link,
      ).score,
    ).toBe(40);
    expect(
      effectiveDevice(deviceRequest, {
        ...link,
        finalUrl: "http://destination.example/",
      }).findingIds,
    ).toEqual(["link.http"]);
  });
  it("treats only a known registration age as established", () => {
    expect(
      establishedDestination({
        finalUrl: "https://other.example/",
        hops: [],
        domainAgeDays: 365,
      }),
    ).toBe(true);
    for (const domainAgeDays of [undefined, 364])
      expect(
        establishedDestination({
          finalUrl: "https://shop.example.com/",
          hops: [],
          domainAgeDays,
        }),
      ).toBe(false);
  });
  it("does not accept an unexplained high model score", async () => {
    for (const findings of [
      [],
      [
        {
          id: "info",
          severity: "info",
          source: "ai",
          title: "Sign in",
          detail: "The page offers sign-in.",
        },
      ],
    ]) {
      const result = await createVerdict(
        request,
        { intel: [], limitations: [] },
        returning({ ...draft, score: 70, findings }),
      );
      expect(result.score).toBe(10);
    }
  });
  it("always explains a verdict at or above 30, including unavailable destinations", async () => {
    for (const score of [0, 29, 30, 69, 70, 100]) {
      for (const destinationUnavailable of [false, true]) {
        const result = await createVerdict(
          { ...request, device: { score, floor: score, findingIds: [] } },
          {
            intel: [],
            limitations: ["model", "sandbox"],
            destinationUnavailable,
          },
          failing(),
        );
        if (result.score >= 30)
          expect(
            result.findings.some((finding) => finding.severity !== "info"),
          ).toBe(true);
      }
    }
  });
  it("does not call informational device findings warnings", () => {
    const result = deterministicVerdict(
      {
        ...request,
        device: { score: 10, floor: 0, findingIds: ["payment.instant"] },
      },
      { intel: [], limitations: [] },
    );
    expect(result.score).toBe(10);
    expect(result.findings).toEqual([]);
  });
  it("keeps device warning severity even when its score is above the proven floor", () => {
    const result = deterministicVerdict(
      {
        ...request,
        device: { score: 70, floor: 0, findingIds: ["content.combination"] },
      },
      { intel: [], limitations: [] },
    );
    expect(result.findings).toContainEqual(
      expect.objectContaining({
        source: "device",
        severity: "danger",
      }),
    );
  });
  it("raises concealed card collection to danger while an ordinary card form stays low", () => {
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
    ).toBe(10);
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
    expect(result.level).toBe("safe");
    expect(result.headline).toBe("Vypadá bezpečně.");
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
      destinationUnavailable: true,
    });
    expect(result.score).toBeGreaterThanOrEqual(30);
  });
});
