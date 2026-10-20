import { z } from "zod";
import { apifyToken } from "../shared/apify-secret.js";
import { env } from "../shared/config.js";
import { BedrockModel, type Model } from "../shared/model.js";
import { count, logger, measured } from "../shared/observability.js";
import { claimOnce, QuotaExceeded } from "../shared/storage.js";
import { Apify } from "./apify.js";
import { type Article, ArticleRejected, fetchArticle } from "./article.js";
import { extractCase, type RejectionReason } from "./extract.js";
import { caseId } from "./schema.js";
import { type ActorJob, actorJobs, canonicalSource } from "./sources.js";
import { DynamoIntelStore, type IntelStore } from "./store.js";

interface CollectorDependencies {
  apify: { run(job: ActorJob): Promise<unknown[]> };
  intel: IntelStore;
  model: Model;
  claim(): Promise<void>;
  article?: typeof fetchArticle;
  jobs?: ActorJob[];
}
type DecisionReason =
  | RejectionReason
  | ArticleRejected["reason"]
  | "accepted"
  | "duplicate"
  | "model_budget"
  | "fetch_failed"
  | "extraction_failed";
interface Decision {
  sourceUrl: string;
  reason: DecisionReason;
}
export interface CollectionResult {
  candidates: number;
  stored: number;
  failed: number;
  skipped: boolean;
  decisions: Decision[];
  actors: { actor: string; items: number; status: "completed" | "failed" }[];
}

function candidates(
  items: unknown[],
  facebook: boolean,
): { urls: string[]; posts: Article[] } {
  const urls = new Set<string>();
  const posts: Article[] = [];
  for (const item of items) {
    if (!item || typeof item !== "object") continue;
    const row = item as Record<string, unknown>;
    if (facebook) {
      const id = typeof row.postId === "string" ? row.postId : undefined;
      if (!id || !/^\d{5,40}$/.test(id) || typeof row.text !== "string")
        continue;
      if (row.pageName !== undefined && row.pageName !== "PolicieCZ") continue;
      const date =
        typeof row.time === "string"
          ? row.time.slice(0, 10)
          : typeof row.timestamp === "number"
            ? new Date(row.timestamp * (row.timestamp < 1e12 ? 1000 : 1))
                .toISOString()
                .slice(0, 10)
            : undefined;
      if (date && z.iso.date().safeParse(date).success)
        posts.push({
          sourceUrl: `https://www.facebook.com/PolicieCZ/posts/${id}`,
          text: row.text.slice(0, 16_000),
          publishedAt: date,
        });
      continue;
    }
    const links = [
      row.sourceUrl,
      ...(Array.isArray(row.organicResults)
        ? row.organicResults.map((result: unknown) =>
            result && typeof result === "object" && "url" in result
              ? result.url
              : undefined,
          )
        : []),
    ];
    if (row.isSeed === true) continue;
    for (const link of links) {
      if (typeof link !== "string") continue;
      const source = canonicalSource(link);
      if (source) urls.add(source);
    }
  }
  return { urls: [...urls], posts };
}

export async function collect(
  deps: CollectorDependencies,
): Promise<CollectionResult> {
  const result: CollectionResult = {
    candidates: 0,
    stored: 0,
    failed: 0,
    skipped: false,
    decisions: [],
    actors: [],
  };
  try {
    await deps.claim();
  } catch (error) {
    if (error instanceof QuotaExceeded) return { ...result, skipped: true };
    throw error;
  }
  let attempts = 0;
  const seen = new Set<string>();
  const decision = (sourceUrl: string, reason: DecisionReason) => {
    result.decisions.push({ sourceUrl, reason });
    logger.info("Public-source decision", {
      sourceId: caseId(sourceUrl),
      reason,
    });
  };
  const processArticle = async (article: Article) => {
    result.candidates++;
    if (await deps.intel.has(caseId(article.sourceUrl))) {
      decision(article.sourceUrl, "duplicate");
      return;
    }
    if (!/\bqr\b|quishing/i.test(article.text)) {
      decision(article.sourceUrl, "no_qr_evidence");
      return;
    }
    if (!article.publishedAt) {
      decision(article.sourceUrl, "missing_publication_date");
      return;
    }
    if (attempts >= 8) {
      decision(article.sourceUrl, "model_budget");
      return;
    }
    attempts++;
    try {
      const extraction = await extractCase(article, deps.model);
      if (extraction.accepted) {
        await deps.intel.put(extraction.item);
        result.stored++;
        decision(article.sourceUrl, "accepted");
      } else decision(article.sourceUrl, extraction.reason);
    } catch (error) {
      result.failed++;
      decision(article.sourceUrl, "extraction_failed");
      logger.warn("Public-source extraction failed", {
        errorType: error instanceof Error ? error.name : "Error",
        validation:
          error instanceof z.ZodError
            ? error.issues.map((issue) => ({
                code: issue.code,
                path: issue.path,
              }))
            : undefined,
      });
    }
  };
  for (const job of deps.jobs ?? actorJobs()) {
    let discovered: ReturnType<typeof candidates>;
    try {
      const items = await deps.apify.run(job);
      discovered = candidates(items, job.actor.includes("facebook"));
      result.actors.push({
        actor: job.actor,
        items: items.length,
        status: "completed",
      });
    } catch {
      result.failed++;
      result.actors.push({ actor: job.actor, items: 0, status: "failed" });
      logger.warn("Collection operation failed", {
        stage: "actor",
        actor: job.actor,
      });
      continue;
    }
    for (const url of discovered.urls.slice(0, 12)) {
      if (seen.has(url) || (await deps.intel.has(caseId(url)))) {
        decision(url, "duplicate");
        continue;
      }
      seen.add(url);
      try {
        await processArticle(await (deps.article ?? fetchArticle)(url));
      } catch (error) {
        if (error instanceof ArticleRejected) decision(url, error.reason);
        else {
          result.failed++;
          decision(url, "fetch_failed");
        }
      }
    }
    for (const post of discovered.posts) await processArticle(post);
  }
  return result;
}

export function claimCollection(actor?: string): Promise<void> {
  const day = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Prague",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  return claimOnce(
    env("CHECKS_TABLE"),
    `collector#${day}${actor ? `#${actor}` : ""}`,
  );
}

const invocationSchema = z
  .object({
    actor: z
      .enum([
        "apify/cheerio-scraper",
        "apify/google-search-scraper",
        "apify/facebook-posts-scraper",
      ])
      .optional(),
  })
  .strict();

export const handler = (event: unknown = {}) =>
  measured("collector", async () => {
    const { actor } = invocationSchema.parse(event);
    const jobs = actorJobs().filter((job) => !actor || job.actor === actor);
    const token = await apifyToken();
    const result = await collect({
      apify: new Apify(
        token,
        fetch,
        jobs.reduce((sum, job) => sum + job.capUsd, 0),
      ),
      intel: new DynamoIntelStore(env("INTEL_TABLE")),
      model: new BedrockModel(8),
      claim: () => claimCollection(actor),
      jobs,
    });
    count(result.failed ? "CollectionPartial" : "CollectionCompleted");
    return result;
  });
