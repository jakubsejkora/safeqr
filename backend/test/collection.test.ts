import { load } from "cheerio";
import { describe, expect, it, vi } from "vitest";
import seeds from "../data/verified-cases.json" with { type: "json" };
import { Apify, pragueBillingDays } from "../src/intel/apify.js";
import { fetchArticle } from "../src/intel/article.js";
import { collect } from "../src/intel/collector.js";
import { extractCase, prepareArticle } from "../src/intel/extract.js";
import { publicationDate } from "../src/intel/publication.js";
import { actorJobs } from "../src/intel/sources.js";
import type { WebFetch, WebResponse } from "../src/shared/network.js";
import { failing, intel, returning } from "./helpers.js";

const sourceUrl = "https://www.spp.sk/clanky/report/";
const article = {
  sourceUrl,
  text: "Podvodné QR kódy vedou na falešné stránky.",
  publishedAt: "2026-03-31",
};

describe("publication evidence", () => {
  it("reads JSON-LD dates and selects article metadata after template metadata", () => {
    expect(
      publicationDate(
        load(
          '<script type="application/ld+json">{"@graph":[{"datePublished":"2026-03-31T12:00:00Z"}]}</script>',
        ),
        "",
      ),
    ).toBe("2026-03-31");
    expect(
      publicationDate(
        load(
          '<meta name="date" content="2019-09-05"><meta name="date" content="07.10.2026 14:07">',
        ),
        "",
      ),
    ).toBe("2026-10-07");
  });
  it("reads standalone Czech publication lines but never an incident date buried in prose", () => {
    expect(
      publicationDate(
        load(""),
        "Text zprávy.\n14. července 2026, tiskové oddělení",
      ),
    ).toBe("2026-07-14");
    expect(
      publicationDate(load(""), "K útoku došlo 14. července 2026."),
    ).toBeUndefined();
    expect(
      publicationDate(
        load('<meta property="article:modified_time" content="2026-10-19">'),
        "",
      ),
    ).toBeUndefined();
  });
  it("follows a same-origin robots redirect and preserves the publication date", async () => {
    const request = vi
      .fn<WebFetch>()
      .mockImplementation(async (url): Promise<WebResponse> => {
        if (url.endsWith("/robots.txt"))
          return {
            status: 301,
            headers: { location: "/rules.txt" },
            body: Buffer.alloc(0),
          };
        if (url.endsWith("/rules.txt"))
          return {
            status: 200,
            headers: {},
            body: Buffer.from("User-agent: *\nDisallow:"),
          };
        return {
          status: 200,
          headers: { "content-type": "text/html" },
          body: Buffer.from(
            "<main><p>QR podvod.</p><p>31. marec 2026</p></main>",
          ),
        };
      });
    expect((await fetchArticle(sourceUrl, request)).publishedAt).toBe(
      "2026-03-31",
    );
  });
});

describe("collection gates and diagnostics", () => {
  it("keeps nearby QR evidence without mixing unrelated fraud in a police digest", () => {
    const prepared = prepareArticle({
      sourceUrl,
      text: "Fake DHL QR codes collect personal data. Do not scan them. Contact the police. Another report follows. An unrelated investment fraud stole banking passwords.",
    });
    expect(prepared.text).toContain("QR");
    expect(prepared.text).not.toContain("banking passwords");
  });

  it("rejects undated or non-QR material before paying for extraction", async () => {
    const model = failing();
    expect(
      await extractCase({ ...article, publishedAt: undefined }, model),
    ).toEqual({ accepted: false, reason: "missing_publication_date" });
    expect(
      await extractCase(
        { ...article, text: "A scam SMS with an ordinary link." },
        model,
      ),
    ).toEqual({ accepted: false, reason: "no_qr_evidence" });
    expect(model.ask).not.toHaveBeenCalled();
  });
  it("records an explicit model rejection without publishing a case", async () => {
    expect(
      await extractCase(
        article,
        returning({
          isQuishing: false,
          privacySafe: true,
          titleCs: "",
          titleEn: "",
          case: null,
        }),
      ),
    ).toEqual({ accepted: false, reason: "unrelated_to_qr_fraud" });
  });
  it("accepts direct article seeds, deduplicates, and explains each rejected official post", async () => {
    const store = intel();
    const sourceCase = seeds[0];
    if (!sourceCase) throw new Error("Missing fixture");
    const result = await collect({
      claim: async () => {},
      intel: store,
      article: async () => article,
      model: returning({
        isQuishing: true,
        privacySafe: true,
        titleCs: "Podvodný QR kód",
        titleEn: "Fake QR code",
        case: {
          ...Object.fromEntries(
            Object.entries(sourceCase.record).filter(([key]) => key !== "id"),
          ),
          payloadType: null,
        },
      }),
      apify: {
        run: async (job) =>
          job.actor.includes("facebook")
            ? Array.from({ length: 5 }, (_, index) => ({
                postId: `123456${index}`,
                pageName: "PolicieCZ",
                time: "2026-10-19T12:00:00Z",
                text: "Policie informuje o silniční kontrole.",
              }))
            : [{ sourceUrl, isSeed: false }],
      },
    });
    expect(result.stored).toBe(1);
    expect(store.put).toHaveBeenCalledOnce();
    expect(store.put).toHaveBeenCalledWith(
      expect.objectContaining({
        record: expect.objectContaining({ payloadType: "unknown" }),
      }),
    );
    expect(
      result.decisions.filter((item) => item.reason === "no_qr_evidence"),
    ).toHaveLength(5);
    expect(result.decisions.some((item) => item.reason === "duplicate")).toBe(
      true,
    );
  });
  it("includes both UTC billing days overlapping the Prague day", () => {
    expect(pragueBillingDays(new Date("2026-10-19T22:30:00Z"))).toEqual([
      "2026-10-19",
      "2026-10-20",
    ]);
  });
  it("refuses paid work when observed account spend leaves insufficient headroom", async () => {
    const request: typeof fetch = vi.fn(async () =>
      Response.json({
        data: {
          dailyServiceUsages: [
            {
              date: pragueBillingDays(new Date())[0],
              totalUsageCreditsUsd: 0.25,
            },
          ],
        },
      }),
    );
    const job = actorJobs()[0];
    if (!job) throw new Error("Missing job");
    await expect(new Apify("test-secret", request).run(job)).rejects.toThrow(
      "budget",
    );
    expect(request).toHaveBeenCalledOnce();
  });
});
