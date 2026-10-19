import { setTimeout } from "node:timers/promises";
import { env } from "../src/shared/config.js";
import {
  acceptedSchema,
  checkSchema,
  requestSchema,
} from "../src/shared/schemas.js";

try {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      cs: { type: "boolean" },
      scene: { type: "string" },
      kind: { type: "string", default: "link" },
      score: { type: "string", default: "0" },
      floor: { type: "string", default: "0" },
      finding: { type: "string", multiple: true },
    },
  });
  const request = requestSchema.parse({
    payload: positionals[0] ?? "https://safeqr.cz",
    kind: values.kind,
    locale: values.cs ? "cs" : "en",
    device: {
      score: Number(values.score),
      floor: Number(values.floor),
      findingIds: values.finding ?? [],
    },
    ...(values.scene
      ? {
          scene: {
            image: (await readFile(values.scene)).toString("base64"),
            source: "photo",
          },
        }
      : {}),
  });
  const api = env("API_URL").replace(/\/$/, "");
  if (new URL(api).protocol !== "https:") throw new Error("HTTPS required");
  const started = performance.now();
  const response = await fetch(`${api}/v1/checks`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    signal: AbortSignal.timeout(20_000),
    body: JSON.stringify(request),
  });
  if (response.status !== 202)
    throw new Error(`Start returned ${response.status}`);
  const accepted = acceptedSchema.parse(await response.json());
  console.log(
    `Check ${accepted.id} accepted in ${Math.round(performance.now() - started)} ms`,
  );
  const deadline = Date.now() + 160_000;
  let previous = "";
  for (;;) {
    await setTimeout(Math.max(500, Math.min(accepted.pollAfterMs, 3000)));
    const poll = await fetch(`${api}/v1/checks/${accepted.id}`, {
      signal: AbortSignal.timeout(10_000),
    });
    if (!poll.ok) throw new Error(`Poll returned ${poll.status}`);
    const check = checkSchema.parse(await poll.json());
    const steps = JSON.stringify(check.steps);
    if (steps !== previous) {
      console.log(
        check.steps.map((step) => `${step.status}: ${step.label}`).join("\n"),
      );
      previous = steps;
    }
    if (check.status !== "running") {
      console.log(
        JSON.stringify(
          {
            ...check.result,
            link: check.result?.link
              ? {
                  ...check.result.link,
                  screenshotUrl: check.result.link.screenshotUrl
                    ? "[15-minute private screenshot URL]"
                    : undefined,
                }
              : undefined,
          },
          null,
          2,
        ),
      );
      console.log(
        `Completed in ${((performance.now() - started) / 1000).toFixed(2)} s`,
      );
      if (check.status !== "completed") process.exitCode = 1;
      break;
    }
    if (Date.now() > deadline) throw new Error("Timed out waiting for verdict");
  }
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message.replace(/https?:\S+/g, "[URL]")
      : "Smoke check failed",
  );
  process.exitCode = 1;
}

import { readFile } from "node:fs/promises";
import { parseArgs } from "node:util";
