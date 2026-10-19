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
const finished = (run: Run) =>
  ["SUCCEEDED", "FAILED", "TIMED-OUT", "ABORTED"].includes(run.status);

/** Runs a bounded public-source job and deletes temporary Apify storage. */
export class Apify {
  private reserved = 0;
  constructor(
    private readonly token: string,
    private readonly request = fetch,
  ) {}

  async run(job: ActorJob): Promise<unknown[]> {
    if (job.capUsd <= 0 || this.reserved + job.capUsd > 0.8)
      throw new Error("Daily collector budget exhausted");
    this.reserved += job.capUsd;
    const query = new URLSearchParams({
      build: job.build,
      timeout: "120",
      memory: String(job.memory),
      maxTotalChargeUsd: String(job.capUsd),
      restartOnError: "false",
      waitForFinish: "0",
    });
    let run = runSchema.parse(
      (
        (await this.api(
          `actors/${job.actor.replace("/", "~")}/runs?${query}`,
          "POST",
          job.input,
        )) as { data: unknown }
      ).data,
    );
    try {
      const deadline = Date.now() + 135_000;
      while (!finished(run) && Date.now() < deadline) {
        run = runSchema.parse(
          (
            (await this.api(`actor-runs/${run.id}?waitForFinish=10`)) as {
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
      });
      if (run.status !== "SUCCEEDED" || !run.defaultDatasetId)
        throw new Error("Actor did not complete successfully");
      const items = await this.api(
        `datasets/${run.defaultDatasetId}/items?clean=true&limit=40&format=json&fields=sourceUrl,isSeed,hasQrMention,organicResults,url,text,time,timestamp,postId,pageName`,
      );
      return z.array(z.unknown()).max(40).parse(items);
    } finally {
      if (!finished(run)) {
        run = runSchema.parse(
          (
            (await this.api(
              `actor-runs/${run.id}/abort?waitForFinish=10`,
              "POST",
            )) as { data: unknown }
          ).data,
        );
      }
      await this.purge(run);
    }
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
      resources.map((path) => this.api(path, "DELETE")),
    );
    if (deleted.some((result) => result.status === "rejected"))
      throw new Error("Temporary source cleanup failed");
  }

  private async api(
    path: string,
    method = "GET",
    body?: unknown,
  ): Promise<unknown> {
    const response = await this.request(`https://api.apify.com/v2/${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.token}`,
        "Content-Type": "application/json",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(20_000),
      redirect: "error",
    });
    if (response.status === 204) return undefined;
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
