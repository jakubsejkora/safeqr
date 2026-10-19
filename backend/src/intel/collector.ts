import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import { z } from "zod";
import { env, REGION } from "../shared/config.js";
import { BedrockModel, type Model } from "../shared/model.js";
import { count, measured } from "../shared/observability.js";
import { claimOnce, QuotaExceeded } from "../shared/storage.js";
import { Apify } from "./apify.js";
import { type Article, fetchArticle } from "./article.js";
import { extractCase } from "./extract.js";
import { caseId } from "./schema.js";
import { type ActorJob, actorJobs, canonicalSource } from "./sources.js";
import { DynamoIntelStore, type IntelStore } from "./store.js";

interface CollectorDependencies {
  apify: { run(job: ActorJob): Promise<unknown[]> };
  intel: IntelStore;
  model: Model;
  claim(): Promise<void>;
  article?: typeof fetchArticle;
}
export interface CollectionResult {
  candidates: number;
  stored: number;
  failed: number;
  skipped: boolean;
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
  };
  try {
    await deps.claim();
  } catch (error) {
    if (error instanceof QuotaExceeded) return { ...result, skipped: true };
    throw error;
  }
  let attempts = 0;
  const seen = new Set<string>();
  for (const job of actorJobs()) {
    let discovered: ReturnType<typeof candidates>;
    try {
      discovered = candidates(
        await deps.apify.run(job),
        job.actor.includes("facebook"),
      );
    } catch {
      result.failed++;
      continue;
    }
    const articles: Article[] = [...discovered.posts];
    for (const url of discovered.urls.slice(0, 12)) {
      if (seen.has(url) || (await deps.intel.has(caseId(url)))) continue;
      seen.add(url);
      try {
        const article = await (deps.article ?? fetchArticle)(url);
        if (article) articles.push(article);
      } catch {
        result.failed++;
      }
    }
    for (const article of articles) {
      result.candidates++;
      if (attempts >= 8 || (await deps.intel.has(caseId(article.sourceUrl))))
        continue;
      if (!/\bqr\b|quishing/i.test(article.text)) continue;
      attempts++;
      try {
        const item = await extractCase(article, deps.model);
        if (item) {
          await deps.intel.put(item);
          result.stored++;
        }
      } catch {
        result.failed++;
      }
    }
  }
  return result;
}

export function claimCollection(): Promise<void> {
  const day = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Prague",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  return claimOnce(env("CHECKS_TABLE"), `collector#${day}`);
}

export const handler = () =>
  measured("collector", async () => {
    const secrets = new SecretsManagerClient({
      region: REGION,
      maxAttempts: 1,
    });
    const secret = await secrets.send(
      new GetSecretValueCommand({ SecretId: env("APIFY_SECRET_ARN") }),
    );
    const token = secret.SecretString;
    if (!token) throw new Error("Collector credentials unavailable");
    const result = await collect({
      apify: new Apify(token),
      intel: new DynamoIntelStore(env("INTEL_TABLE")),
      model: new BedrockModel(8),
      claim: claimCollection,
    });
    count(result.failed ? "CollectionPartial" : "CollectionCompleted");
    return result;
  });
