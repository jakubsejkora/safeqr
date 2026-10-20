import { z } from "zod";
import { logger } from "../shared/observability.js";
import type { ActorJob } from "./sources.js";

const runSchema = z.object({
  id: z.string(),
  status: z.string(),
  defaultDatasetId: z.string().optional(),
  defaultKeyValueStoreId: z.string().optional(),
  defaultRequestQueueId: z.string().optional(),
  usageTotalUsd: z.number().optional(),
});
type Run = z.infer<typeof runSchema>;
interface RunOptions {
  seconds?: number;
  fields?: string[];
  limit?: number;
}
const finished = (run: Run) =>
  ["SUCCEEDED", "FAILED", "TIMED-OUT", "ABORTED"].includes(run.status);

/** Runs a bounded public-source job and deletes temporary Apify storage. */
export class Apify {
  private reserved = 0;
  private budgetChecked = false;
  constructor(
    private readonly token: string,
    private readonly request = fetch,
    private readonly budgetUsd = 0.76,
  ) {}

  async run(job: ActorJob, options: RunOptions = {}): Promise<unknown[]> {
    const started = Date.now();
    const seconds = options.seconds ?? 135;
    const deadline = started + seconds * 1000;
    const remaining = () => Math.max(1, deadline - Date.now());
    const limit = options.limit ?? 40;
    if (job.capUsd <= 0 || this.reserved + job.capUsd > this.budgetUsd)
      throw new Error("Daily collector budget exhausted");
    if (!this.budgetChecked) {
      await this.checkDailyBudget();
      this.budgetChecked = true;
    }
    this.reserved += job.capUsd;
    const query = new URLSearchParams({
      build: job.build,
      timeout: String(Math.min(120, seconds)),
      memory: String(job.memory),
      maxTotalChargeUsd: String(job.capUsd),
      restartOnError: "false",
      forcePermissionLevel: "LIMITED_PERMISSIONS",
      waitForFinish: "0",
    });
    let run = runSchema.parse(
      (
        (await this.api(
          `actors/${job.actor.replace("/", "~")}/runs?${query}`,
          "POST",
          job.input,
          remaining(),
        )) as { data: unknown }
      ).data,
    );
    try {
      while (!finished(run) && Date.now() < deadline) {
        run = runSchema.parse(
          (
            (await this.api(
              `actor-runs/${run.id}?waitForFinish=${Math.min(5, Math.ceil(remaining() / 1000))}`,
              "GET",
              undefined,
              remaining(),
            )) as {
              data: unknown;
            }
          ).data,
        );
      }
      if (!finished(run)) throw new Error("Actor time limit reached");
      logger.info("Public-source actor completed", {
        actor: job.actor,
        status: run.status,
        costUsd: run.usageTotalUsd,
        durationMs: Date.now() - started,
      });
      if (run.status !== "SUCCEEDED" || !run.defaultDatasetId)
        throw new Error("Actor did not complete successfully");
      const fields =
        options.fields?.join(",") ??
        "sourceUrl,isSeed,hasQrMention,organicResults,url,text,time,timestamp,postId,pageName";
      const items = await this.api(
        `datasets/${run.defaultDatasetId}/items?clean=true&limit=${limit}&format=json&fields=${fields}`,
        "GET",
        undefined,
        remaining(),
      );
      return z.array(z.unknown()).max(limit).parse(items);
    } finally {
      try {
        if (!finished(run)) {
          run = runSchema.parse(
            (
              (await this.api(
                `actor-runs/${run.id}/abort?waitForFinish=2`,
                "POST",
                undefined,
                3000,
              )) as { data: unknown }
            ).data,
          );
        }
      } finally {
        await this.purge(run);
      }
    }
  }

  private async checkDailyBudget(): Promise<void> {
    const usageSchema = z.object({
      data: z.object({
        dailyServiceUsages: z.array(
          z.object({
            date: z.string(),
            totalUsageCreditsUsd: z.number().nonnegative(),
          }),
        ),
      }),
    });
    const usage = usageSchema.parse(await this.api("users/me/usage/monthly"));
    const days = pragueBillingDays(new Date());
    const spent = usage.data.dailyServiceUsages
      .filter((entry) => days.includes(entry.date.slice(0, 10)))
      .reduce((sum, entry) => sum + entry.totalUsageCreditsUsd, 0);
    logger.info("Public-source daily budget", {
      observedUsd: spent,
      reservedUsd: this.budgetUsd,
    });
    // Billing is daily UTC and can lag. Include every overlapping day and leave a margin.
    if (spent + this.budgetUsd > 0.98)
      throw new Error("Daily collector budget exhausted");
  }

  private async purge(run: Run): Promise<void> {
    const resources = [
      ...(run.defaultDatasetId ? [`datasets/${run.defaultDatasetId}`] : []),
      ...(run.defaultKeyValueStoreId
        ? [`key-value-stores/${run.defaultKeyValueStoreId}`]
        : []),
      ...(run.defaultRequestQueueId
        ? [`request-queues/${run.defaultRequestQueueId}`]
        : []),
      `actor-runs/${run.id}`,
    ];
    const deleted = await Promise.allSettled(
      resources.map((path) => this.api(path, "DELETE", undefined, 3000)),
    );
    if (deleted.some((result) => result.status === "rejected"))
      throw new Error("Temporary source cleanup failed");
  }

  private async api(
    path: string,
    method = "GET",
    body?: unknown,
    timeoutMs = 20_000,
  ): Promise<unknown> {
    const response = await this.request(`https://api.apify.com/v2/${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.token}`,
        "Content-Type": "application/json",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(Math.min(20_000, timeoutMs)),
      redirect: "error",
    });
    if (
      response.status === 204 ||
      (method === "DELETE" && response.status === 404)
    )
      return undefined;
    if (!response.body) throw new Error("Empty source response");
    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    try {
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 2_000_000) throw new Error("Source response too large");
        chunks.push(value);
      }
    } finally {
      await reader.cancel();
    }
    const parsed: unknown = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    if (!response.ok) {
      const error = z
        .object({
          error: z.object({ type: z.string().regex(/^[a-z-]{1,100}$/) }),
        })
        .safeParse(parsed);
      logger.warn("Public-source API unavailable", {
        status: response.status,
        code: error.success ? error.data.error.type : "unknown",
      });
      throw new Error("Public-source service unavailable");
    }
    return parsed;
  }
}

export function pragueBillingDays(now: Date): string[] {
  const localDay = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Prague",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
  const previous = new Date(`${localDay}T00:00:00Z`);
  previous.setUTCDate(previous.getUTCDate() - 1);
  return [previous.toISOString().slice(0, 10), localDay];
}
